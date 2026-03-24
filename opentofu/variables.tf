# ============================================================
# Helix Stax Infrastructure — Variables
# ============================================================

# ---- Provider Credentials ------------------------------------

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS and tunnel management"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (required for tunnel creation)"
  type        = string
  sensitive   = true
}

# ---- Cloudflare Zone IDs ------------------------------------

variable "cloudflare_zone_id_com" {
  description = "Cloudflare zone ID for helixstax.com"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id_net" {
  description = "Cloudflare zone ID for helixstax.net"
  type        = string
  sensitive   = true
}

# ---- SSH & Access -------------------------------------------

variable "ssh_key_ids" {
  description = "List of Hetzner SSH key IDs to attach to servers"
  type        = list(number)

  validation {
    condition     = length(var.ssh_key_ids) > 0
    error_message = "At least one SSH key ID must be provided."
  }
}

variable "ssh_public_key" {
  description = "SSH public key content for cloud-init user provisioning"
  type        = string
  sensitive   = true
}

variable "admin_user" {
  description = "Admin username created by cloud-init"
  type        = string
  default     = "wakeem"
}

# ---- CP Server (helix-stax-cp) ------------------------------

variable "cp_server_type" {
  description = "Server type for the K3s control plane"
  type        = string
  default     = "cpx31"
}

variable "cp_image" {
  description = "OS image for the K3s control plane"
  type        = string
  default     = "alma-9"
}

variable "cp_location" {
  description = "Hetzner datacenter location for the K3s control plane"
  type        = string
  default     = "ash"
}

# ---- VPS Server (helix-stax-vps) ----------------------------

variable "vps_server_type" {
  description = "Server type for the services VPS"
  type        = string
  default     = "cpx31"
}

variable "vps_image" {
  description = "OS image for the services VPS"
  type        = string
  default     = "alma-9"
}

variable "vps_location" {
  description = "Hetzner datacenter location for the services VPS"
  type        = string
  default     = "hil"
}

# ---- Test Server (helix-stax-test) --------------------------

variable "test_server_type" {
  description = "Server type for the temporary test server"
  type        = string
  default     = "cpx11" # Cheapest x86 — $4.99/mo
}

variable "test_location" {
  description = "Hetzner datacenter location for the test server"
  type        = string
  default     = "ash"
}
