# Azure Network Security Perimeter Module

This module is used to manage [Azure Network Security Perimeters (NSP)](https://learn.microsoft.com/en-us/azure/private-link/network-security-perimeter-concepts), including profiles, access rules, and resource associations.

Network Security Perimeter allows Azure PaaS resources to communicate within an explicit trusted boundary by defining network security policies. It provides a centralized approach to managing network access for supported PaaS services without relying solely on individual resource-level firewall rules.

## Features

The module supports:

- Creating a Network Security Perimeter
- Creating NSP profiles to group access rules
- Creating inbound and outbound access rules (address prefixes, FQDNs, subscriptions, service tags)
- Associating PaaS resources with the perimeter via resource associations
- Configuring access modes for resource associations (`Learning`, `Enforced`, `Audit`)
- Role assignments on the perimeter resource
- Resource locks
- Tagging

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Network Security Perimeter with a Profile and Access Rules

This example creates an NSP with one profile, an inbound rule allowing specific public IP ranges, and an outbound rule allowing access to a storage account FQDN.

> **Note:** Inbound access rules require public IP address prefixes (RFC 1918 private ranges are not allowed). Outbound FQDN rules require fully qualified domain names (wildcard patterns are not supported).

```terraform
module "network_security_perimeter" {
  source = "Azure/avm-res-network-networksecurityperimeter/azapi"

  location            = "eastus2"
  name                = "nsp-demo-eastus2-001"
  resource_group_name = "rg-demo-eastus2-001"

  profiles = {
    profile1 = {
      name = "default-profile"
    }
  }

  access_rules = {
    allow_inbound_public = {
      name             = "allow-inbound-public"
      profile_key      = "profile1"
      direction        = "Inbound"
      address_prefixes = ["203.0.113.0/24", "198.51.100.0/24"]
    }
    allow_outbound_storage = {
      name                         = "allow-outbound-storage"
      profile_key                  = "profile1"
      direction                    = "Outbound"
      fully_qualified_domain_names = ["mystorageaccount.blob.core.windows.net"]
    }
  }
}
```
