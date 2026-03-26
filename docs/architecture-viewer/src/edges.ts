import type { Edge } from '@xyflow/react'

const traffic = {
  animated: true,
  style: { stroke: '#52A882', strokeWidth: 2 },
}

const trafficDashed = {
  animated: true,
  style: { stroke: '#52A882', strokeWidth: 1.5, strokeDasharray: '6 3' },
}

const internal = {
  animated: false,
  style: { stroke: '#30363d', strokeWidth: 1.5 },
}

const external = {
  animated: false,
  style: { stroke: '#4a5568', strokeWidth: 1.5, strokeDasharray: '5 4' },
}

// Planned connections — dashed grey
const planned = {
  animated: false,
  style: { stroke: '#4a5568', strokeWidth: 1, strokeDasharray: '4 6', opacity: 0.5 },
}

// Monitoring scrape connections
const scrape = {
  animated: true,
  style: { stroke: '#C4975A', strokeWidth: 1.5, strokeDasharray: '3 5', opacity: 0.7 },
}

// SSO auth connections
const ssoAuth = {
  animated: true,
  style: { stroke: '#52A882', strokeWidth: 1.5, strokeDasharray: '5 3', opacity: 0.8 },
}

export const initialEdges: Edge[] = [
  // ── Internet → Cloudflare edge ───────────────────────────────────────────
  { id: 'e-inet-waf',    source: 'cf-waf',    target: 'cf-zt',       ...traffic,       label: 'Internet traffic' },
  { id: 'e-waf-zt',      source: 'cf-zt',     target: 'cf-tunnel',   ...traffic },

  // ── Cloudflare → Cluster ─────────────────────────────────────────────────
  { id: 'e-tunnel-traf', source: 'cf-tunnel', target: 'traefik',     ...trafficDashed, label: 'cloudflared' },

  // ── Traefik → Services (deployed — active) ───────────────────────────────
  { id: 'e-traf-n8n',    source: 'traefik',   target: 'n8n',         ...traffic },
  { id: 'e-traf-mon',    source: 'traefik',   target: 'monitoring',  ...traffic },
  { id: 'e-traf-dev',    source: 'traefik',   target: 'devtron',     ...traffic },
  { id: 'e-traf-zit',    source: 'traefik',   target: 'zitadel',     ...ssoAuth,       label: 'ForwardAuth' },

  // ── Traefik → Planned services ───────────────────────────────────────────
  { id: 'e-traf-rc',     source: 'traefik',   target: 'rocketchat',  ...planned },
  { id: 'e-traf-minio',  source: 'traefik',   target: 'minio',       ...planned },
  { id: 'e-traf-harbor', source: 'traefik',   target: 'harbor',      ...planned },
  { id: 'e-traf-oll',    source: 'traefik',   target: 'ollama',      ...planned },

  // ── 4-node cluster topology ──────────────────────────────────────────────
  { id: 'e-cp-edge',     source: 'cp',        target: 'edge-node',   ...internal,      label: 'K3s cluster' },
  { id: 'e-cp-vault',    source: 'cp',        target: 'vault-node',  ...internal },
  { id: 'e-cp-forge',    source: 'cp',        target: 'forge-node',  ...internal },

  // ── CrowdSec on all nodes ────────────────────────────────────────────────
  { id: 'e-csec-cp',     source: 'crowdsec',  target: 'cp',          ...internal,      label: 'IDS' },
  { id: 'e-csec-edge',   source: 'crowdsec',  target: 'edge-node',   ...internal },
  { id: 'e-csec-vault',  source: 'crowdsec',  target: 'vault-node',  ...internal },
  { id: 'e-csec-forge',  source: 'crowdsec',  target: 'forge-node',  ...internal },

  // ── Zitadel SSO connections (deployed services auth via OIDC) ─────────────
  { id: 'e-zit-grafana', source: 'zitadel',   target: 'monitoring',  ...ssoAuth,       label: 'OIDC SSO' },
  { id: 'e-zit-dev',     source: 'zitadel',   target: 'devtron',     ...ssoAuth },
  { id: 'e-zit-n8n',     source: 'zitadel',   target: 'n8n',         ...ssoAuth },
  { id: 'e-zit-gws',     source: 'zitadel',   target: 'gws',         ...external,      label: 'Google IdP' },

  // ── PostgreSQL connections (deployed) ─────────────────────────────────────
  { id: 'e-zit-pg',      source: 'zitadel',   target: 'cnpg',        ...internal,      label: 'DB' },
  { id: 'e-dev-pg',      source: 'devtron',   target: 'cnpg',        ...internal },
  { id: 'e-n8n-pg',      source: 'n8n',       target: 'cnpg',        ...internal },
  { id: 'e-mon-pg',      source: 'monitoring', target: 'cnpg',       ...internal },

  // ── Valkey cache connections ──────────────────────────────────────────────
  { id: 'e-zit-val',     source: 'zitadel',   target: 'valkey',      ...internal,      label: 'session cache' },

  // ── Prometheus monitoring scrapes ─────────────────────────────────────────
  { id: 'e-prom-zit',    source: 'monitoring', target: 'zitadel',    ...scrape,        label: 'scrape' },
  { id: 'e-prom-dev',    source: 'monitoring', target: 'devtron',    ...scrape },
  { id: 'e-prom-traf',   source: 'monitoring', target: 'traefik',    ...scrape },
  { id: 'e-prom-n8n',    source: 'monitoring', target: 'n8n',        ...scrape },
  { id: 'e-prom-alert',  source: 'monitoring', target: 'alertmanager', ...internal },

  // ── Loki (planned — datasource configured) ────────────────────────────────
  { id: 'e-mon-loki',    source: 'monitoring', target: 'loki',       ...planned,       label: 'log datasource' },

  // ── Alertmanager → planned notification targets ────────────────────────────
  { id: 'e-alert-rc',    source: 'alertmanager', target: 'rocketchat', ...planned,     label: 'alerts (planned)' },
  { id: 'e-alert-n8n',   source: 'alertmanager', target: 'n8n',      ...planned },

  // ── Devtron CI/CD ─────────────────────────────────────────────────────────
  { id: 'e-dev-gh',      source: 'devtron',   target: 'github',      ...external,      label: 'GitOps' },
  { id: 'e-dev-harbor',  source: 'devtron',   target: 'harbor',      ...planned,       label: 'registry (planned)' },

  // ── MinIO dependencies ────────────────────────────────────────────────────
  { id: 'e-cnpg-minio',  source: 'cnpg',      target: 'minio',       ...planned,       label: 'WAL backup (planned)' },
  { id: 'e-velero-minio', source: 'velero',   target: 'minio',       ...planned,       label: 'backup target' },

  // ── External backups ──────────────────────────────────────────────────────
  { id: 'e-pg-b2',       source: 'cnpg',      target: 'b2',          ...external,      label: 'Barman WAL' },
  { id: 'e-minio-b2',    source: 'minio',     target: 'b2',          ...planned },
  { id: 'e-velero-b2',   source: 'velero',    target: 'b2',          ...planned },

  // ── Hetzner provider ──────────────────────────────────────────────────────
  { id: 'e-cp-hetz',     source: 'cp',        target: 'hetzner',     ...external },
  { id: 'e-forge-hetz',  source: 'forge-node', target: 'hetzner',    ...external },
  { id: 'e-vault-hetz',  source: 'vault-node', target: 'hetzner',    ...external },
]
