import { useAppStore, useHasWorkspace } from '../../stores/appStore'
import type { SidebarMode } from '../../stores/appStore'
import { FileTree } from './FileTree'
import { PolicyList } from './PolicyList'

export function Sidebar() {
  const sidebarMode = useAppStore((s) => s.sidebarMode)
  const setSidebarMode = useAppStore((s) => s.setSidebarMode)
  const hasWorkspace = useHasWorkspace()

  return (
    <div className="flex flex-col h-full bg-sidebar">
      <ModeTabBar mode={sidebarMode} onChange={setSidebarMode} />

      {hasWorkspace ? (
        sidebarMode === 'workspace' ? (
          <FileTree />
        ) : (
          <PolicyList />
        )
      ) : (
        <EmptyState />
      )}
    </div>
  )
}

function ModeTabBar({ mode, onChange }: { mode: SidebarMode; onChange: (m: SidebarMode) => void }) {
  const modes: { id: SidebarMode; icon: string }[] = [
    { id: 'workspace', icon: 'folder' },
    { id: 'policies', icon: 'sliders' }
  ]

  return (
    <div className="border-y border-separator/70">
      <div className="flex items-center justify-center gap-2 h-10 px-1.5">
        {modes.map((m) => (
          <button
            key={m.id}
            onClick={() => onChange(m.id)}
            title={m.id.charAt(0).toUpperCase() + m.id.slice(1)}
            className={`
              flex items-center justify-center w-8 h-6 rounded cursor-default
              ${mode === m.id ? 'text-accent' : 'text-text-secondary hover:text-text-primary'}
            `}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              {m.icon === 'folder' && (
                <path
                  d="M2 4.5C2 3.67 2.67 3 3.5 3H6l1.5 1.5H12.5C13.33 4.5 14 5.17 14 6V11.5C14 12.33 13.33 13 12.5 13H3.5C2.67 13 2 12.33 2 11.5V4.5Z"
                  stroke="currentColor"
                  strokeWidth="1.2"
                  fill={mode === m.id ? 'currentColor' : 'none'}
                  fillOpacity={mode === m.id ? 0.15 : 0}
                />
              )}
              {m.icon === 'sliders' && (
                <>
                  <line x1="2" y1="5" x2="14" y2="5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
                  <line x1="2" y1="8" x2="14" y2="8" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
                  <line x1="2" y1="11" x2="14" y2="11" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
                  <circle cx="5" cy="5" r="1.5" fill="currentColor" />
                  <circle cx="10" cy="8" r="1.5" fill="currentColor" />
                  <circle cx="7" cy="11" r="1.5" fill="currentColor" />
                </>
              )}
            </svg>
          </button>
        ))}
      </div>
    </div>
  )
}

function EmptyState() {
  return (
    <div className="flex-1 flex items-start p-3">
      <div>
        <p className="text-xs font-semibold text-text-secondary">No Workspace</p>
        <p className="text-[11px] text-text-secondary/80 mt-1.5">
          Use File &gt; Open Workspace…
        </p>
      </div>
    </div>
  )
}
