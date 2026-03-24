import { memo } from 'react'
import { Handle, Position } from '@xyflow/react'

export interface NodeData {
  label: string
  description: string
  layer: string
  accentColor: string
  icon: string
  meta?: Record<string, string>
}

interface CustomNodeProps {
  data: NodeData
  selected: boolean
}

const layerColors: Record<string, string> = {
  edge:     '#52A882',
  cluster:  '#C4975A',
  platform: '#52A882',
  app:      '#C4975A',
  external: '#4a5568',
}

function CustomNode({ data, selected }: CustomNodeProps) {
  const accent = layerColors[data.layer] ?? '#52A882'

  return (
    <div
      style={{
        background: '#1a2332',
        border: `1px solid ${selected ? accent : '#30363d'}`,
        borderLeft: `3px solid ${accent}`,
        borderRadius: 8,
        padding: '10px 14px',
        minWidth: 160,
        maxWidth: 200,
        cursor: 'pointer',
        boxShadow: selected
          ? `0 0 0 2px ${accent}33, 0 4px 20px rgba(0,0,0,0.4)`
          : '0 2px 8px rgba(0,0,0,0.3)',
        transition: 'box-shadow 0.15s, border-color 0.15s',
        position: 'relative',
      }}
      data-testid={`node-${data.label.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`}
    >
      <Handle
        type="target"
        position={Position.Top}
        style={{ background: accent, width: 8, height: 8, border: '2px solid #0D1117' }}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
        <span style={{ fontSize: 16, lineHeight: 1 }} role="img" aria-hidden="true">
          {data.icon}
        </span>
        <span
          style={{
            fontSize: 12,
            fontWeight: 700,
            color: accent,
            letterSpacing: '0.01em',
            lineHeight: 1.2,
          }}
        >
          {data.label}
        </span>
      </div>

      <p
        style={{
          fontSize: 10,
          color: '#8b949e',
          lineHeight: 1.4,
          margin: 0,
        }}
      >
        {data.description}
      </p>

      <Handle
        type="source"
        position={Position.Bottom}
        style={{ background: accent, width: 8, height: 8, border: '2px solid #0D1117' }}
      />
    </div>
  )
}

export default memo(CustomNode)
