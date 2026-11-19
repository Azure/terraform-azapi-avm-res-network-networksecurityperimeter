# No ID override: the mocked resource ID is genuinely unknown during PLAN.
module "remote" {
  source   = "../../.."
  for_each = local.remote_instances

  location         = "eastus2"
  name             = "remote"
  parent_id        = local.parent_id
  enable_telemetry = false
  link_references  = local.no_children
  links            = local.no_children
  lock             = local.no_lock
}

module "nested" {
  source   = "../../.."
  for_each = { for key, value in local.cases : key => value if startswith(var.mode, "nested_") }

  location         = "eastus2"
  name             = each.key
  parent_id        = local.parent_id
  enable_telemetry = false
  link_references = var.mode == "nested_reference" ? {
    composed = {
      name                         = "composed"
      remote_perimeter_resource_id = module.remote["remote"].resource_id
      remote_perimeter_extensions = {
        lock             = each.value.remote_lock
        role_assignments = each.value.assignments
      }
    }
  } : {}
  links = var.mode == "nested_link" ? {
    composed = {
      name                                       = "composed"
      auto_approved_remote_perimeter_resource_id = module.remote["remote"].resource_id
      remote_perimeter_extensions = {
        lock             = each.value.remote_lock
        role_assignments = each.value.assignments
      }
    }
  } : {}
  lock = each.value.lock
}
