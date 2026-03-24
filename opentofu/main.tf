# ============================================================
# Helix Stax Infrastructure — Root Module
# Servers: helix-stax-cp (CP), helix-stax-vps, helix-stax-test
#
# Firewall strategy:
#   - Hetzner firewall removed — redundant third layer
#   - Edge: Cloudflare WAF + DDoS
#   - Host: firewalld (configured by Ansible)
#   - IDS: CrowdSec (installed by Ansible)
# ============================================================

locals {
  # Known server IPs — used for Ansible inventory generation
  cp_ip  = "178.156.233.12"
  vps_ip = "5.78.145.30"
}

# ---- CP Server -----------------------------------------------
module "cp_server" {
  source = "./modules/hetzner-server"

  name        = "helix-stax-cp"
  server_type = var.cp_server_type
  image       = var.cp_image
  location    = var.cp_location
  ssh_key_ids = var.ssh_key_ids

  user_data = templatefile("${path.module}/cloud-init/alma9-init.yaml.tpl", {
    admin_user     = var.admin_user
    ssh_public_key = var.ssh_public_key
  })

  labels = {
    role = "control-plane"
    env  = "production"
  }
}

# ---- VPS Server ----------------------------------------------
module "vps_server" {
  source = "./modules/hetzner-server"

  name        = "helix-stax-vps"
  server_type = var.vps_server_type
  image       = var.vps_image
  location    = var.vps_location
  ssh_key_ids = var.ssh_key_ids

  user_data = templatefile("${path.module}/cloud-init/alma9-init.yaml.tpl", {
    admin_user     = var.admin_user
    ssh_public_key = var.ssh_public_key
  })

  labels = {
    role = "services"
    env  = "production"
  }
}

# ---- Test Server (temporary validation) ----------------------
module "test_server" {
  source = "./modules/hetzner-server"

  name        = "helix-stax-test"
  server_type = var.test_server_type
  image       = "alma-9"
  location    = var.test_location
  ssh_key_ids = var.ssh_key_ids

  user_data = templatefile("${path.module}/cloud-init/alma9-init.yaml.tpl", {
    admin_user     = var.admin_user
    ssh_public_key = var.ssh_public_key
  })

  labels = {
    role = "test"
    env  = "staging"
  }
}
