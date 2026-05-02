locals {
  user_passwords = {
    admin      = var.user_password_admin
    mktxp_user = var.user_password_mktxp_user
    wg-portal  = var.user_password_wg_portal
    homepage   = var.user_password_homepage
  }
}

resource "routeros_system_user_group" "this" {
  for_each = local.user_groups

  name   = each.key
  policy = each.value.policies
}

resource "routeros_system_user" "this" {
  for_each = local.users

  name     = each.key
  group    = each.value.group
  address  = lookup(each.value, "address", null)
  password = lookup(local.user_passwords, each.key, null)

  depends_on = [routeros_system_user_group.this]

  lifecycle {
    ignore_changes = [password]
  }
}
