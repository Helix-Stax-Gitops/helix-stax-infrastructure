# ============================================================
# Helix Stax Infrastructure — Outputs
# ============================================================

# ---- CP Server (heart) ---------------------------------------

output "cp_server_id" {
  description = "Hetzner server ID of heart (helix-stax-cp)"
  value       = module.cp_server.server_id
}

output "cp_server_ipv4" {
  description = "Public IPv4 of heart (helix-stax-cp)"
  value       = module.cp_server.server_ipv4
}

output "cp_server_ipv6" {
  description = "Public IPv6 of heart (helix-stax-cp)"
  value       = module.cp_server.server_ipv6
}

# ---- VPS Server (vault) --------------------------------------

output "vps_server_id" {
  description = "Hetzner server ID of vault (helix-stax-vps)"
  value       = module.vps_server.server_id
}

output "vps_server_ipv4" {
  description = "Public IPv4 of vault (helix-stax-vps)"
  value       = module.vps_server.server_ipv4
}

output "vps_server_ipv6" {
  description = "Public IPv6 of vault (helix-stax-vps)"
  value       = module.vps_server.server_ipv6
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
