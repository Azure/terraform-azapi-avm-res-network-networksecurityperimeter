# Default example

This fresh-deployment example combines a profile, inbound/outbound rules,
perimeter Reader assignment and CanNotDelete lock. Supporting resources use
AzAPI. The deployment identity needs role-assignment write permissions and,
when telemetry is enabled, subscription deployment permissions.

The lock is created last and removed first during full teardown. This does not
prove selective rule/assignment replacement under an unchanged lock. Staged
unlock/change/relock requires separate operational authorization.

No Azure deployment or cleanup is claimed by the local mocked tests.
The example combines a perimeter lock, profile RBAC and access-rule lock/RBAC
using the current caller identity. No profile lock is enabled during descendant
creation, avoiding the staged ancestor-lock requirement. This is interaction
configuration, not evidence of Azure deployment or locked teardown.

Child locks and RBAC are direct AzAPI resources in each owning submodule,
configured by the interfaces utility. Extension controls use direct
`authorization_locks` and `authorization_role_assignments` fields beneath the
actual child ARM-type slot; root lock/RBAC controls remain separate.
