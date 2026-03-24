import type { Node } from '@xyflow/react'
import type { NodeData } from './CustomNode'

// Layout constants — top-to-bottom layers with manual positions
const LX = {
  left:   80,
  center: 320,
  right:  560,
  far:    800,
}

const LY = {
  edge:     100,
  cluster:  280,
  platform: 460,
  app:      700,
  external: 940,
}

const GAP = 220

function node(
  id: string,
  x: number,
  y: number,
  data: NodeData,
): Node<NodeData> {
  return { id, type: 'custom', position: { x, y }, data }
}

export const initialNodes: Node<NodeData>[] = [
  // Layer 1 — Edge (Cloudflare)
  node('cf-waf', LX.left,   LY.edge, {
    label: 'Cloudflare WAF/CDN',
    description: 'DDoS protection, CDN, DNS, TLS termination',
    layer: 'edge', accentColor: '#52A882', icon: '🛡',
    meta: { Zone: 'helixstax.com + .net', TLS: 'Full Strict', Plan: 'Free/Pro' },
  }),
  node('cf-zt', LX.center, LY.edge, {
    label: 'Zero Trust Access',
    description: 'Cloudflare Access — JWT-based app auth',
    layer: 'edge', accentColor: '#52A882', icon: '🔐',
    meta: { Auth: 'JWT cookie', Provider: 'Zitadel OIDC' },
  }),
  node('cf-tunnel', LX.right, LY.edge, {
    label: 'Cloudflare Tunnel',
    description: 'Outbound tunnel — no inbound firewall holes',
    layer: 'edge', accentColor: '#52A882', icon: '🔗',
    meta: { Daemon: 'cloudflared', Transport: 'QUIC/HTTP2' },
  }),

  // Layer 2 — Cluster (K3s)
  node('traefik', LX.left,   LY.cluster, {
    label: 'Traefik',
    description: 'Ingress controller + ForwardAuth middleware',
    layer: 'cluster', accentColor: '#C4975A', icon: '⚡',
    meta: { CRDs: 'IngressRoute', Auth: 'ForwardAuth → Zitadel' },
  }),
  node('cp', LX.center, LY.cluster, {
    label: 'helix-stax-cp',
    description: 'K3s control plane — Hetzner Cloud CX32',
    layer: 'cluster', accentColor: '#C4975A', icon: '🖥',
    meta: { IP: '178.156.233.12', vCPU: '4', RAM: '8 GB' },
  }),
  node('worker', LX.right, LY.cluster, {
    label: 'helix-stax-vps',
    description: 'K3s worker node — Hetzner Robot i7',
    layer: 'cluster', accentColor: '#C4975A', icon: '🖥',
    meta: { IP: '138.201.131.157', vCPU: '8', RAM: '62 GB' },
  }),

  // Layer 3 — Platform Services
  node('zitadel', LX.left - 60,  LY.platform, {
    label: 'Zitadel',
    description: 'Identity provider — OIDC / SAML / SCIM',
    layer: 'platform', accentColor: '#52A882', icon: '🪪',
    meta: { Domain: 'auth.helixstax.net', Protocol: 'OIDC' },
  }),
  node('cnpg', LX.left + GAP - 60, LY.platform, {
    label: 'CloudNativePG',
    description: 'Managed PostgreSQL operator for K8s',
    layer: 'platform', accentColor: '#52A882', icon: '🗄',
    meta: { HA: 'Primary + replica', Backup: 'Barman → MinIO' },
  }),
  node('valkey', LX.left + GAP * 2 - 60, LY.platform, {
    label: 'Valkey',
    description: 'In-memory cache (Redis-compatible)',
    layer: 'platform', accentColor: '#52A882', icon: '⚡',
    meta: { Protocol: 'RESP', Persistence: 'AOF' },
  }),
  node('minio', LX.left + GAP * 3 - 60, LY.platform, {
    label: 'MinIO',
    description: 'S3-compatible object storage',
    layer: 'platform', accentColor: '#52A882', icon: '🪣',
    meta: { API: 'S3 compatible', TLS: 'Yes' },
  }),
  node('openbao', LX.left + GAP * 4 - 60, LY.platform, {
    label: 'OpenBao + ESO',
    description: 'Secrets management + External Secrets Operator',
    layer: 'platform', accentColor: '#52A882', icon: '🔑',
    meta: { Auth: 'K8s service accounts', Sync: 'ESO → K8s Secrets' },
  }),
  node('devtron', LX.left + GAP * 5 - 60, LY.platform, {
    label: 'Devtron + ArgoCD',
    description: 'GitOps CI/CD — Helm-based deployments',
    layer: 'platform', accentColor: '#52A882', icon: '🚀',
    meta: { Source: 'GitHub', CD: 'ArgoCD sync', Charts: 'Helm' },
  }),

  // Layer 4 — Applications
  node('n8n',      LX.left,             LY.app, {
    label: 'n8n',
    description: 'Workflow automation and API orchestration',
    layer: 'app', accentColor: '#C4975A', icon: '⚙',
    meta: { Domain: 'n8n.helixstax.net' },
  }),
  node('rocketchat', LX.left + GAP,     LY.app, {
    label: 'Rocket.Chat',
    description: 'Team messaging — agent coordination hub',
    layer: 'app', accentColor: '#C4975A', icon: '💬',
    meta: { Domain: 'chat.helixstax.net' },
  }),
  node('monitoring', LX.left + GAP * 2, LY.app, {
    label: 'Monitoring',
    description: 'Prometheus + Grafana + Loki stack',
    layer: 'app', accentColor: '#C4975A', icon: '📊',
    meta: { Metrics: 'Prometheus', Logs: 'Loki', UI: 'Grafana' },
  }),
  node('backstage', LX.left + GAP * 3, LY.app, {
    label: 'Backstage',
    description: 'Developer portal — service catalog + docs',
    layer: 'app', accentColor: '#C4975A', icon: '🗂',
    meta: { Domain: 'portal.helixstax.net' },
  }),
  node('outline', LX.left + GAP * 4, LY.app, {
    label: 'Outline',
    description: 'Knowledge base and internal documentation',
    layer: 'app', accentColor: '#C4975A', icon: '📝',
    meta: { Domain: 'docs.helixstax.net' },
  }),
  node('ollama', LX.left + GAP * 5, LY.app, {
    label: 'Ollama + Open WebUI',
    description: 'Local LLM inference + chat interface',
    layer: 'app', accentColor: '#C4975A', icon: '🤖',
    meta: { Domain: 'ai.helixstax.net', GPU: 'Worker node' },
  }),

  // Layer 5 — External
  node('b2',        LX.left,             LY.external, {
    label: 'Backblaze B2',
    description: 'Off-cluster backup target for PostgreSQL',
    layer: 'external', accentColor: '#4a5568', icon: '☁',
    meta: { Protocol: 'S3 API', Retention: '30 days' },
  }),
  node('github',    LX.left + GAP,       LY.external, {
    label: 'GitHub',
    description: 'Source of truth — GitOps trigger for Devtron',
    layer: 'external', accentColor: '#4a5568', icon: '🐙',
    meta: { Repo: 'helix-stax-infra', CD: 'ArgoCD webhook' },
  }),
  node('gws',       LX.left + GAP * 2,   LY.external, {
    label: 'Google Workspace',
    description: 'Email, calendar, docs — helixstax.com domain',
    layer: 'external', accentColor: '#4a5568', icon: '✉',
    meta: { Domain: 'helixstax.com', MX: 'Google' },
  }),
  node('hetzner',   LX.left + GAP * 3,   LY.external, {
    label: 'Hetzner Cloud',
    description: 'VPS provider — Falkenstein DC (FSN1)',
    layer: 'external', accentColor: '#4a5568', icon: '🏗',
    meta: { Region: 'Falkenstein', Account: 'helix-stax' },
  }),
]
