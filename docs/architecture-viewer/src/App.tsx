import { useCallback, useState } from 'react'
import {
  ReactFlow,
  Background,
  BackgroundVariant,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  addEdge,
  type Connection,
  type NodeMouseHandler,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'

import CustomNode, { type NodeData } from './CustomNode'
import { initialNodes } from './nodes'
import { initialEdges } from './edges'
import type { Node } from '@xyflow/react'

const nodeTypes = { custom: CustomNode }

const LAYER_LABELS: Record<string, string> = {
  edge:     'Layer 1 — Edge (Cloudflare)',
  cluster:  'Layer 2 — Kubernetes Cluster (K3s)',
  platform: 'Layer 3 — Platform Services',
  app:      'Layer 4 — Applications',
  external: 'Layer 5 — External Providers',
}

const LAYER_Y: Record<string, number> = {
  edge:     60,
  cluster:  240,
  platform: 420,
  app:      660,
  external: 900,
}

const LAYER_TEAL  = 'rgba(82,168,130,0.06)'
const LAYER_AMBER = 'rgba(196,151,90,0.05)'
const LAYER_DIM   = 'rgba(255,255,255,0.02)'

function layerBg(layer: string): string {
  if (layer === 'edge' || layer === 'platform') return LAYER_TEAL
  if (layer === 'cluster' || layer === 'app')   return LAYER_AMBER
  return LAYER_DIM
}

function LayerBackground({ layer }: { layer: string }) {
  const y    = LAYER_Y[layer] ?? 0
  const h    = layer === 'platform' ? 200 : 180
  return (
    <div
      aria-hidden="true"
      style={{
        position: 'absolute',
        left: 0, right: 0,
        top: y, height: h,
        background: layerBg(layer),
        borderTop: '1px solid rgba(255,255,255,0.04)',
        pointerEvents: 'none',
        zIndex: 0,
      }}
    >
      <span className="layer-label">{LAYER_LABELS[layer]}</span>
    </div>
  )
}

interface DetailPanelProps {
  node: Node<NodeData>
  onClose: () => void
}

function DetailPanel({ node, onClose }: DetailPanelProps) {
  const d = node.data
  const layerColors: Record<string, string> = {
    edge: '#52A882', cluster: '#C4975A', platform: '#52A882',
    app: '#C4975A', external: '#4a5568',
  }
  const color = layerColors[d.layer] ?? '#52A882'

  return (
    <aside className="detail-panel" aria-label={`Details for ${d.label}`}>
      <button
        className="detail-panel-close"
        onClick={onClose}
        aria-label="Close detail panel"
        data-testid="detail-panel-close"
      >
        ESC
      </button>

      <span className="detail-panel-layer" style={{ color }}>
        {LAYER_LABELS[d.layer] ?? d.layer}
      </span>

      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ fontSize: 28 }} role="img" aria-label="">
          {d.icon}
        </span>
        <h2 className="detail-panel-name">{d.label}</h2>
      </div>

      <p className="detail-panel-desc">{d.description}</p>

      {d.meta && Object.keys(d.meta).length > 0 && (
        <>
          <div className="detail-panel-divider" />
          <dl className="detail-panel-meta">
            {Object.entries(d.meta).map(([k, v]) => (
              <div key={k} className="detail-meta-row">
                <dt className="detail-meta-key">{k}</dt>
                <dd className="detail-meta-val">{v}</dd>
              </div>
            ))}
          </dl>
        </>
      )}
    </aside>
  )
}

export default function App() {
  const [nodes, , onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)
  const [selected, setSelected] = useState<Node<NodeData> | null>(null)

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge(params, eds)),
    [setEdges],
  )

  const onNodeClick: NodeMouseHandler<Node<NodeData>> = useCallback((_evt, node) => {
    setSelected((prev) => (prev?.id === node.id ? null : node))
  }, [])

  const onPaneClick = useCallback(() => setSelected(null), [])

  return (
    <div style={{ width: '100vw', height: '100vh', background: '#0D1117' }}>
      {/* Header */}
      <header className="arch-header" role="banner">
        <svg
          className="arch-header-logo"
          viewBox="0 0 28 28"
          fill="none"
          aria-label="Helix Stax logo"
          role="img"
        >
          <path d="M14 2 C8 2 4 7 4 14 S8 26 14 26 S24 21 24 14 S20 2 14 2 Z" fill="none" stroke="#52A882" strokeWidth="1.5"/>
          <path d="M8 10 Q14 6 20 10 Q14 14 8 18 Q14 22 20 18" stroke="#C4975A" strokeWidth="2" fill="none" strokeLinecap="round"/>
        </svg>
        <span className="arch-header-title">Helix Stax</span>
        <span style={{ color: '#30363d', fontSize: 14 }}>|</span>
        <span style={{ fontSize: 13, color: '#8b949e' }}>Infrastructure Architecture</span>
        <span className="arch-header-subtitle">K3s on Hetzner · Cloudflare Edge · Zitadel OIDC</span>
      </header>

      {/* Flow canvas — offset by header height */}
      <div
        style={{ position: 'absolute', top: 49, left: 0, right: selected ? 280 : 0, bottom: 0 }}
        role="main"
        aria-label="Architecture diagram"
      >
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodeClick={onNodeClick}
          onPaneClick={onPaneClick}
          nodeTypes={nodeTypes}
          fitView
          fitViewOptions={{ padding: 0.15 }}
          minZoom={0.25}
          maxZoom={2}
          attributionPosition="bottom-left"
          aria-label="Helix Stax infrastructure architecture diagram"
        >
          <Background
            variant={BackgroundVariant.Dots}
            gap={24}
            size={1}
            color="#1e2a38"
          />
          <Controls aria-label="Diagram controls" />
          <MiniMap
            nodeColor={(n) => {
              const layer = (n.data as NodeData)?.layer ?? 'edge'
              if (layer === 'edge' || layer === 'platform') return '#52A882'
              if (layer === 'cluster' || layer === 'app')   return '#C4975A'
              return '#4a5568'
            }}
            maskColor="rgba(13,17,23,0.7)"
            aria-label="Minimap"
          />

          {/* Layer background bands — rendered as SVG foreign objects via absolute divs */}
          {['edge', 'cluster', 'platform', 'app', 'external'].map((l) => (
            <LayerBackground key={l} layer={l} />
          ))}
        </ReactFlow>
      </div>

      {/* Detail panel */}
      {selected && (
        <DetailPanel
          node={selected as Node<NodeData>}
          onClose={() => setSelected(null)}
        />
      )}
    </div>
  )
}
