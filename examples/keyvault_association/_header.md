# Key Vault with Network Security Perimeter

This example deploys a Network Security Perimeter protecting an Azure Key Vault. It demonstrates a real-world scenario where a PaaS resource is associated with an NSP profile to enforce network access control.

The example creates:

- A Network Security Perimeter with a profile
- An inbound access rule allowing a specific public IP range
- An inbound access rule allowing same-subscription access
- A Key Vault associated with the NSP profile in `Learning` mode

The Key Vault's public network access is disabled and RBAC authorization, soft
delete and purge protection are enabled. NSP Learning mode is observational,
not an assertion that NSP enforcement has been tested. There are no data-plane
operations or public-access exceptions in the setup.

Purge protection retains a soft-deleted vault for at least seven days; normal
Terraform destroy does not purge it. A future E2E authorization must explicitly
cover this retention and its owner. No Azure deployment, persistence or cleanup
has been verified for this local candidate.
The perimeter lock is inherited onto the externally owned Key Vault target;
Reader RBAC is explicitly requested on that target using the caller identity.
The NSP module owns only the association and its target extensions, not the
vault's configuration or lifecycle. These interactions have not been deployed.

The association submodule directly declares its target lock and RBAC resources;
the interfaces utility supplies canonical configuration only. The Key Vault
remains owned by this example, not by the association or utility.
