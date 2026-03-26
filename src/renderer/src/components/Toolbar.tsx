import { useAppStore, useHasWorkspace } from "../stores/appStore";
import { PanelBottom, PanelRight } from "lucide-react";

export function Toolbar() {
  const toolbarTitle = useAppStore((s) => s.toolbarTitle);
  const isInspectorVisible = useAppStore((s) => s.isInspectorVisible);
  const isOutputVisible = useAppStore((s) => s.isOutputVisible);
  const toggleInspector = useAppStore((s) => s.toggleInspector);
  const toggleOutput = useAppStore((s) => s.toggleOutput);
  const openWorkspace = useAppStore((s) => s.openWorkspace);
  const hasWorkspace = useHasWorkspace();

  return (
    <div className="titlebar-drag flex items-center h-11 bg-pane border-b border-separator shrink-0">
      <div className="w-[76px] shrink-0" />

      <div className="flex-1 min-w-0 pl-0.5">
        <button
          onClick={() => void openWorkspace()}
          title="Change Workspace"
          className="titlebar-no-drag flex h-7 items-center rounded-md px-2 text-left text-[12px] font-medium text-text-primary transition-colors hover:bg-hover cursor-default max-w-fit"
        >
          <span className="truncate">{toolbarTitle}</span>
        </button>
      </div>

      <div className="titlebar-no-drag flex items-center gap-1 pr-3 pl-2">
        <ToolbarToggle
          icon="output"
          active={isOutputVisible}
          onClick={toggleOutput}
          title="Toggle Output (⌘3)"
        />
        <ToolbarToggle
          icon="inspector"
          active={isInspectorVisible}
          onClick={toggleInspector}
          title="Toggle Inspector (⌘2)"
          disabled={!hasWorkspace}
        />
      </div>
    </div>
  );
}

function ToolbarToggle({
  icon,
  active,
  onClick,
  title,
  disabled,
}: {
  icon: string;
  active: boolean;
  onClick: () => void;
  title: string;
  disabled?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={`
        flex items-center justify-center w-8 h-8 rounded transition-colors duration-100
        ${active ? "text-accent" : "text-text-secondary"}
        ${disabled ? "opacity-30 cursor-default" : "hover:bg-hover cursor-default"}
      `}
    >
      {icon === "output" && <PanelBottom size={18} strokeWidth={1.5} />}
      {icon === "inspector" && <PanelRight size={18} strokeWidth={1.5} />}
    </button>
  );
}
