import { useAppStore, useHasWorkspace } from "../../stores/appStore";
import type { SidebarMode } from "../../stores/appStore";
import { FileTree } from "./FileTree";
import { PolicyList } from "./PolicyList";
import { Folder, SlidersHorizontal } from "lucide-react";

export function Sidebar() {
  const sidebarMode = useAppStore((s) => s.sidebarMode);
  const setSidebarMode = useAppStore((s) => s.setSidebarMode);
  const hasWorkspace = useHasWorkspace();

  return (
    <div className="flex h-full flex-col bg-sidebar">
      <ModeTabBar mode={sidebarMode} onChange={setSidebarMode} />

      {hasWorkspace ? (
        sidebarMode === "workspace" ? (
          <FileTree />
        ) : (
          <PolicyList />
        )
      ) : (
        <EmptyState />
      )}
    </div>
  );
}

function ModeTabBar({
  mode,
  onChange,
}: {
  mode: SidebarMode;
  onChange: (m: SidebarMode) => void;
}) {
  const modes: { id: SidebarMode; label: string; icon: typeof Folder }[] = [
    { id: "workspace", label: "Workspace", icon: Folder },
    { id: "policies", label: "Policies", icon: SlidersHorizontal },
  ];

  return (
    <div className="border-b border-separator">
      <div className="flex h-10 items-center justify-center gap-2 px-2">
        {modes.map((m) => {
          const Icon = m.icon;
          const isActive = mode === m.id;

          return (
            <button
              key={m.id}
              onClick={() => onChange(m.id)}
              title={m.label}
              className={`
                flex h-7.5 w-7.5 items-center justify-center rounded-md cursor-default transition-colors
                ${isActive ? "bg-hover text-accent" : "text-text-secondary hover:bg-hover/70 hover:text-text-primary"}
              `}
            >
              <Icon size={17} strokeWidth={1.75} />
            </button>
          );
        })}
      </div>
    </div>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-1 items-start p-3">
      <div>
        <p className="text-xs font-semibold text-text-secondary">
          No Workspace
        </p>
        <p className="mt-1.5 text-[11px] text-text-secondary/80">
          Use File &gt; Open Workspace…
        </p>
      </div>
    </div>
  );
}
