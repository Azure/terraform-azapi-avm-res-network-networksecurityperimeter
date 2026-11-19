# NSP Link Submodule

This submodule manages links for a Network Security Perimeter (`Microsoft.Network/networkSecurityPerimeters/links`).

Links connect two Network Security Perimeters to allow traffic between them, with configurable local and remote inbound profiles.
## Extension ownership

Canonical `lock` and `role_assignments` apply to the link scope.
`remote_perimeter_extensions` manages only remote-perimeter extensions.
Its `lock_inheritance_enabled` defaults true: an explicit target lock overrides
the owning module lock; false disables it even with an override.
Standalone calls inherit the link lock; root calls inherit the primary perimeter
lock. Remote RBAC is never automatic.

The remote perimeter's configuration, tags and lifecycle remain external.
The remote ID may come directly from another module's `resource_id` and remain
unknown during planning. Keep extension presence, assignment keys and role
selectors plan-known; the ID is only a scope value. Terraform retains the
dependency on the remote perimeter and can create it before the link in one
apply, without a separate remote deployment or targeted apply.
Manual links without a remote ARM ID cannot manage remote extensions and must
disable remote lock inheritance when an inherited lock would otherwise apply.
Existing extensions require opt-out or deliberate adoption. Remove applicable
locks in a separate approved apply before selective replacement or ReadOnly
updates; restore them only after the inspected change.

The owning module directly declares separate child and target lock/RBAC blocks,
using the interfaces utility for canonical configuration. Direct
`authorization_locks` and `authorization_role_assignments` controls apply uniformly
to both scopes; `authorization_role_definitions` controls stable role lookups.
Tested API defaults belong here, not in the parent.
