# NSP Resource Association Submodule

This submodule manages resource associations for a Network Security Perimeter (`Microsoft.Network/networkSecurityPerimeters/resourceAssociations`).

Resource associations link Azure PaaS resources to the perimeter, with configurable access modes (`Learning`, `Enforced`, `Audit`).

## Retargeting

The PaaS target is immutable. Changing `private_link_resource_id` deletes the
association before recreating it with the new target, even when its name and ARM
ID stay the same. Association-scope locks and role assignments follow that
replacement; explicit assignment GUIDs remain configured. Profile and access-mode
changes do not require association replacement.

Remove applicable ancestor locks in a separate approved apply before retargeting,
verify removal, then apply the inspected replacement plan and restore locks
separately. ReadOnly locks also block updates. An unchanged ancestor lock is not
automatically removed. Target-scoped extensions move only when explicitly owned
through `private_link_resource_extensions`; neither PaaS target is owned here.
## Extension ownership

Canonical `lock` and `role_assignments` apply to the association scope.
`private_link_resource_extensions` manages only extensions at the referenced
PaaS target. Its `lock_inheritance_enabled` defaults true: an explicit target
lock overrides the owning module lock; false disables it even with an override.
Standalone calls inherit the association lock; root calls inherit the primary
perimeter lock. Target RBAC is never automatic.

The PaaS target's configuration, tags and lifecycle remain externally owned.
Exactly one state must own each extension. Existing extensions require opt-out
or deliberate adoption. Removing this module call deletes its owned extensions,
not the PaaS target. Staged removal of applicable locks is required before
selective replacement or ReadOnly-protected updates.

This owner directly declares separate child and target lock/RBAC blocks using
the interfaces utility for canonical configuration. Direct `authorization_locks`
and `authorization_role_assignments` controls apply uniformly to both scopes;
`authorization_role_definitions` controls stable role lookups. Tested API
defaults belong here, not in the parent. PaaS IDs are polymorphic and deliberately
have no single-type resource-ID validation under the TFNFR38 exception.
