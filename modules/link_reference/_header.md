# NSP Link Reference Submodule

This submodule looks up existing link references for a Network Security Perimeter (`Microsoft.Network/networkSecurityPerimeters/linkReferences`).

The service creates the remote counterpart when a link is established. API
2025-05-01 exposes GET and DELETE, but no PUT lifecycle. This submodule never
creates, updates or deletes a link reference. The reference must already exist;
a missing object fails the lookup.

Existing main-sourced `azapi_resource.this` bindings are forgotten with a
module-owned `removed` block (`destroy = false`). The remote object is not deleted.
This is not a replacement owner: lifecycle remains with the link/service.
Telemetry retains its separate opt-out and subscription deployment requirements.

Optional canonical `lock` and `role_assignments` manage extensions at the
existing reference scope, not the reference lifecycle. Direct, separately named
AzAPI resources create/delete only locks and explicitly requested assignments;
the interfaces utility supplies canonical configuration, not lifecycle ownership.
`remote_perimeter_extensions` inherits this submodule's lock by default;
`lock_inheritance_enabled = false` disables the remote lock even with an
override. Remote RBAC defaults empty.

Remote extension management requires a known `remote_perimeter_resource_id`.
Its identity must match `properties.remotePerimeterResourceId` returned by GET.
No remote ID is inferred from an update-sensitive output. Without remote
extensions, omit that ID and explicitly disable inheritance when applying a
reference lock. The reference remains GET-only and is never deleted on teardown.

Direct `authorization_locks` and `authorization_role_assignments` control fields
apply uniformly to the distinct reference and remote extension blocks.
`authorization_role_definitions` controls stable role lookups. This module owns
the stable tested defaults for its direct extensions even though the reference
itself is data-only. Retry/timeouts apply to extensions, not unsupported GET
data-source arguments.
