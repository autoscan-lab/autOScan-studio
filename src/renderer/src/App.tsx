import { useEffect } from 'react'
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels'
import { useAppStore } from './stores/appStore'
import { Toolbar } from './components/Toolbar'
import { Sidebar } from './components/Sidebar/Sidebar'
import { EditorPane } from './components/Editor/EditorPane'
import { OutputPane } from './components/Output/OutputPane'
import { InspectorPane } from './components/Inspector/InspectorPane'

export default function App() {
  const isSidebarVisible = useAppStore((s) => s.isSidebarVisible)
  const isInspectorVisible = useAppStore((s) => s.isInspectorVisible)
  const isOutputVisible = useAppStore((s) => s.isOutputVisible)
  const restoreSession = useAppStore((s) => s.restoreSession)
  const toggleSidebar = useAppStore((s) => s.toggleSidebar)
  const toggleInspector = useAppStore((s) => s.toggleInspector)
  const toggleOutput = useAppStore((s) => s.toggleOutput)
  const openWorkspace = useAppStore((s) => s.openWorkspace)
  const savePolicy = useAppStore((s) => s.savePolicy)
  const handleEngineEvent = useAppStore((s) => s.handleEngineEvent)
  const appendOutput = useAppStore((s) => s.appendOutput)
  const setRunDone = useAppStore((s) => s.setRunDone)

  useEffect(() => {
    restoreSession()
  }, [restoreSession])

  // Wire up menu events and engine events
  useEffect(() => {
    const unsubs = [
      window.api.onMenuEvent('menu:open-workspace', openWorkspace),
      window.api.onMenuEvent('menu:save-policy', savePolicy),
      window.api.onMenuEvent('menu:toggle-sidebar', toggleSidebar),
      window.api.onMenuEvent('menu:toggle-inspector', toggleInspector),
      window.api.onMenuEvent('menu:toggle-output', toggleOutput),
      window.api.onEngineEvent((event) => handleEngineEvent(event as any)),
      window.api.onEngineOutput((text) => appendOutput(text)),
      window.api.onEngineDone((code) => setRunDone(code))
    ]
    return () => unsubs.forEach((fn) => fn())
  }, [openWorkspace, savePolicy, toggleSidebar, toggleInspector, toggleOutput, handleEngineEvent, appendOutput, setRunDone])

  return (
    <div className="flex flex-col h-screen">
      <Toolbar />

      <PanelGroup direction="horizontal" className="flex-1 min-h-0">
        {isSidebarVisible && (
          <>
            <Panel defaultSize={20} minSize={15} maxSize={35} id="sidebar" order={1}>
              <Sidebar />
            </Panel>
            <PanelResizeHandle className="w-px bg-separator" />
          </>
        )}

        <Panel minSize={30} id="center" order={2}>
          <PanelGroup direction="vertical">
            <Panel minSize={20} id="editor" order={1}>
              <EditorPane />
            </Panel>

            {isOutputVisible && (
              <>
                <PanelResizeHandle className="h-px bg-separator" />
                <Panel defaultSize={30} minSize={10} maxSize={50} id="output" order={2}>
                  <OutputPane />
                </Panel>
              </>
            )}
          </PanelGroup>
        </Panel>

        {isInspectorVisible && (
          <>
            <PanelResizeHandle className="w-px bg-separator" />
            <Panel defaultSize={28} minSize={20} maxSize={45} id="inspector" order={3}>
              <InspectorPane />
            </Panel>
          </>
        )}
      </PanelGroup>
    </div>
  )
}
