# ============================================================
# Helix Stax Infrastructure — Outputs
# ============================================================

# ---- CP Server -----------------------------------------------

output "cp_server_id" {
  description = "Hetzner server ID of the K3s control plane"
  value       = module.cp_server.server_id
}

output "cp_server_ipv4" {
  description = "Public IPv4 of the K3s control plane"
  value       = module.cp_server.server_ipv4
}

output "cp_server_ipv6" {
  description = "Public IPv6 of the K3s control plane"
  value       = module.cp_server.server_ipv6
}

# ---- VPS Server ----------------------------------------------

output "vps_server_id" {
  description = "Hetzner server ID of the services VPS"
  value       = module.vps_server.server_id
}

output "vps_server_ipv4" {
  description = "Public IPv4 of the services VPS"
  value       = module.vps_server.server_ipv4
}

output "vps_server_ipv6" {
  description = "Public IPv6 of the services VPS"
  value       = module.vps_server.server_ipv6
}

# ---- Test Server ---------------------------------------------

output "test_server_id" {
  description = "Hetzner server ID of the temporary test server"
  value       = module.test_server.server_id
}

output "test_server_ipv4" {
  description = "Public IPv4 of the temporary test server"
  value       = module.test_server.server_ipv4
}

output "test_server_ipv6" {
  description = "Public IPv6 of the temporary test server"
  value       = module.test_server.server_ipv6
}

# ---- Cloudflare Tunnel --------------------------------------

output "tunnel_id" {
  description = "Cloudflare Tunnel ID for helix-hub-tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.helix_tunnel.id
}

output "tunnel_token" {
  description = "Cloudflare Tunnel token — inject into K8s secret for cloudflared"
  value       = cloudflare_zero_trust_tunnel_cloudflared.helix_tunnel.tunnel_token
  sensitive   = true
}
