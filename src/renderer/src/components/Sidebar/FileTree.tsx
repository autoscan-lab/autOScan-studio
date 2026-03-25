import { useCallback } from 'react'
import { useAppStore } from '../../stores/appStore'
import type { WorkspaceNode } from '../../types/workspace'

export function FileTree() {
  const nodes = useAppStore((s) => s.workspaceNodes)
  const expandedIDs = useAppStore((s) => s.expandedDirectoryIDs)
  const selectedID = useAppStore((s) => s.selectedFileNodeID)
  const selectFile = useAppStore((s) => s.selectFile)
  const toggleDirectory = useAppStore((s) => s.toggleDirectory)

  return (
    <div className="flex-1 overflow-y-auto py-1">
      {nodes.map((node) => (
        <TreeNode
          key={node.id}
          node={node}
          depth={0}
          expandedIDs={expandedIDs}
          selectedID={selectedID}
          onSelect={selectFile}
          onToggle={toggleDirectory}
        />
      ))}
    </div>
  )
}

function TreeNode({
  node,
  depth,
  expandedIDs,
  selectedID,
  onSelect,
  onToggle
}: {
  node: WorkspaceNode
  depth: number
  expandedIDs: Set<string>
  selectedID: string | null
  onSelect: (id: string) => Promise<void>
  onToggle: (id: string) => void
}) {
  const isExpanded = expandedIDs.has(node.id)
  const isSelected = selectedID === node.id

  const handleClick = useCallback(() => {
    if (node.isDirectory) {
      onToggle(node.id)
    } else {
      onSelect(node.id)
    }
  }, [node.id, node.isDirectory, onToggle, onSelect])

  const ext = node.name.split('.').pop()?.toLowerCase() ?? ''

  return (
    <>
      <div
        onClick={handleClick}
        className={`
          flex items-center h-[26px] px-2 cursor-default text-[12px]
          ${isSelected ? 'bg-selection text-text-primary' : 'text-text-secondary hover:bg-hover hover:text-text-primary'}
        `}
        style={{ paddingLeft: `${depth * 16 + 8}px` }}
      >
        {node.isDirectory ? (
          <span className="w-4 text-center text-[10px] mr-1.5 shrink-0 text-text-secondary">
            {isExpanded ? '▾' : '▸'}
          </span>
        ) : (
          <span className="w-4 mr-1.5 shrink-0" />
        )}

        <FileIcon isDirectory={node.isDirectory} ext={ext} />

        <span className="truncate">{node.name}</span>
      </div>

      {node.isDirectory && isExpanded && (
        <>
          {node.children.map((child) => (
            <TreeNode
              key={child.id}
              node={child}
              depth={depth + 1}
              expandedIDs={expandedIDs}
              selectedID={selectedID}
              onSelect={onSelect}
              onToggle={onToggle}
            />
          ))}
        </>
      )}
    </>
  )
}

function FileIcon({ isDirectory, ext }: { isDirectory: boolean; ext: string }) {
  const colorMap: Record<string, string> = {
    c: 'text-blue-400',
    h: 'text-purple-400',
    cpp: 'text-blue-500',
    yaml: 'text-green-400',
    yml: 'text-green-400',
    md: 'text-gray-400',
    txt: 'text-gray-400'
  }

  const color = isDirectory ? 'text-accent' : (colorMap[ext] ?? 'text-text-secondary')

  return (
    <span className={`mr-1.5 text-[13px] shrink-0 ${color}`}>
      {isDirectory ? '📁' : '📄'}
    </span>
  )
}
