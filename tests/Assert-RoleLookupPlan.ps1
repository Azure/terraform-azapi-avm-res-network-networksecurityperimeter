param(
  [Parameter(Mandatory)][string]$PlanPath
)
$ErrorActionPreference = 'Stop'
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
$scopes = @{
  'module.perimeter' = 'module.perimeter.data.azapi_resource_list.role_definitions[0]'
  'module.perimeter.module.nsp_profile["profile"]' = 'module.perimeter.module.nsp_profile["profile"].data.azapi_resource_list.role_definitions["child"]'
  'module.perimeter.module.nsp_access_rule["rule"]' = 'module.perimeter.module.nsp_access_rule["rule"].data.azapi_resource_list.role_definitions["child"]'
  'module.profile' = 'module.profile.data.azapi_resource_list.role_definitions["child"]'
}
foreach ($scope in $scopes.Keys) {
  $resource = @($plan.resource_changes | Where-Object address -CEQ "$scope.azapi_resource.this")
  $lookup = @($plan.resource_changes | Where-Object address -CEQ $scopes[$scope])
  $assignment = @($plan.resource_changes | Where-Object address -CEQ "$scope.azapi_resource.role_assignments[`"reader`"]")
  if ($resource.Count -ne 1 -or ($resource[0].change.actions -join '+') -cne 'create') {
    throw "Expected a fresh scope resource: $scope"
  }
  if ($lookup.Count -ne 1 -or ($lookup[0].change.actions -join '+') -cne 'read' -or
    $lookup[0].change.after_unknown.parent_id -ne $true -or
    $lookup[0].action_reason -cnotin @('read_because_config_unknown', 'read_because_dependency_pending')) {
    throw "Role lookup must be deferred until its scope exists: $($scopes[$scope])"
  }
  if ($assignment.Count -ne 1 -or ($assignment[0].change.actions -join '+') -cne 'create' -or
    $assignment[0].change.after_unknown.body.properties.roleDefinitionId -ne $true) {
    throw "Assignment must wait for role-name resolution: $scope"
  }
}
if (@($plan.resource_changes | Where-Object {
  $_.name -cin @('extension_role_definitions', 'extension_ownership')
}).Count) {
  throw 'Aggregate role lookup or ownership guards remain in the dependency graph.'
}
"PASS: all $($scopes.Count) fresh role lookups and assignments are deferred behind their scope resources."
