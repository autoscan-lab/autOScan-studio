import { useEffect, useMemo, useRef, useState } from "react";
import { Panel, PanelGroup, PanelResizeHandle } from "react-resizable-panels";
import { useAppStore } from "./stores/appStore";
import { Toolbar } from "./components/Toolbar";
import { Sidebar } from "./components/Sidebar/Sidebar";
import { EditorPane } from "./components/Editor/EditorPane";
import { OutputPane } from "./components/Output/OutputPane";
import { InspectorPane } from "./components/Inspector/InspectorPane";

const LEFT_SIDEBAR_DEFAULT_WIDTH = 306;
const LEFT_SIDEBAR_MIN_WIDTH = 220;
const LEFT_SIDEBAR_MAX_WIDTH = 460;
const RIGHT_SIDEBAR_DEFAULT_WIDTH = 360;
const RIGHT_SIDEBAR_MIN_WIDTH = 280;
const RIGHT_SIDEBAR_MAX_WIDTH = 520;
const CENTER_MIN_WIDTH = 420;

export default function App() {
  const isSidebarVisible = useAppStore((s) => s.isSidebarVisible);
  const isInspectorVisible = useAppStore((s) => s.isInspectorVisible);
  const isOutputVisible = useAppStore((s) => s.isOutputVisible);
  const restoreSession = useAppStore((s) => s.restoreSession);
  const toggleSidebar = useAppStore((s) => s.toggleSidebar);
  const toggleInspector = useAppStore((s) => s.toggleInspector);
  const toggleOutput = useAppStore((s) => s.toggleOutput);
  const openWorkspace = useAppStore((s) => s.openWorkspace);
  const savePolicy = useAppStore((s) => s.savePolicy);
  const handleEngineEvent = useAppStore((s) => s.handleEngineEvent);
  const appendOutput = useAppStore((s) => s.appendOutput);
  const setRunDone = useAppStore((s) => s.setRunDone);

  const appBodyRef = useRef<HTMLDivElement | null>(null);
  const [leftSidebarWidth, setLeftSidebarWidth] = useState(
    LEFT_SIDEBAR_DEFAULT_WIDTH,
  );
  const [rightSidebarWidth, setRightSidebarWidth] = useState(
    RIGHT_SIDEBAR_DEFAULT_WIDTH,
  );

  useEffect(() => {
    restoreSession();
  }, [restoreSession]);

  useEffect(() => {
    const unsubs = [
      window.api.onMenuEvent("menu:open-workspace", openWorkspace),
      window.api.onMenuEvent("menu:save-policy", savePolicy),
      window.api.onMenuEvent("menu:toggle-sidebar", toggleSidebar),
      window.api.onMenuEvent("menu:toggle-inspector", toggleInspector),
      window.api.onMenuEvent("menu:toggle-output", toggleOutput),
      window.api.onEngineEvent((event) => handleEngineEvent(event as any)),
      window.api.onEngineOutput((text) => appendOutput(text)),
      window.api.onEngineDone((code) => setRunDone(code)),
    ];
    return () => unsubs.forEach((fn) => fn());
  }, [
    openWorkspace,
    savePolicy,
    toggleSidebar,
    toggleInspector,
    toggleOutput,
    handleEngineEvent,
    appendOutput,
    setRunDone,
  ]);

  const visibleLeftWidth = isSidebarVisible ? leftSidebarWidth : 0;
  const visibleRightWidth = isInspectorVisible ? rightSidebarWidth : 0;

  const maxLeftWidth = useMemo(() => {
    const totalWidth = appBodyRef.current?.clientWidth ?? 0;
    const available = totalWidth - visibleRightWidth - CENTER_MIN_WIDTH;
    return Math.max(
      LEFT_SIDEBAR_MIN_WIDTH,
      Math.min(LEFT_SIDEBAR_MAX_WIDTH, available),
    );
  }, [visibleRightWidth]);

  const maxRightWidth = useMemo(() => {
    const totalWidth = appBodyRef.current?.clientWidth ?? 0;
    const available = totalWidth - visibleLeftWidth - CENTER_MIN_WIDTH;
    return Math.max(
      RIGHT_SIDEBAR_MIN_WIDTH,
      Math.min(RIGHT_SIDEBAR_MAX_WIDTH, available),
    );
  }, [visibleLeftWidth]);

  useEffect(() => {
    if (isSidebarVisible) {
      setLeftSidebarWidth((current) => Math.min(current, maxLeftWidth));
    }
  }, [isSidebarVisible, maxLeftWidth]);

  useEffect(() => {
    if (isInspectorVisible) {
      setRightSidebarWidth((current) => Math.min(current, maxRightWidth));
    }
  }, [isInspectorVisible, maxRightWidth]);

  const startHorizontalResize = (
    side: "left" | "right",
    event: React.MouseEvent<HTMLDivElement>,
  ) => {
    event.preventDefault();

    const startX = event.clientX;
    const startLeft = leftSidebarWidth;
    const startRight = rightSidebarWidth;

    const onMouseMove = (moveEvent: MouseEvent) => {
      const containerWidth = appBodyRef.current?.clientWidth ?? 0;

      if (side === "left") {
        const delta = moveEvent.clientX - startX;
        const next = startLeft + delta;
        const allowedMax = Math.max(
          LEFT_SIDEBAR_MIN_WIDTH,
          Math.min(
            LEFT_SIDEBAR_MAX_WIDTH,
            containerWidth - visibleRightWidth - CENTER_MIN_WIDTH,
          ),
        );
        setLeftSidebarWidth(
          Math.min(Math.max(next, LEFT_SIDEBAR_MIN_WIDTH), allowedMax),
        );
        return;
      }

      const delta = startX - moveEvent.clientX;
      const next = startRight + delta;
      const allowedMax = Math.max(
        RIGHT_SIDEBAR_MIN_WIDTH,
        Math.min(
          RIGHT_SIDEBAR_MAX_WIDTH,
          containerWidth - visibleLeftWidth - CENTER_MIN_WIDTH,
        ),
      );
      setRightSidebarWidth(
        Math.min(Math.max(next, RIGHT_SIDEBAR_MIN_WIDTH), allowedMax),
      );
    };

    const onMouseUp = () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };

    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);
  };

  return (
    <div className="flex flex-col h-screen">
      <Toolbar />

      <div ref={appBodyRef} className="flex flex-1 min-h-0 min-w-0">
        {isSidebarVisible && (
          <>
            <div
              className="min-h-0 shrink-0 bg-sidebar"
              style={{ width: `${Math.min(leftSidebarWidth, maxLeftWidth)}px` }}
            >
              <Sidebar />
            </div>
            <div
              onMouseDown={(event) => startHorizontalResize("left", event)}
              className="w-px shrink-0 bg-separator cursor-col-resize"
            />
          </>
        )}

        <div className="flex-1 min-w-0">
          <PanelGroup direction="vertical">
            <Panel minSize={20} id="editor" order={1}>
              <EditorPane />
            </Panel>

            {isOutputVisible && (
              <>
                <PanelResizeHandle className="h-px bg-separator" />
                <Panel
                  defaultSize={30}
                  minSize={10}
                  maxSize={50}
                  id="output"
                  order={2}
                >
                  <OutputPane />
                </Panel>
              </>
            )}
          </PanelGroup>
        </div>

        {isInspectorVisible && (
          <>
            <div
              onMouseDown={(event) => startHorizontalResize("right", event)}
              className="w-px shrink-0 bg-separator cursor-col-resize"
            />
            <div
              className="min-h-0 shrink-0 bg-pane"
              style={{
                width: `${Math.min(rightSidebarWidth, maxRightWidth)}px`,
              }}
            >
              <InspectorPane />
            </div>
          </>
        )}
      </div>
    </div>
  );
}
