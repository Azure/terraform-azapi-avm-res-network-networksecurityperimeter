# Tests

Provider-mocked tests run with `avm test unit`.

`Invoke-RoleIdentityPlanRegression.ps1 -EvidenceDirectory <new-private-directory>`
runs 17 pinned real-provider planning scenarios against synthetic state for
configured selector retention, legacy keepers, mismatch rejection and intentional
identity changes. It invokes `Assert-RoleIdentityPlan.ps1` and covers nine UUID
paths; deferred retention covers eight assignments, excluding the lookup-only
reference child's unknown-parent replacement limitation. Never apply these
plans. This is offline provider-plan coverage, not a live keeper migration,
Azure persistence or selective replacement proof.

`fixtures/role_lookup` reproduces fresh NSP/profile/rule scopes whose names and
parent IDs are already known, including a standalone profile with a literal
parent ID. Save a real-provider plan with telemetry disabled, export it with
`terraform show -json`, then run
`.\tests\Assert-RoleLookupPlan.ps1 -PlanPath <plan.json>`. It requires all four
role-name reads to be deferred until their scope resources exist and assignments
to wait for resolution. The fixture must plan without Azure requests; it does
not prove live deployment, role visibility or cleanup.

`Assert-LinkProfileGraph.ps1` verifies reachability in the actual DOT emitted
by `terraform graph -plan=<saved-plan>`. Supply the exact quoted-node contents
as `-LinkNode` and `-ProfileNode` (without the surrounding DOT quotes), and
`-Destroy` for a destroy plan. Plan/apply edges must lead from the link primary
resource to the profile primary resource; destroy edges must lead in reverse.
Use a fixture with a link referencing `profile-b` by name and an arbitrary
profile map key, and include locks/RBAC to expose cycles. The assertion must
fail against the pre-fix graph. This is graph coverage, not live deletion proof.

`Assert-AssociationPlan.ps1` checks saved `terraform show -json` plans using the
real pinned provider, not mocked replacement behavior. Supply the primary
`-AssociationAddress`, `-Case Initial|Unchanged|Retarget|Mutable`, and `-TargetId`.
For retargeting, also supply `-PreviousTargetId` and the exact allowlisted
`-ReplacedExtensionAddresses` (association Reader/lock and any configured target
extensions). It requires delete-before-create, AzAPI's actual `body` replacement
path and unchanged unrelated Azure resources. Run it against the pre-fix failed
retarget plan too: that counterfactual must fail. Pair these plan checks with
actual request ordering, independent readbacks and two normal refreshed no-ops;
mocked applies alone cannot verify provider replacement semantics.
