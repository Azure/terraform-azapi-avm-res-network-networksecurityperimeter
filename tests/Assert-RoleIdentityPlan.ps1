param(
  [Parameter(Mandatory)][string]$PlanPath,
  [Parameter(Mandatory)]
  [ValidateSet('unchanged', 'case-only', 'role-change', 'principal-change', 'scope-change',
    'old-resolved-keepers', 'legacy-repeat', 'legacy-case-only', 'legacy-role-change',
    'legacy-principal-change', 'legacy-scope-change', 'explicit-guid', 'adopted-guid',
    'explicit-role-change', 'adopted-role-change')]
  [string]$Scenario
)
$ErrorActionPreference = 'Stop'
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
$uuids = @($plan.resource_changes | Where-Object {
  $_.type -eq 'random_uuid' -and $_.change.before.keepers
})
$assignments = @($plan.resource_changes | Where-Object {
  $_.type -eq 'azapi_resource' -and $_.name -in @('role_assignments', 'target_role_assignments')
})
$lookups = @($plan.resource_changes | Where-Object {
  $_.type -eq 'azapi_resource_list' -and $_.name -eq 'role_definitions'
})
if ($uuids.Count -ne 9 -or $assignments.Count -ne 9 -or $lookups.Count -ne 9) {
  throw 'Expected all nine root/child/target UUIDs, assignments and role lookups.'
}
$dep = @($plan.resource_changes | Where-Object address -EQ 'terraform_data.dep')
if ($dep.Count -ne 1 -or ($dep[0].change.actions -join '+') -ne 'update') {
  throw 'Regression must have a pending dependency-only update.'
}
foreach ($lookup in $lookups) {
  if (($lookup.change.actions -join '+') -ne 'read' -or !$lookup.change.after_unknown.output) {
    throw "Expected deferred role lookup: $($lookup.address)"
  }
}
$replace = $Scenario -in @('role-change', 'principal-change', 'scope-change',
  'legacy-role-change', 'legacy-principal-change', 'legacy-scope-change',
  'explicit-role-change', 'adopted-role-change')
foreach ($uuid in $uuids) {
  if ($replace -ne ($uuid.change.actions -contains 'delete')) {
    throw "Unexpected UUID action: $($uuid.address) $($uuid.change.actions -join '+')"
  }
  if ($replace -and !$uuid.change.after_unknown.result) {
    throw "Replacement must produce a new UUID: $($uuid.address)"
  }
  if (!$replace -and (($uuid.change.actions -join '+') -ne 'no-op' -or
    $uuid.change.before.result -ne $uuid.change.after.result)) {
    throw "UUID must remain stable: $($uuid.address)"
  }
}
foreach ($assignment in $assignments) {
  if ($assignment.change.after_unknown.replace_triggers_external_values.role_definition_id) {
    throw "Role replacement component must be known: $($assignment.address)"
  }
  if (!$assignment.change.after_unknown.body.properties.roleDefinitionId) {
    throw "RBAC body must still wait for the resolved role ID: $($assignment.address)"
  }
  # The lookup-only reference's parent ID is independently unknown under depends_on.
  $referenceChild = $assignment.address -eq 'module.reference.azapi_resource.role_assignments["reader"]'
  if ($referenceChild -and !$replace -and
    (($assignment.change.replace_paths | ConvertTo-Json -Depth 20) -notmatch 'parent_id' -or
      !$assignment.change.after_unknown.parent_id)) {
    throw 'Reference-child replacement must be explained by its independently deferred parent ID.'
  }
  if (!$referenceChild -and $replace -ne ($assignment.change.actions -contains 'delete')) {
    throw "Unexpected assignment replacement: $($assignment.address)"
  }
  if (!$replace -and ($assignment.change.replace_paths | ConvertTo-Json -Depth 20) -match 'replace_triggers_external_values') {
    throw "Unchanged role input must not replace via external triggers: $($assignment.address)"
  }
  if (!$replace -and $assignment.change.before.replace_triggers_external_values.role_definition_id -ne
    $assignment.change.after.replace_triggers_external_values.role_definition_id) {
    throw "Stored external role component must be retained: $($assignment.address)"
  }
  if (!$replace -and !$referenceChild -and $assignment.change.before.name -ne $assignment.change.after.name) {
    throw "Existing generated/explicit/adopted GUID must be retained: $($assignment.address)"
  }
  if ($replace -and $Scenario -ne 'explicit-role-change' -and !$assignment.change.after_unknown.name) {
    throw "Generated/adopted assignment replacement must use the new UUID: $($assignment.address)"
  }
  if ($Scenario -eq 'explicit-role-change' -and
    $assignment.change.after.name -ne '00000000-0000-0000-0000-000000000100') {
    throw "Explicit immutable replacement must use the newly configured GUID: $($assignment.address)"
  }
}
$selectors = @($plan.resource_changes | Where-Object {
  $_.type -eq 'terraform_data' -and $_.name -in @('role_assignment_selector', 'target_role_assignment_selector')
})
if ($selectors.Count -ne 9) { throw 'Expected nine state-only selector resources.' }
foreach ($selector in $selectors) {
  $expected = if ($Scenario -in @('old-resolved-keepers', 'legacy-case-only', 'explicit-guid', 'adopted-guid')) {
    'create'
  } elseif ($Scenario -in @('role-change', 'legacy-role-change', 'explicit-role-change', 'adopted-role-change')) { 'delete+create' } else { 'no-op' }
  if (($selector.change.actions -join '+') -ne $expected) {
    throw "Unexpected selector action: $($selector.address) $($selector.change.actions -join '+')"
  }
}
$assignmentChecks = @($plan.checks | Where-Object {
  $_.address.type -eq 'azapi_resource' -and $_.address.name -in @('role_assignments', 'target_role_assignments') -and
  $null -ne $_.instances -and $_.instances.Count -gt 0
})
if ($assignmentChecks.Count -ne 9 -or @($assignmentChecks | Where-Object status -NE 'unknown').Count) {
  throw 'Deferred lookup validations must remain unknown, not falsely counted as passed.'
}
"PASS: $Scenario; nine stable input role components; reference child parent-ID surface classified separately."
