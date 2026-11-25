param(
  [Parameter(Mandatory)][string]$EvidenceDirectory,
  [string]$TerraformPath,
  [string[]]$Scenarios = @('unchanged', 'case-only', 'role-change', 'principal-change', 'scope-change',
    'old-resolved-keepers', 'legacy-repeat', 'legacy-case-only', 'legacy-role-change',
    'legacy-principal-change', 'legacy-scope-change', 'explicit-guid', 'adopted-guid',
    'legacy-role-mismatch', 'selector-without-metadata-mismatch',
    'explicit-role-change', 'adopted-role-change')
)

# Real provider planning against synthetic state, NOT an applied Azure baseline.
# Never apply these plans. Invalid credentials prevent use of a signed-in context.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$fixture = Join-Path $PSScriptRoot 'fixtures/role_identity'
if (!$TerraformPath) {
  Import-Module Avm.Authoring
  $TerraformPath = (Get-AvmTool -Name terraform -Path $root).Path
}
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
if ($evidence.StartsWith("$root\", [StringComparison]::OrdinalIgnoreCase) -or
  $evidence.StartsWith("$root/", [StringComparison]::OrdinalIgnoreCase) -or
  $evidence -eq $root -or (Test-Path $evidence)) {
  throw 'Choose a new protected evidence directory outside the repository.'
}
New-Item -ItemType Directory $evidence | Out-Null
$oldDataDir = $env:TF_DATA_DIR
$env:TF_DATA_DIR = Join-Path $evidence 'data'

function Invoke-Terraform([string[]]$Arguments) {
  $result = & $TerraformPath "-chdir=$fixture" @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Terraform failed: $($Arguments -join ' ')" }
  return $result
}

function Save-Json($Value, [string]$Path) {
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100))
}

function Get-Resources($Module) {
  foreach ($resource in $Module.resources) { $resource }
  foreach ($child in $Module.child_modules) { Get-Resources $child }
}

# Dynamic attributes require Terraform's typed state representation.
function Get-DynamicType($Value) {
  # All nullable leaves synthesized by this fixture are strings (RBAC inputs).
  if ($null -eq $Value) { return 'string' }
  if ($Value -is [System.Collections.IDictionary]) {
    $members = @{}
    foreach ($key in $Value.Keys) { $members[$key] = Get-DynamicType $Value[$key] }
    return ,@('object', $members)
  }
  if ($Value -is [array]) {
    $types = @($Value | ForEach-Object { ,(Get-DynamicType $_) })
    return ,@('tuple', $types)
  }
  if ($Value -is [bool]) { return 'bool' }
  if ($Value -is [string]) { return 'string' }
  return 'number'
}

try {
  Invoke-Terraform @('init', '-backend=false', '-input=false', '-upgrade=false')
  $freshPath = Join-Path $evidence 'fresh.tfplan'
  Invoke-Terraform @('plan', '-refresh=false', '-input=false', '-no-color', "-out=$freshPath")
  $freshText = Invoke-Terraform @('show', '-json', $freshPath)
  [IO.File]::WriteAllText((Join-Path $evidence 'fresh.json'), ($freshText -join "`n"))
  $fresh = ($freshText -join "`n") | ConvertFrom-Json -AsHashtable
  $schemaText = Invoke-Terraform @('providers', 'schema', '-json')
  $schemas = (($schemaText -join "`n") | ConvertFrom-Json -AsHashtable).provider_schemas
  $resources = @(Get-Resources $fresh.planned_values.root_module)
  $freshUuids = @($resources | Where-Object { $_.type -eq 'random_uuid' -and $_.values.keepers })
  $freshSelectors = @($resources | Where-Object {
    $_.type -eq 'terraform_data' -and $_.name -in @('role_assignment_selector', 'target_role_assignment_selector')
  })
  $freshAssignments = @($resources | Where-Object {
    $_.type -eq 'azapi_resource' -and $_.name -in @('role_assignments', 'target_role_assignments')
  })
  if ($freshUuids.Count -ne 9 -or $freshSelectors.Count -ne 9 -or $freshAssignments.Count -ne 9 -or
    @($freshUuids | Where-Object { $_.values.keepers.role_id -ne 'reader' }).Count -or
    @($freshSelectors | Where-Object { $_.values.triggers_replace -ne 'reader' }).Count -or
    @($freshAssignments | Where-Object { $_.values.replace_triggers_external_values.role_definition_id -ne 'reader' }).Count) {
    throw 'Fresh installation must use nine normalized configured role identity components.'
  }
  'PASS: fresh; all nine UUID keepers, selector resources and external role triggers use reader.'
  $rg = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test'
  $nsp = "$rg/providers/Microsoft.Network/networkSecurityPerimeters/existing"
  $readerId = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  $scopeIds = @{
    'module.perimeter' = "$rg/providers/Microsoft.Network/networkSecurityPerimeters/nsp-role-identity"
    'module.profile' = "$nsp/profiles/profile"
    'module.access_rule' = "$nsp/profiles/profile/accessRules/rule"
    'module.association' = "$nsp/resourceAssociations/association"
    'module.link' = "$nsp/links/link"
    'module.reference' = "$nsp/linkReferences/reference"
  }
  $uuids = @{}
  foreach ($r in $resources | Where-Object type -EQ 'random_uuid') {
    $uuids[$r.address] = [guid]::NewGuid().ToString()
  }
  $stateResources = @()
  foreach ($r in $resources | Where-Object mode -EQ 'managed') {
    $module = $r.address -replace '\.(azapi_resource|random_uuid|terraform_data)\..*$', ''
    if ($module -eq $r.address) { $module = '' }
    $values = $r.values
    switch ($r.type) {
      'random_uuid' {
        $values.id = $uuids[$r.address]
        $values.result = $values.id
      }
      'terraform_data' {
        $values.id = [guid]::NewGuid().ToString()
        if ($r.name -eq 'dep') { $values.input = 'settled'; $values.output = 'settled' }
        else { $values.output = $values.input }
      }
      'azapi_resource' {
        $values.output = @{}
        if ($r.name -eq 'this') {
          $values.id = $scopeIds[$module]
        } elseif ($r.name -eq 'lock') {
          $values.parent_id = $scopeIds[$module]
          $values.id = "$($values.parent_id)/providers/Microsoft.Authorization/locks/$($values.name)"
        } else {
          $isTarget = $r.name -eq 'target_role_assignments'
          $uuidName = if ($isTarget) { 'target_role_assignment_name' } else { 'role_assignment_name' }
          $values.name = $uuids["$module.random_uuid.$uuidName[`"reader`"]"]
          if (!$isTarget) { $values.parent_id = $scopeIds[$module] }
          $values.id = "$($values.parent_id)/providers/Microsoft.Authorization/roleAssignments/$($values.name)"
          $values.body = @{
            properties = @{
              principalId = '00000000-0000-0000-0000-000000000001'
              roleDefinitionId = $readerId
            }
          }
        }
      }
      default { throw "Unaccounted fixture resource: $($r.address)" }
    }
    $resourceSchema = $schemas[$r.provider_name].resource_schemas[$r.type]
    foreach ($attribute in @($values.Keys)) {
      if ($resourceSchema.block.attributes[$attribute].type -eq 'dynamic' -and $null -ne $values[$attribute]) {
        $value = $values[$attribute]
        $values[$attribute] = @{ value = $value; type = Get-DynamicType $value }
      }
    }
    $instance = @{
      schema_version = $resourceSchema.version
      attributes = $values
      sensitive_attributes = @()
    }
    if ($r.ContainsKey('index')) { $instance.index_key = $r.index }
    $binding = @{
      mode = 'managed'; type = $r.type; name = $r.name
      provider = "provider[`"$($r.provider_name)`"]"
      instances = @($instance)
    }
    if ($module) { $binding.module = $module }
    $stateResources += $binding
  }
  $state = @{
    version = 4; terraform_version = $fresh.terraform_version
    serial = 1; lineage = [guid]::NewGuid().ToString()
    outputs = @{}; resources = $stateResources; check_results = $null
  }
  $statePath = Join-Path $evidence 'selector.tfstate'
  Save-Json $state $statePath

  foreach ($scenario in $Scenarios) {
    $selector = switch ($scenario) {
      { $_ -in @('case-only', 'legacy-case-only') } { 'READER' }
      { $_ -in @('role-change', 'legacy-role-change', 'selector-without-metadata-mismatch', 'explicit-role-change', 'adopted-role-change') } { 'Contributor' }
      'legacy-role-mismatch' { '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' }
      default { 'Reader' }
    }
    $scenarioState = ($state | ConvertTo-Json -Depth 100) | ConvertFrom-Json -AsHashtable
    if ($scenario -eq 'old-resolved-keepers' -or $scenario.StartsWith('legacy-') -or
      $scenario -in @('explicit-guid', 'adopted-guid', 'explicit-role-change', 'adopted-role-change')) {
      foreach ($r in $scenarioState.resources) {
        $a = $r.instances[0].attributes
        if ($r.type -eq 'random_uuid' -and $a.keepers) { $a.keepers.role_id = $readerId.ToLowerInvariant() }
        if ($r.type -eq 'azapi_resource' -and $r.name -in @('role_assignments', 'target_role_assignments')) {
          $a.replace_triggers_external_values.value.role_definition_id = $readerId.ToLowerInvariant()
        }
      }
    }
    # First transition has no selector metadata. Repeat/change cases model the
    # retained legacy keepers AFTER the selector resource has entered state.
    # This is synthetic state, not evidence that a migration apply persisted it.
    if ($scenario -in @('old-resolved-keepers', 'legacy-case-only', 'explicit-guid', 'adopted-guid', 'legacy-role-mismatch', 'selector-without-metadata-mismatch')) {
      $scenarioState.resources = @($scenarioState.resources | Where-Object {
        $_.type -ne 'terraform_data' -or $_.name -notin @('role_assignment_selector', 'target_role_assignment_selector')
      })
    }
    $explicit = '00000000-0000-0000-0000-000000000099'
    if ($scenario -in @('explicit-guid', 'adopted-guid', 'explicit-role-change', 'adopted-role-change')) {
      foreach ($r in $scenarioState.resources | Where-Object type -EQ 'azapi_resource') {
        if ($r.name -notin @('role_assignments', 'target_role_assignments')) { continue }
        $a = $r.instances[0].attributes
        $a.name = $explicit
        $a.id = "$($a.parent_id)/providers/Microsoft.Authorization/roleAssignments/$explicit"
        if ($scenario -in @('explicit-guid', 'explicit-role-change')) { $a.replace_triggers_external_values.value.name = $explicit }
      }
    }
    if ($scenario -in @('scope-change', 'legacy-scope-change')) {
      # Model old RBAC scopes, not replacement of their primary owners: the latter
      # invokes AzAPI planning-time GETs even with refresh disabled. These old
      # scope values are synthetic, not a migration operation for consumers.
      foreach ($r in $scenarioState.resources) {
        $a = $r.instances[0].attributes
        if ($r.type -eq 'random_uuid' -and $a.keepers) { $a.keepers.scope += '-old' }
        if ($r.type -eq 'azapi_resource' -and $r.name -in @('role_assignments', 'target_role_assignments')) {
          $a.parent_id += '-old'
          $a.id = "$($a.parent_id)/providers/Microsoft.Authorization/roleAssignments/$($a.name)"
        }
      }
    }
    $scenarioStatePath = Join-Path $evidence "$scenario.tfstate"
    Save-Json $scenarioState $scenarioStatePath
    $planPath = Join-Path $evidence "$scenario.tfplan"
    $arguments = @('plan', '-refresh=false', '-input=false', '-no-color',
      "-state=$scenarioStatePath", "-out=$planPath", "-var=role_selector=$selector")
    if ($scenario -eq 'explicit-guid') { $arguments += "-var=assignment_name=$explicit" }
    if ($scenario -eq 'explicit-role-change') { $arguments += '-var=assignment_name=00000000-0000-0000-0000-000000000100' }
    if ($scenario -in @('principal-change', 'legacy-principal-change')) {
      $arguments += '-var=principal_id=00000000-0000-0000-0000-000000000002'
    }
    if ($scenario -in @('legacy-role-mismatch', 'selector-without-metadata-mismatch')) {
      $failure = & $TerraformPath "-chdir=$fixture" @arguments 2>&1
      if ($LASTEXITCODE -eq 0 -or ($failure -join "`n") -notmatch 'The retained role ID does not match the resolved role') {
        throw 'The first-transition genuine role mismatch must fail before an RBAC write.'
      }
      [IO.File]::WriteAllText((Join-Path $evidence "$scenario.txt"), ($failure -join "`n"))
      "PASS: $scenario rejected at plan by retained-role preconditions."
      continue
    }
    Invoke-Terraform $arguments
    $text = Invoke-Terraform @('show', '-json', $planPath)
    $jsonPath = Join-Path $evidence "$scenario.json"
    [IO.File]::WriteAllText($jsonPath, ($text -join "`n"))
    & (Join-Path $PSScriptRoot 'Assert-RoleIdentityPlan.ps1') -PlanPath $jsonPath -Scenario $scenario
  }
  "PASS: offline synthetic-state regression. Evidence: $evidence"
} finally {
  $env:TF_DATA_DIR = $oldDataDir
}
