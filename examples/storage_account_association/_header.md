# Storage Account with Network Security Perimeter

This example deploys a Network Security Perimeter protecting an Azure Storage Account. It demonstrates a real-world scenario where a PaaS resource is associated with an NSP profile to control network access.

The example creates:

- A Network Security Perimeter with a profile for blob storage
- An inbound access rule allowing a corporate IP range
- An inbound access rule allowing same-subscription access
- An outbound access rule allowing FQDN-based access
- A Storage Account associated with the NSP profile in `Learning` mode

The AzAPI-only setup uses Standard_ZRS, TLS 1.2, HTTPS-only traffic, disabled
public network access, disabled anonymous blobs and disabled shared keys.
Learning mode is observational; this example does not claim NSP enforcement.
Choose an authorized region supporting NSP and storage ZRS before deployment.
Local mocked tests do not establish Azure persistence or cleanup.
The association has its own lock; the storage target explicitly opts out of
perimeter lock inheritance but explicitly requests Reader RBAC using the caller
identity. The NSP module never writes storage configuration/tags/lifecycle.
This configuration has not been deployed.

Association-scoped and target-scoped extensions are separate direct AzAPI
resources in the association submodule. Its ARM-kind control fields apply
uniformly to both scopes, without transferring storage ownership.
