# Key Vault with Network Security Perimeter

This example deploys a Network Security Perimeter protecting an Azure Key Vault. It demonstrates a real-world scenario where a PaaS resource is associated with an NSP profile to enforce network access control.

The example creates:

- A Network Security Perimeter with a profile
- An inbound access rule allowing a specific public IP range
- An outbound access rule allowing FQDN-based access
- A Key Vault associated with the NSP profile in `Learning` mode
