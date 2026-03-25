import { useAppStore, useOpenFileTabs, useSelectedPolicyDisplayName } from '../../stores/appStore'
import { CodeViewer } from './CodeViewer'
import { PolicyEditor } from './PolicyEditor'

export function EditorPane() {
  const sidebarMode = useAppStore((s) => s.sidebarMode)
  const hasWorkspace = useAppStore((s) => s.workspaceRootPath !== null)

  const isShowingPolicyEditor = sidebarMode === 'policies' && hasWorkspace

  return (
    <div className="flex flex-col h-full bg-editor">
      {isShowingPolicyEditor ? <PolicyHeader /> : <EditorHeader />}
      <div className="flex-1 min-h-0">
        {isShowingPolicyEditor ? <PolicyEditor /> : <CodeViewer />}
      </div>
    </div>
  )
}

function EditorHeader() {
  const tabs = useOpenFileTabs()
  const selectedID = useAppStore((s) => s.selectedFileNodeID)
  const selectFile = useAppStore((s) => s.selectFile)
  const closeTab = useAppStore((s) => s.closeTab)

  return (
    <div className="border-y border-separator/70 bg-editor">
      <div className="flex items-center h-10 px-3 overflow-x-auto">
        {tabs.length === 0 ? (
          <span className="text-[12px] text-text-secondary/85">No file open</span>
        ) : (
          <div className="flex items-center gap-1.5">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => selectFile(tab.id)}
                className={`
                  flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[12px] font-medium cursor-default
                  ${tab.id === selectedID
                    ? 'bg-hover text-text-primary'
                    : 'text-text-secondary hover:text-text-primary'}
                `}
              >
                <span className="truncate max-w-[120px]">{tab.title}</span>
                <span
                  onClick={(e) => {
                    e.stopPropagation()
                    closeTab(tab.id)
                  }}
                  className="text-[10px] text-text-secondary hover:text-text-primary ml-0.5"
                >
                  ✕
                </span>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function PolicyHeader() {
  const policyName = useSelectedPolicyDisplayName()
  const isPolicyDirty = useAppStore((s) => s.isPolicyDirty)

  return (
    <div className="border-y border-separator/70 bg-editor">
      <div className="flex items-center h-10 px-3 gap-2">
        <span className="text-[13px] text-text-secondary">📋</span>
        {policyName ? (
          <>
            <span className="text-[12px] font-semibold text-text-primary truncate">
              {policyName}
            </span>
            {isPolicyDirty && (
              <span className="text-[10px] font-medium text-orange-400">Unsaved changes</span>
            )}
          </>
        ) : (
          <span className="text-[12px] font-semibold text-text-primary">Policies</span>
        )}
      </div>
    </div>
  )
}
