import {
  useAppStore,
  useOpenFileTabs,
  useSelectedPolicyDisplayName,
} from "../../stores/appStore";
import { MdClose, MdDescription } from "react-icons/md";

import { CodeViewer } from "./CodeViewer";
import { PolicyEditor } from "./PolicyEditor";

export function EditorPane() {
  const sidebarMode = useAppStore((s) => s.sidebarMode);
  const hasWorkspace = useAppStore((s) => s.workspaceRootPath !== null);

  const isShowingPolicyEditor = sidebarMode === "policies" && hasWorkspace;

  return (
    <div className="flex flex-col h-full bg-editor">
      {isShowingPolicyEditor ? <PolicyHeader /> : <EditorHeader />}
      <div className="flex-1 min-h-0">
        {isShowingPolicyEditor ? <PolicyEditor /> : <CodeViewer />}
      </div>
    </div>
  );
}

function EditorHeader() {
  const tabs = useOpenFileTabs();
  const selectedID = useAppStore((s) => s.selectedFileNodeID);
  const selectFile = useAppStore((s) => s.selectFile);
  const closeTab = useAppStore((s) => s.closeTab);

  return (
    <div className="border-b border-separator bg-editor">
      <div className="flex h-10 items-stretch overflow-x-auto">
        {tabs.length === 0 ? (
          <span className="flex items-center px-4 text-[12px] text-text-primary">
            No file open
          </span>
        ) : (
          <div className="flex h-full items-stretch border-l border-separator">
            {tabs.map((tab) => {
              const isActive = tab.id === selectedID;

              return (
                <button
                  key={tab.id}
                  onClick={() => selectFile(tab.id)}
                  className={`
                    flex h-full min-w-0 items-center gap-2 border-r border-separator px-3.5 cursor-default text-[12px] font-medium
                    ${
                      isActive
                        ? "bg-hover text-text-primary"
                        : "bg-editor text-text-primary hover:bg-hover/40"
                    }
                  `}
                >
                  <span className="max-w-40 truncate">{tab.title}</span>
                  <span
                    onClick={(e) => {
                      e.stopPropagation();
                      closeTab(tab.id);
                    }}
                    className="ml-1 shrink-0 text-text-secondary hover:text-text-primary"
                  >
                    <MdClose size={13} />
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

function PolicyHeader() {
  const policyName = useSelectedPolicyDisplayName();
  const isPolicyDirty = useAppStore((s) => s.isPolicyDirty);

  return (
    <div className="border-b border-separator bg-editor">
      <div className="flex h-10 items-center gap-2 px-4">
        <MdDescription size={16} className="shrink-0 text-text-secondary" />
        {policyName ? (
          <>
            <span className="truncate text-[12px] font-semibold text-text-primary">
              {policyName}
            </span>
            {isPolicyDirty && (
              <span className="text-[10px] font-medium text-orange-400">
                Unsaved changes
              </span>
            )}
          </>
        ) : (
          <span className="text-[12px] font-semibold text-text-primary">
            Policies
          </span>
        )}
      </div>
    </div>
  );
}
