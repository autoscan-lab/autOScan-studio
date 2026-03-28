import {
  useActiveMainPaneTab,
  useAppStore,
  useSelectedPolicyDisplayName,
} from "../../stores/appStore";
import { MdClose, MdDescription } from "react-icons/md";

import { CodeViewer } from "./CodeViewer";
import { PolicyEditor } from "./PolicyEditor";
import { AnalysisPane } from "./AnalysisPane";

export function EditorPane() {
  const sidebarMode = useAppStore((state) => state.sidebarMode);
  const hasWorkspace = useAppStore((state) => state.workspaceRootPath !== null);
  const policiesCount = useAppStore((state) => state.policies.length);
  const activeMainPaneTab = useActiveMainPaneTab();

  const isShowingAnalysis =
    activeMainPaneTab !== null && activeMainPaneTab.kind !== "file";
  const isShowingPolicyEditor =
    sidebarMode === "policies" && hasWorkspace && !isShowingAnalysis;

  if (isShowingPolicyEditor) {
    return (
      <div className="flex flex-col h-full bg-editor">
        <PolicyHeader />
        <div className="flex-1 min-h-0">
          {policiesCount > 0 ? <PolicyEditor /> : <NoPoliciesEditorState />}
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full bg-editor">
      <MainPaneHeader />
      <div className="flex-1 min-h-0">
        {!activeMainPaneTab ? (
          <NoTabOpen />
        ) : activeMainPaneTab.kind === "file" ? (
          <CodeViewer />
        ) : (
          <AnalysisPane tab={activeMainPaneTab} />
        )}
      </div>
    </div>
  );
}

function MainPaneHeader() {
  const tabs = useAppStore((state) => state.mainPaneTabs);
  const activeTabID = useAppStore((state) => state.activeMainPaneTabID);
  const setActiveMainPaneTab = useAppStore((state) => state.setActiveMainPaneTab);
  const closeMainPaneTab = useAppStore((state) => state.closeMainPaneTab);

  return (
    <div className="border-b border-separator bg-editor">
      <div className="flex h-10 items-stretch overflow-x-auto">
        {tabs.length === 0 ? (
          <span className="flex items-center px-4 text-[12px] text-text-primary">
            No view open
          </span>
        ) : (
          <div className="flex h-full items-stretch">
            {tabs.map((tab) => {
              const isActive = tab.id === activeTabID;
              const typeLabel =
                tab.kind === "file"
                  ? "FILE"
                  : tab.kind === "diff"
                    ? "DIFF"
                    : tab.kind === "similarity"
                      ? "SIM"
                      : "AI";

              return (
                <button
                  key={tab.id}
                  onClick={() => void setActiveMainPaneTab(tab.id)}
                  className={`
                    flex h-full min-w-0 items-center gap-2 border-r border-separator px-3.5 cursor-default text-[12px] font-medium
                    ${
                      isActive
                        ? "bg-hover text-text-primary"
                        : "bg-editor text-text-primary hover:bg-hover/40"
                    }
                  `}
                >
                  <span className="text-[9px] text-text-secondary font-semibold tracking-wide shrink-0">
                    {typeLabel}
                  </span>
                  <span className="max-w-44 truncate">{tab.title}</span>
                  <span
                    onClick={(event) => {
                      event.stopPropagation();
                      void closeMainPaneTab(tab.id);
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

function NoTabOpen() {
  return (
    <div className="flex items-center justify-center h-full">
      <p className="text-sm text-text-secondary/70">
        Open a file or analysis view to begin.
      </p>
    </div>
  );
}

function NoPoliciesEditorState() {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="text-center">
        <p className="text-[13px] font-medium text-text-primary">No policies yet</p>
        <p className="mt-1 text-[12px] text-text-secondary/80">
          Create one from the Policies sidebar to start editing.
        </p>
      </div>
    </div>
  );
}

function PolicyHeader() {
  const policyName = useSelectedPolicyDisplayName();
  const isPolicyDirty = useAppStore((state) => state.isPolicyDirty);

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
