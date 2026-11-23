# Azure Network Security Perimeter Module

This module is used to manage [Azure Network Security Perimeters (NSP)](https://learn.microsoft.com/en-us/azure/private-link/network-security-perimeter-concepts), including profiles, access rules, and resource associations.

Network Security Perimeter allows Azure PaaS resources to communicate within an explicit trusted boundary by defining network security policies. It provides a centralized approach to managing network access for supported PaaS services without relying solely on individual resource-level firewall rules.

## Features

The module supports:

- Creating a Network Security Perimeter
- Creating NSP profiles to group access rules
- Creating inbound and outbound access rules (address prefixes, FQDNs, subscriptions, service tags)
- Associating PaaS resources with the perimeter via resource associations
- Configuring access modes for resource associations (`Learning`, `Enforced`, `Audit`)
- Explicit role assignments on the perimeter, profiles, rules, associations,
  links, existing link references, referenced PaaS targets and remote perimeters
- Resource locks
- Tagging

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Network Security Perimeter with a Profile and Access Rules

This example creates an NSP with one profile, an inbound rule allowing specific public IP ranges, and an outbound rule allowing access to a storage account FQDN.

> **Note:** Inbound access rules require public IP address prefixes (RFC 1918 private ranges are not allowed). Outbound FQDN rules require fully qualified domain names (wildcard patterns are not supported).

```terraform
module "network_security_perimeter" {
  source = "Azure/avm-res-network-networksecurityperimeter/azapi"

  location            = "eastus2"
  name                = "nsp-demo-eastus2-001"
  parent_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-demo-eastus2-001"

  profiles = {
    profile1 = {
      name = "default-profile"
    }
  }

  access_rules = {
    allow_inbound_public = {
      name             = "allow-inbound-public"
      profile_key      = "profile1"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24", "198.51.100.0/24"]
    }
    allow_outbound_storage = {
      name                         = "allow-outbound-storage"
      profile_key                  = "profile1"
      direction                    = "Outbound"
      fully_qualified_domain_names = ["mystorageaccount.blob.core.windows.net"]
    }
  }
}
```

## Compatibility and operational limits

This candidate is an unreleased breaking refactor. Read
[the upgrade guide](UPGRADE.md) for version-specific state moves, bounded Azure
verification and unverified paths before changing an existing deployment.
Terraform >=1.11.0 and AzAPI >=2.12, <3.0 are required.

Writable children remain independently consumable, single-instance submodules;
the parent owns map cardinality. `parent_id` replaces scope-name inputs.
Link references are **lookup-only**, never created or deleted by this module.
`resource` outputs expose stable identity objects, not raw provider objects.
`resource_id` is the canonical identity output.

Per-resource `resource_types` and `ignore_body_changes` plus shared `retry` and
`timeouts` cascade to writable children. Ignore paths use body-relative dot
notation; ignored configuration is not sent to Azure, and changes take effect
only after apply. Do not ignore owned collections to conceal drift.

Role names resolve case-insensitively at the assignment scope. Lookups and
extension writes on owned resources depend on those resources being created;
referenced targets retain their supplied resource dependencies. Custom roles
inherited from the resource group remain visible. Role-ID subscription
qualification is separate from lookup scope.
With AzAPI there is no Microsoft Graph pre-check: setting
`skip_service_principal_aad_check = true` supplies `principalType = ServicePrincipal`
when no explicit principal type was given. Adopted assignment GUIDs are retained.
Generated assignment UUIDs rotate when the principal, lowercased configured
`role_definition_id_or_name` selector or scope
changes, including target RBAC during association retargeting. Existing assignment
names are retained on unchanged upgrades; additional UUID resources are state-only.
A changed explicit `name` also triggers replacement. If you supply an explicit
GUID, supply a new GUID when changing principal, role or scope.
Case-only role selector changes retain identity. State-only selector resources
track future role changes while a narrow UUID role-keeper ignore preserves
legacy resolved-ID keepers and matching external role triggers. The first
migration must keep the actual role unchanged; a retained role-ID check runs
after lookup and before any RBAC write. Once selector metadata exists, changing
between a name and equivalent ID rotates identity. Missing/divergent UUID state
is not an automatic retention path. See [the upgrade guide](UPGRADE.md) for
prerequisites, bounded synthetic-plan evidence and the independently applied
released v0.2.0 upgrade. That live upgrade retained the generated root Reader
GUID and representative child relationships; it does not prove all nine RBAC
paths. The unreleased `c8b48e8` keeper transition is supplementary and was not
applied: its rejected plan retained assignments but replaced seven telemetry
deployments due to unknown parent IDs. Repeat deferral, case-only live retention
and live immutable mutations remain untested. The lookup-only reference child
also retains a known unknown-parent replacement limitation.
Default retry patterns include `PrincipalNotFound` and `LinkedAuthorizationFailed`
for RBAC replication, as well as `ScopeLocked`; retries do not grant permissions.
Override `retry.error_message_regex` to replace the patterns or set `retry = null`
for provider defaults.

Locks are ordered after writable children and assignments. Default retries cover
`ScopeLocked` propagation errors; they do not unlock an unchanged lock.
Selective deletion/replacement may require staged unlock/change/relock, and
ReadOnly locks may block PUTs. Obtain separate operational approval before
removing a lock or performing any destructive operation.

Telemetry is enabled by default and creates an empty incremental deployment at
the active subscription scope (including instrumented child modules).
The identity needs deployment read/write/delete permissions there.
Set `enable_telemetry = false` to disable it throughout the module graph.
The telemetry `plantimestamp()` update is intentional; it is not a blanket
exception for infrastructure drift.

Provider-mocked tests do not prove Azure persistence, collection removal,
identity preservation, released-state upgrades, or lock teardown.

## Extension ownership and inheritance

Each root collection item accepts canonical `lock` and `role_assignments`
inputs. Extensions live inside that item's submodule, including when consumed
standalone. Child locks default to absent; the perimeter lock already protects
its descendant scopes. Child RBAC defaults to `{}` and is never automatically
granted.

`resource_associations[*].private_link_resource_extensions` and
`links[*].remote_perimeter_extensions` configure extensions on referenced
targets. Link references use `remote_perimeter_resource_id` together with
`remote_perimeter_extensions`; the supplied ID is checked against the reference's
GET response before remote writes. The reference itself remains lookup-only,
even if this module manages extensions at its scope.

Remote perimeter IDs can be passed directly from another module's `resource_id`
while unknown at plan time. Keep collection/assignment keys, extension presence
and role selectors plan-known. Terraform retains the real resource dependency:
the remote perimeter and the initiating link can be created in a single apply;
no separate remote deployment, precomputed ID or targeted apply is required.
Remote-target input checks that need those IDs run once they resolve, before
extension writes. GET-only references still require their service-created object
to exist; when composing its producing link in the same apply, carry that link's
output dependency through the relevant reference input.

For each target, `lock_inheritance_enabled` defaults to `true`. An explicit
target `lock` replaces the perimeter lock configuration; a null/omitted target
lock inherits it. Setting `lock_inheritance_enabled = false` disables that
target lock **even when an override is supplied**. Target RBAC is created only
from its explicitly supplied `role_assignments`. Standalone association/link/
reference modules inherit their own `lock` instead of a root perimeter lock.
Manual links with no remote ARM ID cannot manage remote extensions: disable
remote lock inheritance and leave remote RBAC empty.

The module never writes referenced target configuration or tags and never
deletes the PaaS resource or remote perimeter. Deleting an association/link/
reference module call does delete **extensions owned by that call**; a GET-only
reference remains untouched. Removing an extension while keeping its target
does not transfer target lifecycle ownership.

Consumers must coordinate extension ownership across repeated references,
collection paths and Terraform states. Disable lock inheritance on paths that
do not own the target lock. The module does not perform duplicate-assignment
or GUID-uniqueness checks; Azure enforces its role-assignment constraints.
A PaaS target can have only one association owner in this perimeter.

Existing externally owned locks require opt-out. Existing assignments require
empty RBAC inputs or deliberate state adoption preserving their GUIDs.
AzAPI's create-time existence check rejects an existing ARM object; no automatic
import is introduced for new extensions. Preserve keys after deliberate imports.
All owned assignments retain the narrow name ignore for deliberately adopted GUIDs.

Extension controls are in each child's `resource_types` and
`ignore_body_changes` slots, directly under that child's ARM-type key.
Each child directly declares its locks and RBAC, using
`Azure/avm-utl-interfaces/azure` 0.10.0 for canonical configuration.
Each type slot contains direct `authorization_locks`,
`authorization_role_assignments` and read-only `authorization_role_definitions`
fields. Each ignore slot contains direct `authorization_locks` and
`authorization_role_assignments` path lists. Owning children define their tested
stable API defaults; parent string overrides have no repeated defaults.
Same ARM-kind resources share a field uniformly within the child, including
distinct child-scoped and target-scoped resource blocks. There are no additional
per-item controls or precedence layers; resource bodies and scope ownership
remain separate.
Shared retry/timeouts pass through to every managed extension, not to unsupported
GET-only data-source arguments. Role names are resolved at their assignment
scope, including custom roles inherited from a resource group.

Referenced PaaS IDs are polymorphic: different Private Link-capable ARM types
are supported. They are deliberately not validated against a single resource
type (TFNFR38 exception); the consumer supplies the actual fully-qualified ID.

## Lock staging requirements

Root locks follow children/extensions; each child lock follows its own resource
and RBAC. This does **not** temporarily unlock unchanged locks. Before selective
deletion, immutable replacement, RBAC changes under ReadOnly, or ancestor-profile
descendant teardown:

1. Obtain operational approval and apply removal of **all** applicable owned
   locks (root `lock = null`, affected child `lock = null`, and referenced-target
   `lock_inheritance_enabled = false` as needed). Do not simultaneously change
   protected identities, remove the child module, or alter assignments.
2. Verify removal and wait for Azure propagation, then apply the inspected
   resource/assignment change.
3. Restore the intended locks in a separate apply and verify convergence.

In particular, profile locks protect independently managed root access-rule
modules. Waiting on those modules from inside their parent profile would create
a Terraform graph cycle. Remove profile locks in a separate apply before
descendant teardown **including full module destroy**. Apply ReadOnly profile
locks only after descendant creation. This staged contract also applies to
standalone profiles whose descendants another configuration manages.
Do not infer automatic locked teardown or propagation proof from mocked tests.
## Upgrading existing deployments

Released **v0.2.0 introduced breaking child addresses and output shapes** relative
to v0.1.0; this candidate introduces further interface and ownership changes.
Follow the [upgrade guide](UPGRADE.md) for your exact starting version.
Do not replay already-completed moves. A version bump alone does not preserve
state, and the bounded v0.1.0-to-candidate proof does not verify the
v0.2.0-to-candidate path.
