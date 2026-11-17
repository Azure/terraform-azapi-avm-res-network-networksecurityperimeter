# Upgrading from 0.1.0 to 0.2.0

**0.2.0 is a planned breaking release, not a backwards-compatible patch.** These instructions describe the child-module design following 0.1.0. Wait for the reviewed release before selecting its Registry version.

Existing profiles, access rules, and resource associations need explicit, per-key state-address moves. Do not apply a plan that destroys and recreates these Azure resources. Empty collections need no moves; new deployments have no old state to migrate.

The address procedure was checked with Terraform **1.17.2**, PowerShell **7.4+**, and disposable synthetic local state only. It has **not** been tested against a deployed 0.1.0 environment, real provider state, a remote backend, or Azure. Local address checks do not prove an Azure upgrade plan is safe. Have the state owner review the procedure and the actual consumer plan before proceeding.

## What changes

For each existing map key, use these addresses **relative to the module instance**:

| Collection | 0.1.0 source address | 0.2.0 destination address |
| --- | --- | --- |
| `profiles` | `azapi_resource.nsp_profile["PROFILE_KEY"]` | `module.nsp_profile["PROFILE_KEY"].azapi_resource.this` |
| `access_rules` | `azapi_resource.nsp_access_rule["RULE_KEY"]` | `module.nsp_access_rule["RULE_KEY"].azapi_resource.this` |
| `resource_associations` | `azapi_resource.nsp_resource_association["ASSOCIATION_KEY"]` | `module.nsp_resource_association["ASSOCIATION_KEY"].azapi_resource.this` |

Prefix **both** addresses with the exact existing caller module-instance path and a dot. For example, `module.network_security_perimeter`, or `module.platform["prod"].module.network_security_perimeter["west"]`. When this repository is the Terraform root, there is no prefix or leading dot.

Keep each collection's own key unchanged. A rule or association key is **not** its `profile_key`; map keys need not equal Azure resource names. Preserve all inputs, Azure resource names, parent IDs, provider aliases/bindings, subscription, tenant, and workspace during this address-only step.

The Terraform resource type remains `azapi_resource`, using the same `registry.terraform.io/azure/azapi` provider binding. The Azure resource types and API versions remain:

- Profiles: `Microsoft.Network/networkSecurityPerimeters/profiles@2025-05-01`.
- Access rules: `Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2025-05-01`.
- Associations: `Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01`.

The intended Azure IDs remain `<NSP_ID>/profiles/<profile-name>`, `<NSP_ID>/profiles/<profile-name>/accessRules/<rule-name>`, and `<NSP_ID>/resourceAssociations/<association-name>`, respectively. A move changes Terraform ownership, not those Azure IDs.

There is no reusable wildcard or `for_each` `moved` block for this layout: the old resource-instance key becomes a module-instance key. Move each known instance explicitly; do not move an entire collection to an unkeyed module.

## 1. Freeze changes and back up the correct state

Arrange an exclusive maintenance window. Pause automated plans/applies and other state writers until the configuration and state agree again. Confirm the backend, workspace, caller prefix, and provider bindings. Do not rename keys, change inputs, or change credentials as part of this procedure.

Use PowerShell 7.4 or newer with standard native argument passing. The commands below are **consumer instructions**, not commands executed against real state during the offline check.

From the consumer configuration directory:

```powershell
$ErrorActionPreference = 'Stop'
$PSNativeCommandArgumentPassing = 'Standard'
if (Test-Path Env:TF_DATA_DIR) {
    throw 'Review TF_DATA_DIR in a fresh shell before continuing.'
}
if (Get-ChildItem Env:TF_CLI_ARGS*) {
    throw 'Remove/review implicit Terraform CLI arguments before continuing.'
}
$consumerRoot = (Get-Location).Path
$reviewDirectory = Join-Path $consumerRoot ('nsp-upgrade-review-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $reviewDirectory | Out-Null
$backup = Join-Path $reviewDirectory 'original.tfstate'

terraform workspace show
if ($LASTEXITCODE -ne 0) { throw 'Workspace lookup failed. Stop.' }
$original = terraform state pull
if ($LASTEXITCODE -ne 0) { throw 'State backup failed. Stop.' }
$null = ($original -join "`n") | ConvertFrom-Json
[IO.File]::WriteAllText($backup, ($original -join "`n"), [Text.UTF8Encoding]::new($false))
```

Verify and securely retain the backup, its lineage/serial, and the original configuration and dependency lock file. State files and automatic `.backup` files can contain secrets: restrict access and do not commit, publish, or paste them into issues. Do not overwrite the original backup. A backup is not permission to overwrite newer operational state.

## 2. Inventory and declare every exact pair

Rehearse in the newly created review directory, with no `.tf` files, `.terraform` directory, backend initialization, or remote-state configuration. **Do not run `terraform init` here.** Explicit `-state` flags are local-backend options; they are not a safety boundary inside a directory configured for a remote backend.

```powershell
Push-Location $reviewDirectory
Copy-Item -LiteralPath .\original.tfstate -Destination .\candidate.tfstate
$before = terraform state list `
    '-state=.\candidate.tfstate'
if ($LASTEXITCODE -ne 0) { throw 'Local inventory failed. Stop.' }
$before
```

Review the complete inventory. Record one pair for **every** existing profile, rule, and association under every affected caller instance. Check their original Azure IDs, types, names, parent IDs, and provider bindings in the backup JSON; do not infer keys from Azure names.

The following is an illustrative three-pair list. Replace the prefix and all keys with the exact addresses from your inventory, and add every remaining instance. Omit only collections actually absent from the original state:

```powershell
$prefix = 'module.network_security_perimeter'
$moves = @(
    @{
        From = $prefix + '.azapi_resource.nsp_profile["profile1"]'
        To   = $prefix + '.module.nsp_profile["profile1"].azapi_resource.this'
    }
    @{
        From = $prefix + '.azapi_resource.nsp_access_rule["allow_inbound_public"]'
        To   = $prefix + '.module.nsp_access_rule["allow_inbound_public"].azapi_resource.this'
    }
    @{
        From = $prefix + '.azapi_resource.nsp_resource_association["keyvault1"]'
        To   = $prefix + '.module.nsp_resource_association["keyvault1"].azapi_resource.this'
    }
)
```

For a root invocation, remove `$prefix + '.'` from both endpoints. For nested callers, retain every ancestor module key/index unchanged. For example, `$prefix = 'module.platform["prod"].module.network_security_perimeter["west"]'`.

Addresses contain HCL string syntax inside PowerShell strings. Preserve HCL `\"` and `\\` escapes; double an apostrophe inside a PowerShell single-quoted string. For example, a profile map key whose literal value is `profile "blue"\west's` has this pair:

```powershell
$escapedProfile = @{
    From = 'module.network_security_perimeter.azapi_resource.nsp_profile["profile \"blue\"\\west''s"]'
    To   = 'module.network_security_perimeter.module.nsp_profile["profile \"blue\"\\west''s"].azapi_resource.this'
}
```

Replace the corresponding entry with that pair; do not add a second entry for the same source or destination. Standard PowerShell native argument passing preserves the embedded quotes; do not add the extra quote escaping used by older Windows PowerShell examples.

## 3. Rehearse on the disposable local copy

Preflight **all** pairs before changing the candidate. A missing source or occupied destination is an error, including on a rerun; never silently skip it.

```powershell
$addresses = @(terraform state list `
    '-state=.\candidate.tfstate')
if ($LASTEXITCODE -ne 0) { throw 'Local inventory failed. Stop.' }
if ((@($moves.From | Sort-Object -Unique -CaseSensitive).Count -ne $moves.Count) -or
    (@($moves.To | Sort-Object -Unique -CaseSensitive).Count -ne $moves.Count)) {
    throw 'Duplicate source or destination. Review the pair list.'
}
foreach ($move in $moves) {
    if (($addresses -cnotcontains $move.From) -or ($addresses -ccontains $move.To)) {
        throw "Unexpected source/destination state. Stop and review: $($move.From)"
    }
}
foreach ($move in $moves) {
    terraform state mv `
        '-state=.\candidate.tfstate' `
        '-lock-timeout=5m' `
        $move.From `
        $move.To
    if ($LASTEXITCODE -ne 0) { throw 'Local move failed. Stop; do not continue.' }
}
$after = terraform state list `
    '-state=.\candidate.tfstate'
if ($LASTEXITCODE -ne 0) { throw 'Local result inventory failed. Stop.' }
$after
```

Compare `original.tfstate` with `candidate.tfstate`. For each pair, require source absent, destination present, the exact same Azure ID, `azapi_resource` type, provider binding, resource attributes, and map key now on the module instance. Require all unrelated resources and the original backup unchanged. State serial/dependency bookkeeping may change; a different Azure ID, provider binding, or missing instance is not expected.

If anything fails, stop. For a failed local rehearsal, retain the evidence and start from a **fresh copy** of the original backup in another empty review directory. Do not reset operational state to that backup.

`state mv` is not an idempotent command: a second invocation after success must fail because the source is gone. The preflight deliberately rejects a full rerun before any move. If resuming a partial operational migration later, inventory the current state and reconcile **each** already-moved pair against its original ID, type, provider binding, attributes, and key before a state owner explicitly approves a remaining-pairs list. Both endpoints present, neither present, or an unexpected destination object means stop, not skip or remove.

## 4. Operational handoff, only after independent approval

Everything above can be rehearsed on copies. The following phase is a **separate, state-changing consumer maintenance operation**, not part of the offline verification.

After review, return with `Pop-Location` to the confirmed consumer directory. Keep other writers paused, initialize/select the intended released **0.2.0** configuration through your normal workflow, update the output references below, and retain the same map keys and provider aliases. Before any move, obtain another state backup and compare it with the original inventory; any intervening changes require a new rehearsal.

Do **not** push the edited local state file to a remote backend. Instead, the state owner can replay the reviewed exact pairs against the configured backend. Re-run the same all-pairs presence/conflict and duplicate checks above, but obtain `$addresses` using `terraform state list` **without `-state`**. Only after those checks pass:

```powershell
foreach ($move in $moves) {
    terraform state mv `
        '-lock-timeout=5m' `
        $move.From `
        $move.To
    if ($LASTEXITCODE -ne 0) { throw 'Backend move failed. Stop and reconcile current state.' }
}
```

Keep backend locking enabled. Do not use `-lock=false`, `state rm`, `state push -force`, manual JSON edits to operational state, re-imports, or blanket state removal to suppress conflicts. A partial failure leaves earlier successful moves in place; follow the reconciliation rule above rather than blindly rerunning or restoring a stale backup.

Finally, save and review a complete plan using your normal input files:

```powershell
terraform plan `
    -out=.\nsp-upgrade.tfplan `
    -detailed-exitcode
if ($LASTEXITCODE -notin @(0, 2)) { throw 'Upgrade plan failed. Stop.' }
terraform show `
    .\nsp-upgrade.tfplan
if ($LASTEXITCODE -ne 0) { throw 'Plan review failed. Stop.' }
```

Require **zero unintended creates, deletes, or replacements** of the existing perimeter, profiles, rules, and associations, with all reviewed Azure IDs preserved. Stop on any unexpected infrastructure update too. Do not use `-target`, `-refresh=false`, or a blanket ignore to conceal a bad plan. No apply is authorized by this guide; only an independently approved saved plan may be applied through your normal process. Review a subsequent full plan afterward.

## Breaking output and runtime changes

The state moves do **not** restore the 0.1.0 output contract:

- `profiles` and `resource_associations` return maps of child outputs containing `name`, `resource`, and `resource_id`, rather than raw AzAPI resource maps. Replace uses such as `module.network_security_perimeter.profiles["profile1"].id` with `.resource_id` (or `.resource.id` when the nested object is needed). Apply the same adjustment to association outputs. Preserve the same map keys.
- Full response exports change from `["*"]` to `[]`. Do not assume the previous full `resource.output` payload is available.
- The AzAPI constraint increases from `~> 2.4` to `~> 2.12`; retain your configured provider aliases and compatible lock selections. Terraform remains `>= 1.9, < 2.0`; the offline procedure was checked only with 1.17.2.
- Default-enabled deployment telemetry can create/update empty subscription-scope deployments for the root and instantiated children. Review the subscription-level `Microsoft.Resources/deployments` read/write/delete permissions, or deliberately set `enable_telemetry = false` in accordance with your policy. Those telemetry operations are separate from retaining the existing NSP Azure resources. Historical telemetry-only `removed` blocks are not a migration mechanism for profiles, rules, or associations.

These are explicit **0.2.0 breaking-change notes**, not a claim of backwards compatibility or proof of a real-state migration.
