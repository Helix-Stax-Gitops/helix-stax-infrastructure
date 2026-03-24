# Deep Research: Devtron CI/CD Platform - Full Configuration Guide

## Who I Am
I run Helix Stax, a small IT consulting company. I use AI coding agents to build and operate my infrastructure. My agents need a comprehensive reference for Devtron so they can configure, troubleshoot, and optimize it without hallucinating.

## Our Setup
- K3s v1.32.3 on AlmaLinux 9.7, Hetzner Cloud (helix-stax-cp: 178.156.233.12)
- Identity: Zitadel (OIDC SSO for all services) at zitadel.helixstax.net
- Database: CloudNativePG (PostgreSQL) - Devtron needs PostgreSQL
- TLS: Cloudflare Origin CA (no cert-manager)
- Edge: Cloudflare Tunnel (no open inbound ports)
- Traefik ingress controller (deployed via Helm)
- Monitoring: Prometheus + Grafana + Loki already deployed
- Git: GitHub (KeemWilliams)
- Domain: helixstax.net for internal apps

## What I Need Researched

### 1. Installation on K3s
- Helm chart installation: devtron/devtron chart
- Prerequisites: PostgreSQL version, RAM/CPU needed
- Minimal vs full install (with/without CI, with/without security scanning)
- K3s-specific issues (containerd not Docker, SELinux enforcing)
- Resource requirements for a 4vCPU/8GB server (can it fit alongside monitoring?)
- Installation command with all necessary values overrides
- Post-install: first login, admin password retrieval

### 2. Global Configurations
Research every section from https://docs.devtron.ai/docs/user-guide/global-configurations:
- Host URL (devtron.helixstax.net via tunnel)
- GitOps (bundled ArgoCD configuration)
- Git Accounts (GitHub connection, webhook setup)
- Container/OCI Registry (what to use before Harbor)
- Chart Repositories (adding Helm repos)
- Cluster and Environment (K3s cluster, dev/staging/prod)
- Projects (structure for consulting firm)
- User Management / SSO (Zitadel OIDC integration)
- Notifications (Rocket.Chat webhook, Alertmanager)
- External Links, Catalog Framework, Scoped Variables, Tags

### 3. Bundled ArgoCD
- How it differs from standalone ArgoCD
- Can we use it for infrastructure apps (monitoring, CloudNativePG)?
- Application management via Devtron UI vs ArgoCD UI
- Sync policies, auto-sync, self-heal

### 4. CI Pipeline Configuration
- Build pipeline for Node.js/Python/Go apps
- Kaniko builds (no Docker daemon in K3s)
- Build cache, env vars, secrets
- Security scanning (what replaces Trivy after compromise?)
- Pipeline triggers (webhook, manual, scheduled)

### 5. CD Pipeline Configuration
- Deployment strategies (rolling, blue-green, canary)
- Pre/post deployment hooks
- Approval gates, rollback
- Helm chart deployment vs raw manifests

### 6. Application Creation
- From scratch, from Helm chart, from existing deployment
- ConfigMap and Secret management per app
- Multi-container apps

### 7. Integration with Our Stack
- Managing apps alongside manual Helm installs
- Migrating monitoring stack to Devtron management
- Devtron + Cloudflare Tunnel (IngressRoute)
- Devtron + Traefik
- Resource sharing: Devtron Grafana vs our Grafana

### 8. API and Automation
- REST API endpoints
- CLI tool (devtron-cli)
- n8n integration via API
- Token authentication

### 9. Troubleshooting
- Common K3s installation failures
- PostgreSQL issues
- Build failures (containerd, SELinux)
- Resource exhaustion (4vCPU/8GB server)

### 10. Best Practices for Small Teams
- Minimal setup for solo founder
- Features to enable vs disable
- Resource optimization
- Recommended pipeline patterns

## Required Output Format

### ## SKILL.md Content
Quick reference: CLI, API, config patterns, troubleshooting. Under 500 lines.

### ## reference.md Content
Full installation guide, global config reference, OIDC setup, pipeline config, API reference.

### ## examples.md Content
Real configs: Zitadel OIDC, GitHub, Cloudflare tunnel, Helm values for K3s, example pipelines.

Be thorough and practical. Copy-paste-ready for K3s on Hetzner behind Cloudflare.
