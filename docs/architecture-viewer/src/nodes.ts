import type { Node } from '@xyflow/react'
import type { NodeData } from './CustomNode'

// Layout constants — top-to-bottom layers with manual positions
const LX = {
  col0:   60,
  col1:  280,
  col2:  500,
  col3:  720,
  col4:  940,
  col5: 1160,
  col6: 1380,
}

const LY = {
  edge:     100,
  cluster:  310,
  platform: 520,
  app:      760,
  external: 1000,
}

function node(
  id: string,
  x: number,
  y: number,
  data: NodeData,
): Node<NodeData> {
  return { id, type: 'custom', position: { x, y }, data }
}

export const initialNodes: Node<NodeData>[] = [
  // ── Layer 1 — Edge (Cloudflare) ──────────────────────────────────────────
  node('cf-waf', LX.col0, LY.edge, {
    label: 'Cloudflare WAF/CDN',
    description: 'DDoS protection, CDN, DNS, TLS termination',
    layer: 'edge', accentColor: '#52A882', icon: '🛡',
    meta: { Zone: 'helixstax.com + .net', TLS: 'Full Strict', Plan: 'Free/Pro' },
  }),
  node('cf-zt', LX.col1, LY.edge, {
    label: 'Zero Trust Access',
    description: 'Cloudflare Access — JWT-based app auth',
    layer: 'edge', accentColor: '#52A882', icon: '🔐',
    meta: { Auth: 'JWT cookie', Provider: 'Zitadel OIDC' },
  }),
  node('cf-tunnel', LX.col2, LY.edge, {
    label: 'Cloudflare Tunnel',
    description: 'Outbound tunnel — no inbound firewall holes',
    layer: 'edge', accentColor: '#52A882', icon: '🔗',
    meta: { Daemon: 'cloudflared', Transport: 'QUIC/HTTP2' },
  }),

  // ── Layer 2 — Kubernetes Cluster (4 nodes) ───────────────────────────────
  node('traefik', LX.col0, LY.cluster, {
    label: 'Traefik',
    description: 'Ingress controller + ForwardAuth middleware',
    layer: 'cluster', accentColor: '#C4975A', icon: '⚡',
    meta: { Namespace: 'traefik', CRDs: 'IngressRoute', Auth: 'ForwardAuth → Zitadel' },
  }),
  node('cp', LX.col1, LY.cluster, {
    label: 'heart (CP)',
    description: 'K3s control plane — cpx31 (4 vCPU, 8 GB RAM)',
    layer: 'cluster', accentColor: '#C4975A', icon: '🖥',
    meta: { IP: '178.156.233.12', vCPU: '4', RAM: '8 GB', Location: 'Ashburn VA', Workload: 'platform' },
  }),
  node('edge-node', LX.col2, LY.cluster, {
    label: 'edge (test)',
    description: 'K3s worker — cpx11 (2 vCPU, 2 GB) — decommission candidate',
    layer: 'cluster', accentColor: '#C4975A', icon: '🖥',
    meta: { IP: '178.156.172.47', vCPU: '2', RAM: '2 GB', Location: 'Ashburn VA', Status: 'decommission candidate' },
  }),
  node('vault-node', LX.col3, LY.cluster, {
    label: 'vault (VPS)',
    description: 'K3s worker — cpx31 (4 vCPU, 8 GB) — forge workloads',
    layer: 'cluster', accentColor: '#C4975A', icon: '🖥',
    meta: { IP: '5.78.145.30', vCPU: '4', RAM: '8 GB', Location: 'Hillsboro OR', Workload: 'forge' },
  }),
  node('forge-node', LX.col4, LY.cluster, {
    label: 'forge (AI)',
    description: 'K3s worker — i7-7700, 64 GB RAM — AI/LLM workloads',
    layer: 'cluster', accentColor: '#C4975A', icon: '🖥',
    meta: { IP: '138.201.131.157', CPU: 'i7-7700', RAM: '64 GB', Location: 'Germany', Workload: 'forge / AI' },
  }),
  node('crowdsec', LX.col5, LY.cluster, {
    label: 'CrowdSec',
    description: 'Host-level IDS/IPS on all 4 nodes',
    layer: 'cluster', accentColor: '#C4975A', icon: '🛡',
    meta: { Type: 'Host-level IDS', Nodes: 'All 4', Integration: 'Traefik bouncer' },
  }),

  // ── Layer 3 — Platform Services (deployed — green) ───────────────────────
  node('zitadel', LX.col0, LY.platform, {
    label: 'Zitadel',
    description: 'OIDC/SAML identity provider — SSO for all services',
    layer: 'platform', accentColor: '#52A882', icon: '🪪',
    meta: { Domain: 'zitadel.helixstax.net', Namespace: 'identity', Protocol: 'OIDC/SAML', Status: 'deployed' },
  }),
  node('cnpg', LX.col1, LY.platform, {
    label: 'CloudNativePG',
    description: 'Managed PostgreSQL — primary + replica HA',
    layer: 'platform', accentColor: '#52A882', icon: '🗄',
    meta: { Namespace: 'database', HA: 'Primary + replica', Backup: 'Barman → MinIO', Status: 'deployed' },
  }),
  node('valkey', LX.col2, LY.platform, {
    label: 'Valkey',
    description: 'Redis-compatible in-memory cache',
    layer: 'platform', accentColor: '#52A882', icon: '⚡',
    meta: { Namespace: 'database', Protocol: 'RESP', Persistence: 'AOF', Status: 'deployed' },
  }),
  node('devtron', LX.col3, LY.platform, {
    label: 'Devtron + ArgoCD',
    description: 'GitOps CI/CD — Helm-based deployments via GitOps',
    layer: 'platform', accentColor: '#52A882', icon: '🚀',
    meta: { Namespace: 'devtroncd', Source: 'GitHub', CD: 'ArgoCD sync', Charts: '12 repos', Status: 'deployed' },
  }),
  node('monitoring', LX.col4, LY.platform, {
    label: 'Prometheus + Grafana',
    description: 'Metrics scraping, 35+ dashboards, SLO/HIPAA compliance views',
    layer: 'platform', accentColor: '#52A882', icon: '📊',
    meta: { Namespace: 'monitoring', Metrics: 'Prometheus', Dashboards: '35+', Compliance: 'HIPAA 87.5%', Status: 'deployed' },
  }),
  node('alertmanager', LX.col5, LY.platform, {
    label: 'Alertmanager',
    description: 'Alert routing — Prometheus → notifications',
    layer: 'platform', accentColor: '#52A882', icon: '🔔',
    meta: { Namespace: 'monitoring', Source: 'Prometheus', Routes: 'Rocket.Chat / n8n (planned)', Status: 'deployed' },
  }),

  // ── Layer 4 — Applications ────────────────────────────────────────────────
  // Deployed (active)
  node('n8n', LX.col0, LY.app, {
    label: 'n8n',
    description: 'Workflow automation and API orchestration',
    layer: 'app', accentColor: '#C4975A', icon: '⚙',
    meta: { Domain: 'n8n.helixstax.net', Namespace: 'automation', DB: 'PostgreSQL', Status: 'deployed' },
  }),
  node('rocketchat', LX.col1, LY.app, {
    label: 'Rocket.Chat',
    description: 'Team messaging — agent coordination hub (planned)',
    layer: 'planned', accentColor: '#4a5568', icon: '💬',
    meta: { Domain: 'chat.helixstax.net', Namespace: 'forge', Needs: 'MongoDB secret', Status: 'planned' },
  }),
  node('minio', LX.col2, LY.app, {
    label: 'MinIO',
    description: 'S3-compatible object storage (planned)',
    layer: 'planned', accentColor: '#4a5568', icon: '🪣',
    meta: { API: 'S3 compatible', TLS: 'Yes', Needs: 'IngressRoute + access key', Status: 'planned' },
  }),
  node('harbor', LX.col3, LY.app, {
    label: 'Harbor',
    description: 'Container registry (planned)',
    layer: 'planned', accentColor: '#4a5568', icon: '📦',
    meta: { Domain: 'registry.helixstax.net', Needs: 'IngressRoute + admin secret', Status: 'planned' },
  }),
  node('ollama', LX.col4, LY.app, {
    label: 'Ollama + Open WebUI',
    description: 'Local LLM inference on forge node (planned)',
    layer: 'planned', accentColor: '#4a5568', icon: '🤖',
    meta: { Domain: 'ai.helixstax.net', Node: 'forge', Needs: 'IngressRoute', Status: 'planned' },
  }),
  node('velero', LX.col5, LY.app, {
    label: 'Velero',
    description: 'K8s backup — needs MinIO first (planned)',
    layer: 'planned', accentColor: '#4a5568', icon: '💾',
    meta: { Backend: 'MinIO → Backblaze B2', Needs: 'MinIO running', Status: 'planned' },
  }),
  node('loki', LX.col6, LY.app, {
    label: 'Loki',
    description: 'Log aggregation — datasource configured, deploy pending',
    layer: 'planned', accentColor: '#4a5568', icon: '📋',
    meta: { Datasource: 'Grafana (configured)', Status: 'planned' },
  }),

  // ── Layer 5 — External Providers ─────────────────────────────────────────
  node('b2', LX.col0, LY.external, {
    label: 'Backblaze B2',
    description: 'Off-cluster backup target for PostgreSQL + MinIO',
    layer: 'external', accentColor: '#4a5568', icon: '☁',
    meta: { Protocol: 'S3 API', Retention: '30 days' },
  }),
  node('github', LX.col1, LY.external, {
    label: 'GitHub',
    description: 'Source of truth — GitOps trigger for Devtron/ArgoCD',
    layer: 'external', accentColor: '#4a5568', icon: '🐙',
    meta: { Repo: 'helix-stax-infrastructure', CD: 'ArgoCD webhook' },
  }),
  node('gws', LX.col2, LY.external, {
    label: 'Google Workspace',
    description: 'Email, calendar — helixstax.com domain. Google IdP in Zitadel',
    layer: 'external', accentColor: '#4a5568', icon: '✉',
    meta: { Domain: 'helixstax.com', MX: 'Google', Role: 'IdP in Zitadel' },
  }),
  node('hetzner', LX.col3, LY.external, {
    label: 'Hetzner Cloud',
    description: 'VPS provider — Ashburn VA (CP + test) and Germany (AI)',
    layer: 'external', accentColor: '#4a5568', icon: '🏗',
    meta: { Regions: 'Ashburn VA + Germany', Nodes: '4 active', Account: 'helix-stax' },
  }),
]
