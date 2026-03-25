# ============================================================
# Helix Stax Infrastructure — Root Module
#
# Managed nodes (Hetzner Cloud, OpenTofu):
#   heart  — helix-stax-cp  (cpx31, 178.156.233.12)  Control plane + platform + identity
#   vault  — helix-stax-vps (cpx31,   5.78.145.30)   Worker, role TBD — kept for now
#
# Unmanaged node (Hetzner Robot, Ansible only):
#   forge  — helix-stax-ai  (138.201.131.157)         Robot dedicated server (i7-7700/64GB)
#            NOT provisioned by OpenTofu — managed exclusively via Ansible.
#            Robot servers cannot be created/destroyed via Hetzner Cloud API.
#
# Decommissioned:
#   edge   — helix-stax-test (cpx11, 178.156.172.47)  Removed — decommissioned
#
# Firewall strategy:
#   - Hetzner firewall removed — redundant third layer
#   - Edge: Cloudflare WAF + DDoS
#   - Host: firewalld (configured by Ansible)
#   - IDS: CrowdSec (installed by Ansible)
# ============================================================

locals {
  # Known server IPs — used for Ansible inventory generation
  # forge (138.201.131.157) is managed by Ansible only — not tracked here
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
    name = "heart"
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
    role = "worker"
    env  = "production"
    name = "vault"
  }
}

# ============================================================
# Cloudflare Tunnel
# ============================================================

# Tunnel secret — 32-byte random value for tunnel authentication
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Zero Trust tunnel — cloudflared connectors in K3s connect to this
resource "cloudflare_zero_trust_tunnel_cloudflared" "helix_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "helix-hub-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

# ---- DNS Records pointing *.helixstax.net to tunnel --------

resource "cloudflare_record" "tunnel_wildcard_net" {
  zone_id = var.cloudflare_zone_id_net
  name    = "*"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.helix_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  comment = "Managed by OpenTofu — wildcard to Cloudflare Tunnel"
}

resource "cloudflare_record" "tunnel_root_net" {
  zone_id = var.cloudflare_zone_id_net
  name    = "@"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.helix_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  comment = "Managed by OpenTofu — root to Cloudflare Tunnel"
}
