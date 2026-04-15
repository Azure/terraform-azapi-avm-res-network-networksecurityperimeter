# Storage Account with Network Security Perimeter

This example deploys a Network Security Perimeter protecting an Azure Storage Account. It demonstrates a real-world scenario where a PaaS resource is associated with an NSP profile to control network access.

The example creates:

- A Network Security Perimeter with a profile for blob storage
- An inbound access rule allowing a corporate IP range
- An inbound access rule allowing same-subscription access
- An outbound access rule allowing FQDN-based access
- A Storage Account associated with the NSP profile in `Learning` mode
