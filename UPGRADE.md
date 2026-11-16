# Upgrade from v0.1.0

## Status and baseline

This guide describes the intended identity-preserving path from released
v0.1.0 (`8c5aaaad4d8674b1e742dd0ad830fa80a66c757a`) to this local candidate.
It is **not yet verified against an applied released Azure state**. Do not
apply an upgrade based on mock tests alone. Existing main-sourced consumers
must use the additional qualifications below.

Freeze an exact candidate commit before Azure verification. Back up state in
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
AzureRM-generated GUID rather than replacing it with the utility's fresh UUID.
Input-based replacement triggers retain immutable-input behavior; their first
adoption and subsequent changes still require real plan verification.
Lock level and notes changes also retain the released replacement behavior.

Composite AzureRM role-assignment state IDs containing `|tenant` are a distinct
**unverified exception**, not proven by tenant-level role-definition prefix
normalization. Do not apply a failing converter plan or create replacement
assignments. Obtain a separately verified scoped forget/import adoption path
that preserves the original GUID. No generic manual recipe is claimed here.

## Explicit keyed child extraction

v0.1.0 had three root `for_each` resources. Current main extracted them into
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
the standard path. Main-sourced states **already at these target addresses**
do not need these moves again. Direct child-module consumers retain their
existing `azapi_resource.this` addresses.

## Main-only link references

v0.1.0 did not expose links/link references. The 2025-05-01 API supports
link-reference GET/DELETE but no PUT. The candidate uses a data source;
the service/link remains lifecycle owner. Existing main-sourced child bindings
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
extraction exception and main-only reference forget path above are unchanged.
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
extensions are requested for a reference, supply its known
`remote_perimeter_resource_id`, matching the GET response. Manual links without
a remote ARM ID require remote lock opt-out and empty remote RBAC.

Before selective replacement, ReadOnly-protected updates, or descendant
teardown under profile locks, perform a separately approved lock-removal apply,
verify propagation, apply the inspected change, then restore locks separately.
Remove ancestor profile locks first even for full module destroy; profile locks
cannot wait on their root-owned descendant modules without a graph cycle.
Apply ReadOnly profile locks after descendants exist. Bounded ScopeLocked retry
is not an unlock mechanism or Azure propagation proof.

## Required verification before use

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
Neither is authorized or claimed by this local implementation. Examples are
fresh-deployment configurations; their scaffold changes are not an automatic
upgrade path for previously applied example state.

## Rollback limitations

A source revert does not reverse provider state conversion or extraction.
State backups do not reverse Azure mutations. After migration, a rollback needs
its own inspected state/configuration recovery plan; none is proven here.
Do not restore old state blindly or accept destruction to match old addresses.
