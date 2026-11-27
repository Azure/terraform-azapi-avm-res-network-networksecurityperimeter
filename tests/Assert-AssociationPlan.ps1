param(
  [Parameter(Mandatory)][string]$PlanPath,
  [Parameter(Mandatory)][string]$AssociationAddress,
  [Parameter(Mandatory)][ValidateSet('Initial', 'Unchanged', 'Retarget', 'Mutable')][string]$Case,
  [Parameter(Mandatory)][string]$TargetId,
  [string]$PreviousTargetId,
  [string[]]$ReplacedExtensionAddresses = @()
)
$ErrorActionPreference = 'Stop'
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
$association = @($plan.resource_changes | Where-Object address -CEQ $AssociationAddress)
if ($association.Count -ne 1) { throw 'Expected exactly one association resource.' }
$change = $association[0].change
$expected = switch ($Case) {
  Initial { 'create' }
  Unchanged { 'no-op' }
  Retarget { 'delete+create' }
  Mutable { 'update' }
}
if (($change.actions -join '+') -ne $expected) {
  throw "Expected $Case association actions $expected; got $($change.actions -join '+')."
}
if ($change.after.body.properties.privateLinkResource.id -cne $TargetId) {
  throw 'Planned association target does not match the intended target.'
}
if ($Case -eq 'Retarget') {
  if (!$PreviousTargetId -or $PreviousTargetId -ceq $TargetId -or
    $change.before.body.properties.privateLinkResource.id -cne $PreviousTargetId) {
    throw 'Retarget requires distinct, verified before/after targets.'
  }
  if (@($change.replace_paths | Where-Object { ($_ -join '.') -eq 'body' }).Count -ne 1) {
    throw 'Expected the pinned AzAPI provider to report replacement at body.'
  }
}
foreach ($address in $ReplacedExtensionAddresses) {
  $extension = @($plan.resource_changes | Where-Object address -CEQ $address)
  $extensionExpected = if ($Case -eq 'Mutable') { 'no-op' } else { $expected }
  if ($extension.Count -ne 1 -or ($extension[0].change.actions -join '+') -ne $extensionExpected) {
    throw "Owned extension must have actions ${extensionExpected}: $address"
  }
}
foreach ($resource in $plan.resource_changes | Where-Object {
  $_.type -eq 'azapi_resource' -and $_.address -cne $AssociationAddress -and
  $_.address -cnotin $ReplacedExtensionAddresses
}) {
  if (($resource.change.actions -join '+') -ne 'no-op') {
    throw "Unexpected Azure change outside the association and approved extensions: $($resource.address)"
  }
}
if (@($plan.action_invocations | Where-Object { $null -ne $_ }).Count) {
  throw 'Unexpected action invocation.'
}
"PASS $Case association plan: $expected; target=$TargetId"
