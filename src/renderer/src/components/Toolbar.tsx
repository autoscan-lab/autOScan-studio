import { useAppStore, useHasWorkspace } from '../stores/appStore'

export function Toolbar() {
  const toolbarTitle = useAppStore((s) => s.toolbarTitle)
  const isSidebarVisible = useAppStore((s) => s.isSidebarVisible)
  const isInspectorVisible = useAppStore((s) => s.isInspectorVisible)
  const isOutputVisible = useAppStore((s) => s.isOutputVisible)
  const toggleSidebar = useAppStore((s) => s.toggleSidebar)
  const toggleInspector = useAppStore((s) => s.toggleInspector)
  const toggleOutput = useAppStore((s) => s.toggleOutput)
  const hasWorkspace = useHasWorkspace()

  return (
    <div className="titlebar-drag flex items-center h-10 px-3 bg-pane border-b border-separator shrink-0">
      {/* macOS traffic light spacer */}
      <div className="w-[70px] shrink-0" />

      <div className="titlebar-no-drag flex items-center gap-1.5 mr-3">
        <ToolbarToggle
          icon="sidebar.left"
          active={isSidebarVisible}
          onClick={toggleSidebar}
          title="Toggle Sidebar (⌘1)"
        />
        <ToolbarToggle
          icon="terminal"
          active={isOutputVisible}
          onClick={toggleOutput}
          title="Toggle Output (⌘3)"
        />
      </div>

      <div className="flex-1 text-center text-xs font-medium text-text-secondary truncate">
        {toolbarTitle}
      </div>

      <div className="titlebar-no-drag flex items-center gap-1.5 ml-3">
        <ToolbarToggle
          icon="sidebar.right"
          active={isInspectorVisible}
          onClick={toggleInspector}
          title="Toggle Inspector (⌘2)"
          disabled={!hasWorkspace}
        />
      </div>
    </div>
  )
}

function ToolbarToggle({
  icon,
  active,
  onClick,
  title,
  disabled
}: {
  icon: string
  active: boolean
  onClick: () => void
  title: string
  disabled?: boolean
}) {
  const iconMap: Record<string, string> = {
    'sidebar.left': '⊞',
    'sidebar.right': '⊞',
    terminal: '⌨'
  }

  return (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`
        flex items-center justify-center w-7 h-6 rounded text-xs
        transition-colors duration-100
        ${active ? 'text-accent' : 'text-text-secondary'}
        ${disabled ? 'opacity-30 cursor-default' : 'hover:bg-hover cursor-default'}
      `}
    >
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
        {icon === 'sidebar.left' && (
          <>
            <rect x="1" y="2" width="14" height="12" rx="2" stroke="currentColor" strokeWidth="1.2" />
            <line x1="5.5" y1="2" x2="5.5" y2="14" stroke="currentColor" strokeWidth="1.2" />
          </>
        )}
        {icon === 'sidebar.right' && (
          <>
            <rect x="1" y="2" width="14" height="12" rx="2" stroke="currentColor" strokeWidth="1.2" />
            <line x1="10.5" y1="2" x2="10.5" y2="14" stroke="currentColor" strokeWidth="1.2" />
          </>
        )}
        {icon === 'terminal' && (
          <>
            <rect x="1" y="2" width="14" height="12" rx="2" stroke="currentColor" strokeWidth="1.2" />
            <polyline points="4,7 6.5,9.5 4,12" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
            <line x1="8" y1="12" x2="12" y2="12" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
          </>
        )}
      </svg>
    </button>
  )
}
