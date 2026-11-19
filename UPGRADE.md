# Network Security Perimeter upgrade guide

## Status and baseline

This guide describes the identity-preserving path from released
v0.1.0 (`8c5aaaad4d8674b1e742dd0ad830fa80a66c757a`) to this local candidate.
Bounded independent same-state verification covered adoption with the association
target unchanged and no replacements, subsequent target replacement with owned
locks/RBAC, in-place profile/access-mode changes and normal teardown. Telemetry
was disabled. Evidence is exact-source-specific, not proof for every state or
optional configuration; the unverified exceptions below remain unverified.
Do not apply an upgrade based on mock tests alone. Existing v0.2.0 and
main-sourced consumers must use the qualifications below.

Released v0.2.0 (`b1933fb2b8c857d97a2e642873a768256203f48c`) already
contains the keyed child extraction. The v0.2.0-to-`9c7e545` path was verified
in Azure in the protected r24 evidence, including default-enabled telemetry,
retained identities and normal cleanup. That evidence remains attributed to
`9c7e545`, with its fixture-only known-ID and service-description recoveries.
**The subsequent review changes to assignment UUID generation, role-name lookup,
retry defaults and link-lock replacement have not been verified in Azure.**
The earlier result is not an exact-source pass for this working candidate.
Do not replay child moves when state already has the
destination addresses. Review the candidate's parent-ID, output, root provider
conversion, link-reference and extension-ownership changes against that actual
state, then independently verify the same-state upgrade before applying it to
another deployment. The historical v0.1.0-to-v0.2.0 address-only procedure is
preserved at the end of this guide; it is not the complete candidate migration.

Freeze an exact candidate commit, or a protected immutable full-source snapshot
and verified manifest when committing is not authorized, before Azure verification.
Back up state in
protected storage, retain the backend/workspace, and capture current resource
IDs, child keys, assignment GUIDs, locks/notes and outputs. Keep the original
AzureRM, random and modtm provider configurations available for the one-time
state conversion/removal initialization. Do not indiscriminately discard locks
or upgrade unrelated dependencies.

## Required configuration changes

- Require Terraform >=1.11.0, <2.0 and Azure/azapi >=2.12, <3.0.
- Replace root `resource_group_name` with the **same existing resource group's
  full ARM ID** in `parent_id`. Do not change subscription, resource names,
  locations, keys, or the association's external PaaS identity during adoption.
- Direct child consumers replace `network_security_perimeter_resource_id` with
  `parent_id`; direct access-rule consumers replace `profile_resource_id` with
  `parent_id`. Associations still accept `profile_resource_id` as a reference,
  not their lifecycle parent.
- Child collection outputs are keyed submodule outputs:
  use `profiles[key].resource_id`, `access_rules[key].resource_id` and
  `resource_associations[key].resource_id`. Raw provider objects and their
  `.output`/`.body` attributes are not part of the new contract.
  `resource` contains only `{ id, name }` (lookup references additionally expose
  observed `properties`). Root `resource_id` remains unchanged.
- Review telemetry permissions: managed empty subscription deployments replace
  released random/modtm telemetry. The old telemetry bindings are forgotten
  without destruction. Telemetry can be disabled through the existing opt-out;
  enabled telemetry intentionally causes deployment timestamp writes.
- The released implementation accepted `role_assignments[*].description` but
  did not pass it to AzureRM. During adoption, configure the actual existing
  value (normally null), not a previously ignored non-null input. Setting a new
  description later is an immutable assignment change requiring a separately
  approved replacement plan.

## Automatic module-owned moves — no per-key commands

The candidate contains these declarative moves:

| Released address | Candidate address |
| --- | --- |
| `azapi_resource.network_security_perimeter` | `azapi_resource.this` |
| `azurerm_management_lock.this` | `azapi_resource.lock` |
| `azurerm_role_assignment.this` | `azapi_resource.role_assignments` |

The latter two move **entire collections**, retaining count indices or map keys.
Do not issue per-key state commands for these standard paths. AzAPI v2.12.0's
`azapi_resource` MoveState converter accepts AzureRM sources and initializes
ARM ID, name, parent and type from source state. The original lock name/notes
defaults are preserved. RBAC uses a narrow name ignore to preserve the adopted
AzureRM-generated GUID rather than replacing it with a fresh UUID.
Input-based replacement triggers retain immutable-input behavior; their first
adoption and subsequent changes still require real plan verification.
Lock level and notes changes also retain the released replacement behavior.

Generated role-assignment names now use module-owned UUIDs keyed by normalized
scope, principal and resolved role ID. The new UUID bindings are state-only
additions; existing utility UUID bindings remain in place. The assignment's
name ignore preserves an existing GUID on an unchanged upgrade, while an
intentional principal/role/scope replacement uses a newly generated UUID.
This applies to primary, child and target assignments. For explicit `name`
values, the caller must choose a new GUID when changing principal, role or scope.
Stage ancestor unlock/change/relock as documented below; UUID rotation does not
unlock an unchanged lock. Link-owned locks now follow remote-target replacement
of the link at its unchanged ARM ID.

Role-name lookup uses each assignment's applicable scope (the existing RG for
primary assignments), independently of subscription qualification of tenant-level
role IDs. Defaults now retry `ScopeLocked`, `PrincipalNotFound` and
`LinkedAuthorizationFailed`; custom `retry.error_message_regex` replaces these
patterns and `retry = null` restores provider defaults. These are bounded
replication retries, not permission grants or automatic unlocking.

Composite AzureRM role-assignment state IDs containing `|tenant` are a distinct
**unverified exception**, not proven by tenant-level role-definition prefix
normalization. Do not apply a failing converter plan or create replacement
assignments. Obtain a separately verified scoped forget/import adoption path
that preserves the original GUID. No generic manual recipe is claimed here.

## Explicit keyed child extraction

v0.1.0 had three root `for_each` resources. Released v0.2.0 extracted them into
single-instance child modules without moves. Terraform cannot express a
module-owned wildcard move mapping arbitrary resource keys into module keys.
Add consumer-root **declarative moved blocks for each actual existing key**,
using your real nested module path. For example, for
`module.platform.module.perimeter`:

```hcl
moved {
  from = module.platform.module.perimeter.azapi_resource.nsp_profile["profile1"]
  to   = module.platform.module.perimeter.module.nsp_profile["profile1"].azapi_resource.this
}
moved {
  from = module.platform.module.perimeter.azapi_resource.nsp_access_rule["inbound"]
  to   = module.platform.module.perimeter.module.nsp_access_rule["inbound"].azapi_resource.this
}
moved {
  from = module.platform.module.perimeter.azapi_resource.nsp_resource_association["storage"]
  to   = module.platform.module.perimeter.module.nsp_resource_association["storage"].azapi_resource.this
}
```

Enumerate actual addresses with `terraform state list`; do not copy example
keys or move only one instance of a populated collection. These are same-kind
AzAPI moves, not Azure recreations or imports. Imperative state editing is not
the standard path. v0.2.0 or main-sourced states **already at these target addresses**
do not need these moves again. Direct child-module consumers retain their
existing `azapi_resource.this` addresses.

## v0.2.0 and main-sourced link references

v0.1.0 did not expose links/link references. The 2025-05-01 API supports
link-reference GET/DELETE but no PUT. The candidate uses a data source;
the service/link remains lifecycle owner. Existing v0.2.0 or main-sourced child bindings
are forgotten by the child module's `removed { destroy = false }` block.
Keep the map entries present during that transition so the child module and
its removal declaration are evaluated. Do not remove the whole module call
first or accept a DELETE plan as a migration shortcut. The lookup must find
the existing counterpart.

## New extension ownership is not automatic migration

The original root moved-block addresses and adopted root assignment GUID
behavior are unchanged. New child and cross-reference extensions have new
addresses; they are not silently covered by the old perimeter lock move.

When upgrading a locked v0.1.0 deployment, associated PaaS targets now inherit
the perimeter lock by default. Explicitly review every referenced target before
applying. If its lock belongs to another state, set
`private_link_resource_extensions.lock_inheritance_enabled = false`; similarly
opt out remote perimeters through `remote_perimeter_extensions`.
This prevents duplicate ownership and preserves external extension intent.
Target configuration/tags/lifecycle remain external regardless of lock choice.

Leave new `role_assignments` maps empty unless permissions were explicitly
requested. To deliberately adopt an existing extension, freeze its previous
writer, preserve the exact scope/name/GUID and canonical body, and use a
consumer-root import at its actual nested address. For example:

```hcl
import {
  to = module.platform.module.perimeter.module.nsp_resource_association["storage"].azapi_resource.target_lock[0]
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example/providers/Microsoft.Storage/storageAccounts/example/providers/Microsoft.Authorization/locks/existing-lock"
}
```

This is an **untested deliberate-adoption exception**, not a required command
for every upgrade. Configure the matching target lock name before import.
Do not import an absent object; do not remove bindings from another state until
the handoff is approved and both owner plans have been inspected.

### Working-candidate architecture correction (not a released upgrade hop)

The removed `modules/resource_extensions` wrapper was part of a never-applied,
unreleased local candidate. Each actual child now owns direct
`azapi_resource.lock[0]` and `azapi_resource.role_assignments[key]` bindings.
Associations, links and references use separate `azapi_resource.target_lock[0]`
and `azapi_resource.target_role_assignments[key]` bindings for external targets.
The pure interfaces utility remains at 0.10.0; it does not own these resources.

For comparison only, former candidate addresses under `module.ext` would now
be direct child addresses; former `module.target_ext` (or `[0]`) addresses would
now use the direct `target_` resource labels. No helper state moves are added:
that local candidate was never applied, and deleting it does not require new
migration steps for released v0.1.0 consumers. The released moves, keyed child
extraction exception and reference forget path above are unchanged.
An independently applied experimental wrapper fork is not an advertised upgrade
baseline and requires its own separately reviewed state plan.

Candidate-only control objects are corrected too: under each actual child's
ARM-type slot, use direct `authorization_locks` and
`authorization_role_assignments` fields, not nested helper-shaped objects.
`resource_types` also has direct `authorization_role_definitions`.
Children own stable defaults. Same ARM-kind resources share the override and
ignore list uniformly across their distinct child and target blocks, without
additional per-item precedence. Retry/timeouts continue to cascade unchanged.

Each collection item supports its own `lock`/`role_assignments`. A lookup-only
reference can own extension resources without owning the reference. If remote
extensions are requested for a reference, supply its non-null
`remote_perimeter_resource_id`, matching the GET response. Remote IDs may remain
unknown at plan time when passed from another module's `resource_id`; keep
extension presence, assignment keys and role selectors plan-known. Terraform
preserves creation ordering and can create the remote perimeter and initiating
link in one apply, without separately deploying the remote first. GET-only
references still need a dependency on their producing link when it is also new.
The `child`/`target` keys and managed extension addresses are unchanged; no new
state move or import is required by this composition correction. Its unknown-ID
coverage is provider-mocked plan regression evidence, not live Azure proof.
Manual links without
a remote ARM ID require remote lock opt-out and empty remote RBAC.

Before selective replacement, ReadOnly-protected updates, or descendant
teardown under profile locks, perform a separately approved lock-removal apply,
verify propagation, apply the inspected change, then restore locks separately.
Remove ancestor profile locks first even for full module destroy; profile locks
cannot wait on their root-owned descendant modules without a graph cycle.
Apply ReadOnly profile locks after descendants exist. Bounded ScopeLocked retry
is not an unlock mechanism or Azure propagation proof.

## Required verification before use

### Association immutable-target replacement

Keep the existing `private_link_resource_id` unchanged during adoption.
Subsequent target changes now require delete-before-create of the association:
Azure rejects an in-place PUT to a different PaaS target. Its ARM ID can remain
the same after replacement. Inspect saved-plan actions and replacement paths,
not only IDs. No create-before-destroy or consumer unbind/state edits are needed.
Profile/access-mode edits with a constant target remain in-place.

Owned association-scope locks and Readers are replaced with the association,
including an explicitly configured Reader GUID. Explicitly owned target
extensions move from the old to the new target through their changed scope;
unconfigured or externally owned extensions and both targets remain untouched.
Before selective replacement, stage removal of any applicable ancestor lock
as described above. An unchanged ancestor lock is not an automatic unlock.

### Link/profile ordering

Module-managed links now consume matching local profile resource names rather
than only input strings. This orders profile creation before link creation and
link deletion before local profile deletion, without depending on profile
extensions or deferring link role-definition lookups. The input remains a list
of names, not profile map keys; externally managed names and `*` pass through.
No ARM identity, role assignment GUID or interface changes are intended.

Remote profiles are owned outside this module's local profile collection.
Consumers must wire the actual link owner to remote profile resource outputs
(or an appropriately scoped explicit dependency), including destruction order.
A GET-only `link_references` lookup does not own or delete the relationship and
cannot substitute for that dependency. Standalone link submodule consumers must
likewise supply dependencies on their profile owners. Existing staged ancestor
lock-removal requirements still apply; this change does not unlock resources.

1. Successfully apply the pinned released baseline in an approved isolated
   fixture, then inspect its refreshed plan and capture protected state/readbacks.
2. Switch the **same state** to an immutable candidate, make only the changes
   above, and initialize. For local module sources remove registry `version`.
3. Save a plan and inspect its JSON. Require explained moves/forgets and no
   unintended deletion, replacement, duplicate assignment or lost association.
   Never apply a destructive plan merely to complete the refactor.
4. Apply only that inspected plan under separate Azure authorization. Compare
   independent Azure IDs, GUIDs, lock names/notes, properties and relationships.
5. Require normal refreshed convergence; for risky lists/normalization require
   two no-op infrastructure plans. Classify only the exact telemetry timestamp
   deployment writes, not arbitrary drift.
6. Separately test list add/subset removal/final clear/restore/reorder/retarget,
   external drift, parent metadata writes preserving children, telemetry
   enabled/disabled, full teardown, parent replacement and selective child/RBAC
   replacement under unchanged locks. ReadOnly is a separate case.
7. Verify approved cleanup and empty test state. Failed destroy is not a pass;
   broad resource-group deletion is not an implicit fallback.

Fresh E2E and independent released-state upgrade verification are separate gates.
The bounded verification above does not authorize changes to another deployment
or establish release readiness without the remaining review and validation gates.
Examples are fresh-deployment configurations; their scaffold changes are not an
automatic upgrade path for previously applied example state.

## Rollback limitations

A source revert does not reverse provider state conversion or extraction.
State backups do not reverse Azure mutations. After migration, a rollback needs
its own inspected state/configuration recovery plan; none is proven here.
Do not restore old state blindly or accept destruction to match old addresses.
## Historical v0.1.0-to-v0.2.0 address-only procedure

**v0.2.0 is a published breaking release, not a backwards-compatible patch.**
The following historical procedure targets that release only, not this
candidate. Prefer the consumer-root declarative moves above for a direct
v0.1.0-to-candidate migration; do not combine the two procedures or replay moves.

Existing profiles, access rules, and resource associations need explicit, per-key state-address moves. Do not apply a plan that destroys and recreates these Azure resources. Empty collections need no moves; new deployments have no old state to migrate.

This historical address-only procedure was checked with Terraform **1.17.2**,
PowerShell **7.4+**, and disposable synthetic local state only, not against a
deployed v0.1.0 environment, real provider state, a remote backend, or Azure.
That qualification applies to this procedure, not to the separate bounded
v0.1.0-to-candidate verification described above. Local address checks do not
prove an Azure upgrade plan is safe. Have the state owner review the procedure
and the actual consumer plan before proceeding.

### What changes in v0.2.0

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

### 1. Freeze changes and back up the correct state

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

### 2. Inventory and declare every exact pair

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

### 3. Rehearse on the disposable local copy

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

### 4. Operational handoff, only after independent approval

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

### v0.2.0 breaking output and runtime changes

The state moves do **not** restore the 0.1.0 output contract:

- `profiles` and `resource_associations` return maps of child outputs containing `name`, `resource`, and `resource_id`, rather than raw AzAPI resource maps. Replace uses such as `module.network_security_perimeter.profiles["profile1"].id` with `.resource_id` (or `.resource.id` when the nested object is needed). Apply the same adjustment to association outputs. Preserve the same map keys.
- Full response exports change from `["*"]` to `[]`. Do not assume the previous full `resource.output` payload is available.
- The AzAPI constraint increases from `~> 2.4` to `~> 2.12`; retain your configured provider aliases and compatible lock selections. Terraform remains `>= 1.9, < 2.0`; the offline procedure was checked only with 1.17.2.
- Default-enabled deployment telemetry can create/update empty subscription-scope deployments for the root and instantiated children. Review the subscription-level `Microsoft.Resources/deployments` read/write/delete permissions, or deliberately set `enable_telemetry = false` in accordance with your policy. Those telemetry operations are separate from retaining the existing NSP Azure resources. Historical telemetry-only `removed` blocks are not a migration mechanism for profiles, rules, or associations.

These are explicit **0.2.0 breaking-change notes**, not a claim of backwards compatibility or proof of a real-state migration.
