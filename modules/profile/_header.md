# NSP Profile Submodule

This submodule manages profiles for a Network Security Perimeter (`Microsoft.Network/networkSecurityPerimeters/profiles`).

Profiles group access rules that define the network access policies for the perimeter.
## Extensions and lock staging

Canonical `role_assignments` and optional `lock` are implemented inside this
standalone profile owner as direct AzAPI resources. No automatic RBAC is granted.
The interfaces utility supplies canonical lock and RBAC configuration without
owning Azure resources. This module owns its tested API defaults and direct
`authorization_locks` / `authorization_role_assignments` ignore fields.

Profile locks protect descendant access rules managed by other module calls.
Remove profile locks in a separate approved apply before descendant replacement
or teardown, including full module destroy. Waiting on the root's descendant
modules from inside this parent module would create a graph cycle. Apply
ReadOnly profile locks only after descendants exist. ScopeLocked retries do not
unlock unchanged locks or prove propagation.
