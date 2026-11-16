# NSP Access Rule Submodule

This submodule manages access rules for Network Security Perimeter profiles (`Microsoft.Network/networkSecurityPerimeters/profiles/accessRules`).

Access rules define inbound and outbound network access policies for a profile, using address prefixes, FQDNs, subscriptions, service tags, email addresses, or phone numbers.
## Extensions

Canonical `role_assignments` and optional `lock` are owned inside this
standalone access-rule module. The lock follows the rule and its assignments.
RBAC is created only when explicitly supplied. Before selective replacement
under an unchanged rule, profile or perimeter lock, remove all applicable locks
in a separate approved apply, verify propagation, change the resource, then
restore locks separately.

The module directly declares AzAPI locks/RBAC; the interfaces utility supplies
canonical configuration only. Direct `authorization_locks`,
`authorization_role_assignments` and `authorization_role_definitions` type fields
own their stable tested defaults here; ignore lists use the corresponding
managed-resource fields.
