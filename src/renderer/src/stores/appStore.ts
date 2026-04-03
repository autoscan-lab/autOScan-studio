import { create } from "zustand";
import type { WorkspaceNode, WorkspaceSnapshot } from "../types/workspace";
import type { PolicyFile, PolicyDraft, TestCase } from "../types/policy";
import type {
  BannedHit,
  BridgeCapabilities,
  EngineRunReport,
  EngineRunEvent,
  SubmissionResult,
} from "../types/engine";
import { createTestCase, createStarterPolicy } from "../types/policy";
import { parsePolicy, serializePolicy } from "../lib/policyYaml";

export type SidebarMode = "workspace" | "policies";
export type EditorDocumentKind = "source" | "notice";
export type BannerKind = "success" | "error" | "info";
export type MainPaneTabKind = "file" | "diff" | "similarity" | "ai";
export type InspectorViewMode = "table" | "detail";
export type InspectorDetailTab =
  | "overview"
  | "banned"
  | "tests";

export interface PolicyBanner {
  id: string;
  kind: BannerKind;
  message: string;
}

export interface DiffLine {
  type: "same" | "added" | "removed";
  content: string;
  line?: number;
}

export interface DiffTabPayload {
  submissionID: string;
  testCaseID: string;
  state: "unavailable" | "ready";
  expectedOutput: string | null;
  actualOutput: string | null;
  stdout: string | null;
  stderr: string | null;
  diffLines: DiffLine[] | null;
  message?: string;
}

export interface SimilarityTabPayload {
  leftSubmissionID: string | null;
  rightSubmissionID: string | null;
  context: string;
}

export interface AITabPayload {
  submissionID: string | null;
  context: string;
}

export interface FileMainPaneTab {
  id: string;
  kind: "file";
  title: string;
  fileNodeID: string;
  filePath: string;
}

export interface DiffMainPaneTab {
  id: string;
  kind: "diff";
  title: string;
  payload: DiffTabPayload;
}

export interface SimilarityMainPaneTab {
  id: string;
  kind: "similarity";
  title: string;
  payload: SimilarityTabPayload;
}

export interface AIMainPaneTab {
  id: string;
  kind: "ai";
  title: string;
  payload: AITabPayload;
}

export type MainPaneTab =
  | FileMainPaneTab
  | DiffMainPaneTab
  | SimilarityMainPaneTab
  | AIMainPaneTab;

export type AnalysisTabInput =
  | {
      kind: "diff";
      id?: string;
      title: string;
      payload: DiffTabPayload;
    }
  | {
      kind: "similarity";
      id?: string;
      title: string;
      payload: SimilarityTabPayload;
    }
  | {
      kind: "ai";
      id?: string;
      title: string;
      payload: AITabPayload;
    };

export interface EngineCapabilities {
  testCaseRun: boolean;
}

export type SubmissionTestCaseStatus =
  | "idle"
  | "running"
  | "pass"
  | "fail"
  | "timeout"
  | "compile_failed"
  | "error";

export interface SubmissionTestCaseResult {
  submissionID: string;
  testCaseID: string;
  testCaseIndex: number;
  testCaseName: string;
  status: SubmissionTestCaseStatus;
  exitCode: number | null;
  durationMs: number | null;
  stdout: string | null;
  stderr: string | null;
  outputMatch: "none" | "pass" | "fail" | "missing" | null;
  expectedOutput: string | null;
  actualOutput: string | null;
  diffLines: DiffLine[] | null;
  message: string | null;
}

interface ActiveTestRunContext {
  mode: "single";
  submissionID: string;
  singleTestCaseID: string | null;
  testCaseIDsByIndex: string[];
}

interface ExportSummaryRow {
  submission_id: string;
  compiled: boolean;
  banned_hit_count: number;
  c_files: string[];
}

interface AppState {
  // Sidebar
  sidebarMode: SidebarMode;
  isSidebarVisible: boolean;
  isInspectorVisible: boolean;
  isOutputVisible: boolean;

  // Workspace
  workspaceRootPath: string | null;
  workspaceNodes: WorkspaceNode[];
  urlByNodeID: Record<string, string>;
  expandedDirectoryIDs: Set<string>;
  selectedFileNodeID: string | null;
  toolbarTitle: string;

  // Main pane tabs
  mainPaneTabs: MainPaneTab[];
  activeMainPaneTabID: string | null;

  // Editor
  editorText: string;
  editorDocumentKind: EditorDocumentKind;
  editorFilePath: string | null;

  // Policies
  policies: PolicyFile[];
  selectedPolicyID: string | null;
  activePolicyID: string | null;
  activePolicyTestCases: TestCase[];
  selectedPolicyDraft: PolicyDraft | null;
  loadedPolicyText: string;
  selectedPolicyTestCaseID: string | null;
  policyBanner: PolicyBanner | null;
  isPolicyDirty: boolean;

  // Run
  runOutputText: string;
  isRunInProgress: boolean;
  runStatusMessage: string;
  latestRunReport: EngineRunReport | null;
  latestRunError: string | null;

  // Inspector detail
  inspectorViewMode: InspectorViewMode;
  selectedSubmissionID: string | null;
  inspectorDetailTab: InspectorDetailTab;

  // Capability flags
  engineCapabilities: EngineCapabilities;
  testCaseResultsBySubmission: Record<
    string,
    Record<string, SubmissionTestCaseResult>
  >;
  activeTestRunContext: ActiveTestRunContext | null;

  // Actions
  loadEngineCapabilities: () => Promise<void>;
  setSidebarMode: (mode: SidebarMode) => void;
  toggleSidebar: () => void;
  toggleInspector: () => void;
  toggleOutput: () => void;
  openWorkspace: () => Promise<void>;
  closeWorkspace: () => Promise<void>;
  loadWorkspace: (
    rootPath: string,
    restoredExpanded?: string[],
    restoredSelected?: string | null,
  ) => Promise<void>;
  selectFile: (nodeID: string | null) => Promise<void>;
  openOrFocusFileTab: (nodeID: string) => void;
  openOrFocusAnalysisTab: (tab: AnalysisTabInput) => void;
  setActiveMainPaneTab: (tabID: string | null) => Promise<void>;
  closeMainPaneTab: (tabID: string) => Promise<void>;
  toggleDirectory: (nodeID: string) => void;
  refreshPolicies: () => Promise<void>;
  selectPolicyForEditing: (policyID: string) => Promise<void>;
  updatePolicyDraft: (draft: PolicyDraft) => void;
  addTestCase: () => void;
  removeTestCase: (id: string) => void;
  updateTestCase: (id: string, updates: Partial<TestCase>) => void;
  savePolicy: () => Promise<void>;
  createPolicy: (name: string) => Promise<void>;
  renamePolicy: (policyID: string, nextName: string) => Promise<void>;
  deletePolicy: (policyID: string) => Promise<void>;
  setActivePolicy: (policyID: string | null) => Promise<void>;
  runWorkspaceSession: () => Promise<void>;
  runSubmissionTestCase: (
    submissionID: string,
    testCaseID: string,
  ) => Promise<void>;
  exportLatestReportSummary: () => Promise<void>;
  cancelRun: () => Promise<void>;
  clearOutput: () => void;
  handleEngineEvent: (event: EngineRunEvent) => void;
  appendOutput: (text: string) => void;
  setRunDone: (code: number) => void;
  setPolicyBanner: (kind: BannerKind, message: string) => void;
  clearPolicyBanner: () => void;
  openSubmissionDetail: (submissionID: string) => void;
  closeSubmissionDetail: () => void;
  setInspectorDetailTab: (tab: InspectorDetailTab) => void;
  restoreSession: () => Promise<void>;
  persist: () => void;
}

function collectDirectoryIDs(nodes: WorkspaceNode[]): Set<string> {
  const ids = new Set<string>();
  function walk(node: WorkspaceNode): void {
    if (node.isDirectory) {
      ids.add(node.id);
      node.children.forEach(walk);
    }
  }
  nodes.forEach(walk);
  return ids;
}

function displayName(value: string): string {
  const normalized = value.replace(/\\/g, "/");
  const segments = normalized.split("/");
  return segments[segments.length - 1] || value;
}

function createAnalysisTabID(tab: AnalysisTabInput): string {
  if (tab.id) return tab.id;

  if (tab.kind === "diff") {
    return `diff:${tab.payload.submissionID}:${tab.payload.testCaseID}`;
  }

  if (tab.kind === "similarity") {
    const left = tab.payload.leftSubmissionID ?? "none";
    const right = tab.payload.rightSubmissionID ?? "none";
    return `similarity:${left}:${right}`;
  }

  return `ai:${tab.payload.submissionID ?? "none"}`;
}

function getSelectedSubmission(
  report: EngineRunReport | null,
  submissionID: string | null,
): SubmissionResult | null {
  if (!report || !submissionID) return null;
  return report.submissions.find((submission) => submission.id === submissionID) ?? null;
}

function mapCapabilities(value: BridgeCapabilities): EngineCapabilities {
  return {
    testCaseRun: Boolean(value.run_test_case),
  };
}

function mapBridgeBannedHit(hit: {
  function: string;
  file: string;
  line?: number;
  column?: number;
  snippet?: string;
}): BannedHit {
  return {
    functionName: hit.function,
    filePath: hit.file,
    line: hit.line ?? null,
    column: hit.column ?? null,
    snippet: hit.snippet ?? "",
  };
}

function mapExportSummaryRows(report: EngineRunReport): ExportSummaryRow[] {
  return report.submissions.map((submission) => ({
    submission_id: submission.id,
    compiled: submission.compileStatus === "pass",
    banned_hit_count: submission.bannedHitCount,
    c_files: submission.cFiles,
  }));
}

function csvEscape(value: string): string {
  if (/[",\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function serializeExportSummaryCsv(rows: ExportSummaryRow[]): string {
  const header = "submission_id,compiled,banned_hit_count,c_files";
  const body = rows.map((row) => {
    const cFiles = row.c_files.join(";");
    return [
      csvEscape(row.submission_id),
      row.compiled ? "true" : "false",
      String(row.banned_hit_count),
      csvEscape(cFiles),
    ].join(",");
  });
  return [header, ...body].join("\n");
}

function buildExportBaseName(): string {
  return "grading-summary";
}

function resolveTestCaseIDByIndex(
  context: ActiveTestRunContext | null,
  index: number,
  activePolicyTestCases: TestCase[],
): string | null {
  if (index < 0) return null;

  const fromContext = context?.testCaseIDsByIndex[index] ?? null;
  if (fromContext) return fromContext;

  return activePolicyTestCases[index]?.id ?? null;
}

export const useAppStore = create<AppState>((set, get) => {
  const loadEditorFromFile = async (
    fileNodeID: string,
    filePath: string,
  ): Promise<void> => {
    set({ selectedFileNodeID: fileNodeID });

    try {
      const content = await window.api.readFile(filePath);
      set({
        editorText: content,
        editorDocumentKind: "source",
        editorFilePath: filePath,
      });
    } catch {
      set({
        editorText: "Unable to read file.",
        editorDocumentKind: "notice",
        editorFilePath: null,
      });
    }

    get().persist();
  };

  return {
    // Initial state
    sidebarMode: "workspace",
    isSidebarVisible: true,
    isInspectorVisible: false,
    isOutputVisible: false,
    workspaceRootPath: null,
    workspaceNodes: [],
    urlByNodeID: {},
    expandedDirectoryIDs: new Set(),
    selectedFileNodeID: null,
    toolbarTitle: "autOScan Studio",
    mainPaneTabs: [],
    activeMainPaneTabID: null,
    editorText: "Select a file to preview.",
    editorDocumentKind: "notice",
    editorFilePath: null,
    policies: [],
    selectedPolicyID: null,
    activePolicyID: null,
    activePolicyTestCases: [],
    selectedPolicyDraft: null,
    loadedPolicyText: "",
    selectedPolicyTestCaseID: null,
    policyBanner: null,
    isPolicyDirty: false,
    runOutputText: "",
    isRunInProgress: false,
    runStatusMessage: "Ready to run",
    latestRunReport: null,
    latestRunError: null,
    inspectorViewMode: "table",
    selectedSubmissionID: null,
    inspectorDetailTab: "overview",
    engineCapabilities: {
      testCaseRun: false,
    },
    testCaseResultsBySubmission: {},
    activeTestRunContext: null,

    // Actions
    loadEngineCapabilities: async () => {
      try {
        const capabilities = (await window.api.getEngineCapabilities()) as BridgeCapabilities;
        set({ engineCapabilities: mapCapabilities(capabilities) });
      } catch {
        set({
          engineCapabilities: {
            testCaseRun: false,
          },
        });
      }
    },

    setSidebarMode: (mode) => {
      set({ sidebarMode: mode });
      get().persist();
    },

    toggleSidebar: () => {
      set((state) => ({ isSidebarVisible: !state.isSidebarVisible }));
      get().persist();
    },

    toggleInspector: () => {
      set((state) => ({ isInspectorVisible: !state.isInspectorVisible }));
      get().persist();
    },

    toggleOutput: () => {
      set((state) => ({ isOutputVisible: !state.isOutputVisible }));
      get().persist();
    },

    openWorkspace: async () => {
      const path = await window.api.openDirectory();
      if (path) {
        await get().loadWorkspace(path);
      }
    },

    closeWorkspace: async () => {
      if (get().isRunInProgress) {
        await window.api.cancelRun();
      }

      set({
        workspaceRootPath: null,
        workspaceNodes: [],
        urlByNodeID: {},
        expandedDirectoryIDs: new Set(),
        selectedFileNodeID: null,
        toolbarTitle: "autOScan Studio",
        mainPaneTabs: [],
        activeMainPaneTabID: null,
        editorText: "Select a file to preview.",
        editorDocumentKind: "notice",
        editorFilePath: null,
        policies: [],
        selectedPolicyID: null,
        activePolicyID: null,
        activePolicyTestCases: [],
        selectedPolicyDraft: null,
        loadedPolicyText: "",
        selectedPolicyTestCaseID: null,
        policyBanner: null,
        isPolicyDirty: false,
        runOutputText: "",
        isRunInProgress: false,
        runStatusMessage: "Ready to run",
        latestRunReport: null,
        latestRunError: null,
        inspectorViewMode: "table",
        selectedSubmissionID: null,
        inspectorDetailTab: "overview",
        testCaseResultsBySubmission: {},
        activeTestRunContext: null,
      });

      window.api.storeSet("workspacePath", null);
      get().persist();
    },

    loadWorkspace: async (rootPath, restoredExpanded, restoredSelected) => {
      const snapshot: WorkspaceSnapshot = await window.api.loadWorkspace(rootPath);
      const directoryIDs = collectDirectoryIDs(snapshot.nodes);
      const restored = restoredExpanded
        ? new Set(restoredExpanded.filter((id) => directoryIDs.has(id)))
        : new Set<string>();
      restored.add(snapshot.rootNodeID);

      set({
        workspaceRootPath: rootPath,
        workspaceNodes: snapshot.nodes,
        urlByNodeID: snapshot.urlByNodeID,
        toolbarTitle: displayName(rootPath),
        expandedDirectoryIDs: restored,
        mainPaneTabs: [],
        activeMainPaneTabID: null,
        editorText: "Select a file to preview.",
        editorDocumentKind: "notice",
        editorFilePath: null,
        selectedFileNodeID: null,
        inspectorViewMode: "table",
        selectedSubmissionID: null,
        inspectorDetailTab: "overview",
        policies: [],
        selectedPolicyID: null,
        activePolicyID: null,
        activePolicyTestCases: [],
        selectedPolicyDraft: null,
        loadedPolicyText: "",
        selectedPolicyTestCaseID: null,
        policyBanner: null,
        isPolicyDirty: false,
        testCaseResultsBySubmission: {},
        activeTestRunContext: null,
      });

      await get().refreshPolicies();

      if (restoredSelected) {
        await get().selectFile(restoredSelected);
      }

      const storedActivePolicyID = (await window.api.storeGet(
        "activePolicyID",
      )) as string | null;
      const policies = get().policies;

      if (
        storedActivePolicyID &&
        policies.some((policy) => policy.id === storedActivePolicyID)
      ) {
        set({ activePolicyID: storedActivePolicyID });
      } else if (policies.length > 0) {
        set({ activePolicyID: policies[0].id });
      }

      const selectedPolicyID = get().selectedPolicyID;
      if (selectedPolicyID) {
        await get().selectPolicyForEditing(selectedPolicyID);
      } else {
        const active = get().activePolicyID ?? policies[0]?.id;
        if (active) await get().selectPolicyForEditing(active);
      }

      await get().setActivePolicy(get().activePolicyID);
      await get().loadEngineCapabilities();

      window.api.storeSet("workspacePath", rootPath);
      get().persist();
    },

    selectFile: async (nodeID) => {
      if (!nodeID) {
        set({
          selectedFileNodeID: null,
          editorText: "Select a file to preview.",
          editorDocumentKind: "notice",
          editorFilePath: null,
        });
        get().persist();
        return;
      }

      const { urlByNodeID } = get();
      const filePath = urlByNodeID[nodeID];
      if (!filePath) return;

      get().openOrFocusFileTab(nodeID);
      await get().setActiveMainPaneTab(`file:${nodeID}`);
    },

    openOrFocusFileTab: (nodeID) => {
      const state = get();
      const filePath = state.urlByNodeID[nodeID];
      if (!filePath) return;

      const tabID = `file:${nodeID}`;
      const title = displayName(filePath);

      set((current) => {
        const existingIndex = current.mainPaneTabs.findIndex((tab) => tab.id === tabID);

        if (existingIndex >= 0) {
          const nextTabs = [...current.mainPaneTabs];
          nextTabs[existingIndex] = {
            id: tabID,
            kind: "file",
            title,
            fileNodeID: nodeID,
            filePath,
          };

          return {
            mainPaneTabs: nextTabs,
            activeMainPaneTabID: tabID,
          };
        }

        return {
          mainPaneTabs: [
            ...current.mainPaneTabs,
            {
              id: tabID,
              kind: "file",
              title,
              fileNodeID: nodeID,
              filePath,
            } as FileMainPaneTab,
          ],
          activeMainPaneTabID: tabID,
        };
      });
    },

    openOrFocusAnalysisTab: (tab) => {
      const tabID = createAnalysisTabID(tab);

      const nextTab: MainPaneTab =
        tab.kind === "diff"
          ? {
              id: tabID,
              kind: "diff",
              title: tab.title,
              payload: tab.payload,
            }
          : tab.kind === "similarity"
            ? {
                id: tabID,
                kind: "similarity",
                title: tab.title,
                payload: tab.payload,
              }
            : {
                id: tabID,
                kind: "ai",
                title: tab.title,
                payload: tab.payload,
              };

      set((current) => {
        const existingIndex = current.mainPaneTabs.findIndex((paneTab) => paneTab.id === tabID);
        let nextTabs = current.mainPaneTabs;

        if (existingIndex >= 0) {
          nextTabs = [...current.mainPaneTabs];
          nextTabs[existingIndex] = nextTab;
        } else {
          nextTabs = [...current.mainPaneTabs, nextTab];
        }

        return {
          mainPaneTabs: nextTabs,
          activeMainPaneTabID: tabID,
          sidebarMode: "workspace",
        };
      });
    },

    setActiveMainPaneTab: async (tabID) => {
      set({ activeMainPaneTabID: tabID });
      if (!tabID) return;

      const tab = get().mainPaneTabs.find((paneTab) => paneTab.id === tabID);
      if (!tab) return;

      if (tab.kind === "file") {
        await loadEditorFromFile(tab.fileNodeID, tab.filePath);
      }
    },

    closeMainPaneTab: async (tabID) => {
      const current = get();
      const index = current.mainPaneTabs.findIndex((tab) => tab.id === tabID);
      if (index < 0) return;

      const nextTabs = current.mainPaneTabs.filter((tab) => tab.id !== tabID);
      let nextActiveTabID = current.activeMainPaneTabID;

      if (current.activeMainPaneTabID === tabID) {
        const prevTab = current.mainPaneTabs[index - 1];
        const nextTab = current.mainPaneTabs[index + 1];
        nextActiveTabID = prevTab?.id ?? nextTab?.id ?? null;
      }

      set({
        mainPaneTabs: nextTabs,
        activeMainPaneTabID: nextActiveTabID,
      });

      if (nextActiveTabID) {
        await get().setActiveMainPaneTab(nextActiveTabID);
      } else {
        set({
          editorText: "Select a file to preview.",
          editorDocumentKind: "notice",
          editorFilePath: null,
          selectedFileNodeID: null,
        });
        get().persist();
      }
    },

    toggleDirectory: (nodeID) => {
      set((state) => {
        const next = new Set(state.expandedDirectoryIDs);
        if (next.has(nodeID)) next.delete(nodeID);
        else next.add(nodeID);
        return { expandedDirectoryIDs: next };
      });
      get().persist();
    },

    refreshPolicies: async () => {
      const rootPath = get().workspaceRootPath;
      if (!rootPath) return;
      const policies: PolicyFile[] = await window.api.listPolicies(rootPath);
      set((state) => {
        const hasSelectedPolicy =
          state.selectedPolicyID !== null &&
          policies.some((policy) => policy.id === state.selectedPolicyID);
        const hasActivePolicy =
          state.activePolicyID !== null &&
          policies.some((policy) => policy.id === state.activePolicyID);

        return {
          policies,
          selectedPolicyID: hasSelectedPolicy ? state.selectedPolicyID : null,
          selectedPolicyDraft: hasSelectedPolicy ? state.selectedPolicyDraft : null,
          loadedPolicyText: hasSelectedPolicy ? state.loadedPolicyText : "",
          isPolicyDirty: hasSelectedPolicy ? state.isPolicyDirty : false,
          selectedPolicyTestCaseID: hasSelectedPolicy
            ? state.selectedPolicyTestCaseID
            : null,
          activePolicyID: hasActivePolicy ? state.activePolicyID : null,
          activePolicyTestCases: hasActivePolicy ? state.activePolicyTestCases : [],
        };
      });
    },

    selectPolicyForEditing: async (policyID) => {
      const policy = get().policies.find((item) => item.id === policyID);
      if (!policy) return;

      set({ selectedPolicyID: policyID });

      try {
        const text = await window.api.readPolicy(policy.path);
        const draft = parsePolicy(text);

        set((state) => ({
          selectedPolicyDraft: draft,
          loadedPolicyText: text,
          isPolicyDirty: false,
          selectedPolicyTestCaseID: draft.testCases[0]?.id ?? null,
          activePolicyTestCases:
            state.activePolicyID === policyID ? draft.testCases : state.activePolicyTestCases,
        }));
      } catch {
        set({
          selectedPolicyDraft: null,
          loadedPolicyText: "",
          isPolicyDirty: false,
        });
      }
    },

    updatePolicyDraft: (draft) => {
      const current = get().loadedPolicyText;
      const newText = serializePolicy(draft);
      set((state) => ({
        selectedPolicyDraft: draft,
        isPolicyDirty: newText !== current,
        activePolicyTestCases:
          state.activePolicyID === state.selectedPolicyID
            ? draft.testCases
            : state.activePolicyTestCases,
      }));
    },

    addTestCase: () => {
      const draft = get().selectedPolicyDraft;
      if (!draft) return;
      const testCase = createTestCase({ name: `Test ${draft.testCases.length + 1}` });
      const updated = { ...draft, testCases: [...draft.testCases, testCase] };
      get().updatePolicyDraft(updated);
      set({ selectedPolicyTestCaseID: testCase.id });
    },

    removeTestCase: (id) => {
      const draft = get().selectedPolicyDraft;
      if (!draft) return;
      const updated = {
        ...draft,
        testCases: draft.testCases.filter((testCase) => testCase.id !== id),
      };
      get().updatePolicyDraft(updated);
      if (get().selectedPolicyTestCaseID === id) {
        set({ selectedPolicyTestCaseID: updated.testCases[0]?.id ?? null });
      }
    },

    updateTestCase: (id, updates) => {
      const draft = get().selectedPolicyDraft;
      if (!draft) return;
      const updated = {
        ...draft,
        testCases: draft.testCases.map((testCase) =>
          testCase.id === id ? { ...testCase, ...updates } : testCase,
        ),
      };
      get().updatePolicyDraft(updated);
    },

    savePolicy: async () => {
      const { selectedPolicyID, selectedPolicyDraft, policies } = get();
      if (!selectedPolicyID || !selectedPolicyDraft) return;

      const policy = policies.find((item) => item.id === selectedPolicyID);
      if (!policy) return;

      const yaml = serializePolicy(selectedPolicyDraft);
      try {
        await window.api.savePolicy(policy.path, yaml);
        set((state) => ({
          loadedPolicyText: yaml,
          isPolicyDirty: false,
          activePolicyTestCases:
            state.activePolicyID === selectedPolicyID
              ? selectedPolicyDraft.testCases
              : state.activePolicyTestCases,
        }));
        get().setPolicyBanner("success", "Policy saved.");
      } catch (err) {
        get().setPolicyBanner("error", `Save failed: ${err}`);
      }
    },

    createPolicy: async (name) => {
      const rootPath = get().workspaceRootPath;
      if (!rootPath) return;

      const draft = createStarterPolicy(name);
      const yaml = serializePolicy(draft);
      const fileName = name.toLowerCase().replace(/\s+/g, "-") + ".yaml";

      try {
        const fullPath = await window.api.createPolicy(rootPath, fileName, yaml);
        await get().refreshPolicies();
        await get().setActivePolicy(fullPath);
        await get().selectPolicyForEditing(fullPath);
        get().setPolicyBanner("success", `Created policy "${name}".`);
      } catch (err) {
        get().setPolicyBanner("error", `Create failed: ${err}`);
      }
    },

    renamePolicy: async (policyID, nextName) => {
      const policies = get().policies;
      const policy = policies.find((item) => item.id === policyID);
      const trimmedName = nextName.trim();

      if (!policy || !trimmedName) return;

      try {
        const currentText = await window.api.readPolicy(policy.path);
        const draft = parsePolicy(currentText);
        const updatedDraft = { ...draft, name: trimmedName };
        const yaml = serializePolicy(updatedDraft);
        const fileName = trimmedName.toLowerCase().replace(/\s+/g, "-") + ".yaml";

        const fullPath = await window.api.renamePolicy(policy.path, fileName, yaml);

        await get().refreshPolicies();

        const nextPolicies = get().policies;
        const renamed = nextPolicies.find((item) => item.id === fullPath) ?? nextPolicies[0];

        if (!renamed) {
          set({
            selectedPolicyID: null,
            activePolicyID: null,
            selectedPolicyDraft: null,
            loadedPolicyText: "",
            isPolicyDirty: false,
            activePolicyTestCases: [],
          });
          get().setPolicyBanner("success", `Renamed policy to "${trimmedName}".`);
          get().persist();
          return;
        }

        set((state) => ({
          selectedPolicyID:
            state.selectedPolicyID === policyID ? renamed.id : state.selectedPolicyID,
          activePolicyID: state.activePolicyID === policyID ? renamed.id : state.activePolicyID,
        }));

        await get().selectPolicyForEditing(renamed.id);
        await get().setActivePolicy(get().activePolicyID);

        get().setPolicyBanner("success", `Renamed policy to "${trimmedName}".`);
        get().persist();
      } catch (err) {
        get().setPolicyBanner("error", `Rename failed: ${err}`);
      }
    },

    deletePolicy: async (policyID) => {
      try {
        await window.api.deletePolicy(policyID);
        await get().refreshPolicies();
        const policies = get().policies;

        if (get().selectedPolicyID === policyID) {
          if (policies.length > 0) {
            await get().selectPolicyForEditing(policies[0].id);
          } else {
            set({ selectedPolicyID: null, selectedPolicyDraft: null });
          }
        }

        if (get().activePolicyID === policyID) {
          await get().setActivePolicy(policies[0]?.id ?? null);
        }

        get().setPolicyBanner("info", "Policy deleted.");
      } catch (err) {
        get().setPolicyBanner("error", `Delete failed: ${err}`);
      }
    },

    setActivePolicy: async (policyID) => {
      set({ activePolicyID: policyID });

      if (!policyID) {
        set({ activePolicyTestCases: [] });
        get().persist();
        return;
      }

      const state = get();
      if (state.selectedPolicyID === policyID && state.selectedPolicyDraft) {
        set({ activePolicyTestCases: state.selectedPolicyDraft.testCases });
        get().persist();
        return;
      }

      const policy = state.policies.find((item) => item.id === policyID);
      if (!policy) {
        set({ activePolicyTestCases: [] });
        get().persist();
        return;
      }

      try {
        const text = await window.api.readPolicy(policy.path);
        const draft = parsePolicy(text);
        set({ activePolicyTestCases: draft.testCases });
      } catch {
        set({ activePolicyTestCases: [] });
      }

      get().persist();
    },

    runWorkspaceSession: async () => {
      const { workspaceRootPath, activePolicyID, policies } = get();
      if (!workspaceRootPath || !activePolicyID) return;

      const policy = policies.find((item) => item.id === activePolicyID);
      if (!policy) return;

      set({
        isRunInProgress: true,
        runOutputText: "",
        runStatusMessage: "Starting…",
        latestRunReport: null,
        latestRunError: null,
        isOutputVisible: true,
        inspectorViewMode: "table",
        selectedSubmissionID: null,
        inspectorDetailTab: "overview",
        activeTestRunContext: null,
        testCaseResultsBySubmission: {},
      });

      await window.api.runSession(workspaceRootPath, policy.path);
    },

    runSubmissionTestCase: async (submissionID, testCaseID) => {
      const state = get();
      const { workspaceRootPath, activePolicyID, policies, activePolicyTestCases } = state;
      if (!workspaceRootPath || !activePolicyID) return;

      const policy = policies.find((item) => item.id === activePolicyID);
      if (!policy) return;

      const testCaseIndex = activePolicyTestCases.findIndex(
        (testCase) => testCase.id === testCaseID,
      );
      if (testCaseIndex < 0) {
        set((current) => ({
          runOutputText:
            current.runOutputText +
            `[Engine] Unknown test case ${testCaseID} for active policy.\n`,
        }));
        return;
      }

      const testCase = activePolicyTestCases[testCaseIndex];
      const testCaseName = testCase.name || "Untitled test";

      set((current) => ({
        isRunInProgress: true,
        latestRunError: null,
        runStatusMessage: `Running ${testCaseName}…`,
        runOutputText: `Running test "${testCaseName}" for ${submissionID}\n`,
        isOutputVisible: true,
        activeTestRunContext: {
          mode: "single",
          submissionID,
          singleTestCaseID: testCaseID,
          testCaseIDsByIndex: activePolicyTestCases.map((tc) => tc.id),
        },
        testCaseResultsBySubmission: {
          ...current.testCaseResultsBySubmission,
          [submissionID]: {
            ...(current.testCaseResultsBySubmission[submissionID] ?? {}),
            [testCaseID]: {
              submissionID,
              testCaseID,
              testCaseIndex,
              testCaseName,
              status: "running",
              exitCode: null,
              durationMs: null,
              stdout: null,
              stderr: null,
              outputMatch: null,
              expectedOutput: null,
              actualOutput: null,
              diffLines: null,
              message: null,
            },
          },
        },
      }));

      await window.api.runTestCase(
        workspaceRootPath,
        policy.path,
        submissionID,
        testCaseIndex,
      );
    },

    exportLatestReportSummary: async () => {
      const { latestRunReport, workspaceRootPath } = get();
      if (!latestRunReport) {
        set((state) => ({
          isOutputVisible: true,
          runStatusMessage: "Nothing to export",
          runOutputText:
            state.runOutputText + "[Export] No run report available.\n",
        }));
        return;
      }

      try {
        const rows = mapExportSummaryRows(latestRunReport);
        const baseName = buildExportBaseName();
        const defaultPath = workspaceRootPath
          ? `${workspaceRootPath}/${baseName}.csv`
          : `${baseName}.csv`;

        const selectedPath = await window.api.saveFile(
          "Export Grading Summary",
          defaultPath,
          [
            { name: "CSV", extensions: ["csv"] },
            { name: "JSON", extensions: ["json"] },
          ],
        );
        if (!selectedPath) return;

        const normalizedPath = selectedPath.toLowerCase();
        const targetPath =
          normalizedPath.endsWith(".csv") || normalizedPath.endsWith(".json")
            ? selectedPath
            : `${selectedPath}.csv`;

        const isJsonExport = targetPath.toLowerCase().endsWith(".json");
        const content = isJsonExport
          ? JSON.stringify(rows, null, 2)
          : serializeExportSummaryCsv(rows);

        await window.api.writeTextFile(targetPath, content);
        set((state) => ({
          isOutputVisible: true,
          runStatusMessage: "Summary exported",
          runOutputText:
            state.runOutputText +
            `[Export] Saved ${rows.length} rows to ${targetPath}\n`,
        }));
      } catch (err) {
        const message =
          err instanceof Error && err.message ? err.message : String(err);
        set((state) => ({
          isOutputVisible: true,
          runStatusMessage: "Export failed",
          runOutputText:
            state.runOutputText + `[Export] Failed to export summary: ${message}\n`,
        }));
      }
    },

    cancelRun: async () => {
      await window.api.cancelRun();
      set({
        isRunInProgress: false,
        runStatusMessage: "Cancelled",
        activeTestRunContext: null,
      });
    },

    clearOutput: () => {
      set({ runOutputText: "" });
    },

    handleEngineEvent: (event) => {
      switch (event.type) {
        case "started":
          set({
            runStatusMessage: event.message || "Starting run…",
          });
          break;

        case "version":
          break;

        case "discovery_complete": {
          if (get().activeTestRunContext) {
            set({
              runStatusMessage: "Preparing test execution…",
            });
            break;
          }

          const discoveredCount = event.discovery?.submission_count;
          set((state) => ({
            runOutputText:
              state.runOutputText +
              `Discovered ${discoveredCount ?? "?"} submissions\n`,
            runStatusMessage:
              discoveredCount !== undefined
                ? `Discovered ${discoveredCount} submissions`
                : state.runStatusMessage,
          }));
          break;
        }

        case "compile_complete": {
          const compileStatus = event.compile?.timed_out
            ? "timeout"
            : event.compile?.ok
              ? "pass"
              : "fail";
          const submissionID = event.compile?.submission_id ?? "unknown";

          set((state) => ({
            runOutputText:
              state.runOutputText + `Compiled ${submissionID} (${compileStatus})\n`,
          }));
          break;
        }

        case "scan_complete": {
          const submissionID = event.scan?.submission_id ?? "unknown";
          const bannedHits = event.scan?.banned_hits ?? 0;

          set((state) => ({
            runOutputText:
              state.runOutputText +
              `Scanned ${submissionID} (${bannedHits} banned hits)\n`,
          }));
          break;
        }

        case "run_complete": {
          const report: EngineRunReport = {
            summary: {
              policyName: event.run.summary.policy_name,
              root: event.run.summary.root,
              startedAt: event.run.summary.started_at,
              finishedAt: event.run.summary.finished_at,
              durationMs: event.run.summary.duration_ms,
              totalSubmissions: event.run.summary.total_submissions,
              compilePass: event.run.summary.compile_pass,
              compileFail: event.run.summary.compile_fail,
              compileTimeout: event.run.summary.compile_timeout,
              cleanSubmissions: event.run.summary.clean_submissions,
              submissionsWithBanned: event.run.summary.submissions_with_banned,
              bannedHits: event.run.summary.banned_hits_total,
              topBannedFunctions: event.run.summary.top_banned_functions,
            },
            submissions: event.run.submissions.map((submission) => {
              const compileStatus: "pass" | "fail" | "timeout" =
                submission.compile_timeout
                  ? "timeout"
                  : submission.compile_ok
                    ? "pass"
                    : "fail";
              const bannedHits = (submission.banned_hits ?? []).map(
                mapBridgeBannedHit,
              );

              return {
                id: submission.id,
                submissionPath: submission.path,
                status: submission.status,
                cFiles: submission.c_files,
                compileOk: submission.compile_ok,
                compileStatus,
                compileTimeout: submission.compile_timeout,
                bannedHitCount: submission.banned_count,
                exitCode: submission.exit_code,
                compileTimeMs: submission.compile_time_ms,
                stderr: submission.stderr ?? "",
                bannedHits,
              };
            }),
          };

          const selectedSubmission = getSelectedSubmission(
            report,
            get().selectedSubmissionID,
          );

          set({
            latestRunReport: report,
            runStatusMessage: `Done — ${report.summary.totalSubmissions} submissions graded`,
            isInspectorVisible: true,
            inspectorViewMode:
              get().inspectorViewMode === "detail" && selectedSubmission
                ? "detail"
                : "table",
            selectedSubmissionID: selectedSubmission?.id ?? null,
            inspectorDetailTab: selectedSubmission
              ? get().inspectorDetailTab
              : "overview",
          });
          break;
        }

        case "test_case_started": {
          const payload = event.test_case_started;
          const context = get().activeTestRunContext;
          const testCaseID =
            resolveTestCaseIDByIndex(
              context,
              payload.test_case_index,
              get().activePolicyTestCases,
            ) ?? `index:${payload.test_case_index}`;

          set((state) => ({
            runStatusMessage: `Running ${payload.test_case_name || "test"}…`,
            testCaseResultsBySubmission: {
              ...state.testCaseResultsBySubmission,
              [payload.submission_id]: {
                ...(state.testCaseResultsBySubmission[payload.submission_id] ?? {}),
                [testCaseID]: {
                  submissionID: payload.submission_id,
                  testCaseID,
                  testCaseIndex: payload.test_case_index,
                  testCaseName: payload.test_case_name || "Untitled test",
                  status: "running",
                  exitCode: null,
                  durationMs: null,
                  stdout: null,
                  stderr: null,
                  outputMatch: null,
                  expectedOutput: null,
                  actualOutput: null,
                  diffLines: null,
                  message: null,
                },
              },
            },
          }));
          break;
        }

        case "test_case_complete": {
          const payload = event.test_case;
          const context = get().activeTestRunContext;
          const testCaseID =
            resolveTestCaseIDByIndex(
              context,
              payload.test_case_index,
              get().activePolicyTestCases,
            ) ?? `index:${payload.test_case_index}`;

          const mappedStatus: SubmissionTestCaseStatus =
            payload.status === "running" ||
            payload.status === "pass" ||
            payload.status === "fail" ||
            payload.status === "timeout" ||
            payload.status === "compile_failed" ||
            payload.status === "error"
              ? payload.status
              : "error";

          const diffLines =
            payload.diff_lines?.map((line) => ({
              type: line.type,
              content: line.content,
              line: line.line_num,
            })) ?? null;

          const outputMatch =
            payload.output_match === "none" ||
            payload.output_match === "pass" ||
            payload.output_match === "fail" ||
            payload.output_match === "missing"
              ? payload.output_match
              : null;

          set((state) => ({
            runStatusMessage: `${payload.test_case_name || "Test"} ${mappedStatus}`,
            testCaseResultsBySubmission: {
              ...state.testCaseResultsBySubmission,
              [payload.submission_id]: {
                ...(state.testCaseResultsBySubmission[payload.submission_id] ?? {}),
                [testCaseID]: {
                  submissionID: payload.submission_id,
                  testCaseID,
                  testCaseIndex: payload.test_case_index,
                  testCaseName: payload.test_case_name || "Untitled test",
                  status: mappedStatus,
                  exitCode: payload.exit_code,
                  durationMs: payload.duration_ms,
                  stdout: payload.stdout ?? null,
                  stderr: payload.stderr ?? null,
                  outputMatch,
                  expectedOutput: payload.expected_output ?? null,
                  actualOutput: payload.actual_output ?? null,
                  diffLines,
                  message: payload.message ?? null,
                },
              },
            },
          }));

          const shouldAutoOpenDiff =
            context?.mode === "single" &&
            context.submissionID === payload.submission_id &&
            context.singleTestCaseID === testCaseID;

          if (shouldAutoOpenDiff) {
            const latestRunReport = get().latestRunReport;
            const submissionLabel = displayName(
              latestRunReport?.submissions.find(
                (submission) => submission.id === payload.submission_id,
              )?.submissionPath ?? payload.submission_id,
            );
            const testCaseLabel =
              get().activePolicyTestCases.find((testCase) => testCase.id === testCaseID)
                ?.name ||
              payload.test_case_name ||
              "Untitled test";
            const hasDiffPayload =
              payload.expected_output !== undefined ||
              payload.actual_output !== undefined ||
              (payload.diff_lines?.length ?? 0) > 0 ||
              payload.output_match === "pass" ||
              payload.output_match === "fail";

            get().openOrFocusAnalysisTab({
              kind: "diff",
              title: `Diff · ${submissionLabel} · ${testCaseLabel}`,
              payload: {
                submissionID: payload.submission_id,
                testCaseID,
                state: hasDiffPayload ? "ready" : "unavailable",
                expectedOutput: payload.expected_output ?? null,
                actualOutput: payload.actual_output ?? payload.stdout ?? null,
                stdout: payload.stdout ?? null,
                stderr: payload.stderr ?? null,
                diffLines,
                message:
                  payload.message ??
                  (payload.output_match === "none"
                    ? "This test case has no expected output file configured."
                    : payload.output_match === "missing"
                      ? "Expected output file was not found for this test case."
                      : hasDiffPayload
                        ? undefined
                        : "Diff payload was not provided by the bridge."),
              },
            });
          }
          break;
        }

        case "tests_complete":
          break;

        case "error":
          set({
            latestRunError: event.message,
            runStatusMessage: "Error",
          });
          break;
      }
    },

    appendOutput: (text) => {
      set((state) => ({ runOutputText: state.runOutputText + text }));
    },

    setRunDone: (code) => {
      set((state) => ({
        isRunInProgress: false,
        activeTestRunContext: null,
        runStatusMessage:
          code === 0
            ? state.runStatusMessage || "Done"
            : `Engine exited with code ${code}`,
      }));
    },

    setPolicyBanner: (kind, message) => {
      set({ policyBanner: { id: crypto.randomUUID(), kind, message } });
      setTimeout(() => {
        set({ policyBanner: null });
      }, 3000);
    },

    clearPolicyBanner: () => {
      set({ policyBanner: null });
    },

    openSubmissionDetail: (submissionID) => {
      if (!get().latestRunReport) return;

      set({
        inspectorViewMode: "detail",
        selectedSubmissionID: submissionID,
        inspectorDetailTab: "overview",
        isInspectorVisible: true,
      });
    },

    closeSubmissionDetail: () => {
      set({
        inspectorViewMode: "table",
        selectedSubmissionID: null,
        inspectorDetailTab: "overview",
      });
    },

    setInspectorDetailTab: (tab) => {
      set({ inspectorDetailTab: tab });
    },

    restoreSession: async () => {
      await get().loadEngineCapabilities();

      const workspacePath = (await window.api.storeGet("workspacePath")) as
        | string
        | null;
      const expanded = (await window.api.storeGet("expandedDirectoryIDs")) as
        | string[]
        | null;
      const selected = (await window.api.storeGet("selectedFileNodeID")) as
        | string
        | null;
      const sidebarMode = (await window.api.storeGet("sidebarMode")) as
        | SidebarMode
        | null;
      const isSidebarVisible = (await window.api.storeGet("isSidebarVisible")) as
        | boolean
        | null;
      const isInspectorVisible = (await window.api.storeGet("isInspectorVisible")) as
        | boolean
        | null;
      const isOutputVisible = (await window.api.storeGet("isOutputVisible")) as
        | boolean
        | null;

      if (sidebarMode) set({ sidebarMode });
      if (isSidebarVisible !== null) set({ isSidebarVisible });
      if (isInspectorVisible !== null) set({ isInspectorVisible });
      if (isOutputVisible !== null) set({ isOutputVisible });

      if (workspacePath) {
        await get().loadWorkspace(workspacePath, expanded ?? undefined, selected);
      }
    },

    persist: () => {
      const state = get();
      window.api.storeSet("sidebarMode", state.sidebarMode);
      window.api.storeSet("isSidebarVisible", state.isSidebarVisible);
      window.api.storeSet("isInspectorVisible", state.isInspectorVisible);
      window.api.storeSet("isOutputVisible", state.isOutputVisible);
      window.api.storeSet(
        "expandedDirectoryIDs",
        Array.from(state.expandedDirectoryIDs),
      );
      window.api.storeSet("selectedFileNodeID", state.selectedFileNodeID);
      window.api.storeSet("activePolicyID", state.activePolicyID);
    },
  };
});

export function useHasWorkspace(): boolean {
  return useAppStore((state) => state.workspaceRootPath !== null);
}

export function useSelectedPolicyDisplayName(): string | null {
  const policies = useAppStore((state) => state.policies);
  const selectedID = useAppStore((state) => state.selectedPolicyID);
  return policies.find((policy) => policy.id === selectedID)?.name ?? null;
}

export function useActiveMainPaneTab(): MainPaneTab | null {
  const tabs = useAppStore((state) => state.mainPaneTabs);
  const activeID = useAppStore((state) => state.activeMainPaneTabID);
  return tabs.find((tab) => tab.id === activeID) ?? null;
}
