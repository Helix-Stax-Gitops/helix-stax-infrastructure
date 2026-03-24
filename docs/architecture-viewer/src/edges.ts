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

export const initialEdges: Edge[] = [
  // Internet → Cloudflare edge
  { id: 'e-inet-waf',    source: 'cf-waf',   target: 'cf-zt',      ...traffic,       label: 'Internet traffic' },
  { id: 'e-waf-zt',      source: 'cf-zt',    target: 'cf-tunnel',  ...traffic },

  // Cloudflare → Cluster
  { id: 'e-tunnel-traf', source: 'cf-tunnel', target: 'traefik',   ...trafficDashed, label: 'cloudflared' },

  // Traefik → Apps
  { id: 'e-traf-n8n',    source: 'traefik',  target: 'n8n',        ...traffic },
  { id: 'e-traf-rc',     source: 'traefik',  target: 'rocketchat', ...traffic },
  { id: 'e-traf-mon',    source: 'traefik',  target: 'monitoring', ...traffic },
  { id: 'e-traf-back',   source: 'traefik',  target: 'backstage',  ...traffic },
  { id: 'e-traf-out',    source: 'traefik',  target: 'outline',    ...traffic },
  { id: 'e-traf-oll',    source: 'traefik',  target: 'ollama',     ...traffic },

  // Cluster topology
  { id: 'e-cp-worker',   source: 'cp',       target: 'worker',     ...internal,      label: 'K3s cluster' },

  // Apps → Platform services
  { id: 'e-n8n-pg',      source: 'n8n',      target: 'cnpg',       ...internal },
  { id: 'e-rc-pg',       source: 'rocketchat', target: 'cnpg',     ...internal },
  { id: 'e-rc-val',      source: 'rocketchat', target: 'valkey',   ...internal },
  { id: 'e-out-pg',      source: 'outline',  target: 'cnpg',       ...internal },
  { id: 'e-out-minio',   source: 'outline',  target: 'minio',      ...internal },
  { id: 'e-mon-pg',      source: 'monitoring', target: 'cnpg',     ...internal },
  { id: 'e-back-pg',     source: 'backstage', target: 'cnpg',      ...internal },
  { id: 'e-apps-zit',    source: 'traefik',  target: 'zitadel',    ...internal,      label: 'ForwardAuth' },

  // Devtron pulls from GitHub
  { id: 'e-dev-gh',      source: 'devtron',  target: 'github',     ...external },
  { id: 'e-dev-reg',     source: 'devtron',  target: 'minio',      ...internal,      label: 'registry cache' },

  // Secrets
  { id: 'e-bao-apps',    source: 'openbao',  target: 'n8n',        ...internal,      label: 'ESO sync' },

  // External backups
  { id: 'e-pg-b2',       source: 'cnpg',     target: 'b2',         ...external,      label: 'Barman WAL' },
  { id: 'e-minio-b2',    source: 'minio',    target: 'b2',         ...external },

  // Provider
  { id: 'e-cp-hetz',     source: 'cp',       target: 'hetzner',    ...external },
  { id: 'e-worker-hetz', source: 'worker',   target: 'hetzner',    ...external },
]
