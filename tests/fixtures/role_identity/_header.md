# Offline role identity regression

Run from the repository root:

```powershell
./tests/Invoke-RoleIdentityPlanRegression.ps1 -EvidenceDirectory <new-protected-directory-outside-repo>
```

The script resolves the managed Terraform binary, initializes real AzAPI/random
providers, and creates synthetic state from a fresh plan plus fictitious IDs and
GUIDs. It only plans; it never applies, refreshes Azure, or destroys resources.
The fixture uses deliberately invalid credentials, disabled Azure CLI/MSI/OIDC,
and a pending `terraform_data.dep` change to defer all Azure data reads.
Never apply the saved plans. Do not use this fixture as an E2E example.

Assertions cover all nine root/child/target keeper and external-trigger role
components: fresh creation, unchanged Reader, case-only changes, role/principal/
scope changes, first transition from old resolved-ID keepers/triggers, repeat
deferral with retained keepers and persisted selector metadata, explicit/adopted
GUID retention, and rejection of a known first-transition role mismatch. The body still
waits for the resolved ID. Assignment updates with an unknown body are not
strict no-ops; this test excludes role-driven replacement, not all plan changes.
The lookup-only reference child still replaces on unknown `parent_id`; this
existing, separate cause is asserted rather than counted as a role fix.
Scope-mutation cases synthesize different prior RBAC parent scopes without
replacing the primary owners: owner replacement invokes planning-time AzAPI
GETs and cannot be verified by this credential-isolated fixture.
Repeat cases synthesize selector metadata; no migration apply is performed.

This is a provider-state/plan regression, not an applied released-baseline
upgrade or Azure RBAC/lock/association/persistence/convergence/cleanup proof.
Protect states and plans outside source control and preserve failed attempts
separately when rerunning.
