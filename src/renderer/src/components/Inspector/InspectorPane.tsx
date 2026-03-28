import { useMemo, useState } from "react";
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  useReactTable,
} from "@tanstack/react-table";
import { MdChevronLeft, MdChevronRight, MdExpandMore } from "react-icons/md";
import { useAppStore } from "../../stores/appStore";
import type { InspectorDetailTab } from "../../stores/appStore";
import type { BannedHit, SubmissionResult } from "../../types/engine";

const columnHelper = createColumnHelper<SubmissionResult>();
const DETAIL_TABS: { id: InspectorDetailTab; label: string }[] = [
  { id: "overview", label: "Compile" },
  { id: "banned", label: "Banned" },
  { id: "tests", label: "Tests" },
];

export function InspectorPane() {
  const report = useAppStore((state) => state.latestRunReport);
  const policies = useAppStore((state) => state.policies);
  const activePolicyID = useAppStore((state) => state.activePolicyID);
  const setActivePolicy = useAppStore((state) => state.setActivePolicy);
  const runWorkspaceSession = useAppStore((state) => state.runWorkspaceSession);
  const runSubmissionTestCase = useAppStore((state) => state.runSubmissionTestCase);
  const isRunInProgress = useAppStore((state) => state.isRunInProgress);
  const latestRunError = useAppStore((state) => state.latestRunError);
  const inspectorViewMode = useAppStore((state) => state.inspectorViewMode);
  const selectedSubmissionID = useAppStore((state) => state.selectedSubmissionID);
  const inspectorDetailTab = useAppStore((state) => state.inspectorDetailTab);
  const openSubmissionDetail = useAppStore((state) => state.openSubmissionDetail);
  const closeSubmissionDetail = useAppStore((state) => state.closeSubmissionDetail);
  const setInspectorDetailTab = useAppStore((state) => state.setInspectorDetailTab);
  const activePolicyTestCases = useAppStore((state) => state.activePolicyTestCases);
  const engineCapabilities = useAppStore((state) => state.engineCapabilities);
  const testCaseResultsBySubmission = useAppStore(
    (state) => state.testCaseResultsBySubmission,
  );
  const activeTestRunContext = useAppStore((state) => state.activeTestRunContext);
  const [expandedBannedGroups, setExpandedBannedGroups] = useState<
    Record<string, boolean>
  >({});

  const hasPolicies = policies.length > 0;
  const isWorkspaceRunInProgress =
    isRunInProgress && activeTestRunContext === null;
  const selectedSubmission =
    report?.submissions.find((submission) => submission.id === selectedSubmissionID) ??
    null;
  const groupedBannedHits = useMemo(
    () => groupBannedHits(selectedSubmission?.bannedHits ?? []),
    [selectedSubmission],
  );

  const columns = useMemo(
    () => [
      columnHelper.accessor("submissionPath", {
        id: "submissionPath",
        header: "Submission",
        cell: (info) => {
          const fullPath = info.getValue();
          const name = fileName(fullPath);
          return (
            <span className="block truncate text-text-primary" title={fullPath}>
              {name}
            </span>
          );
        },
      }),
      columnHelper.accessor("compileStatus", {
        id: "compileStatus",
        header: "Compile",
        cell: (info) => {
          const value = info.getValue();
          const statusColor = {
            pass: "text-green-400",
            fail: "text-red-400",
            timeout: "text-yellow-400",
          }[value];

          return <span className={`font-medium ${statusColor}`}>{value}</span>;
        },
      }),
      columnHelper.accessor("bannedHitCount", {
        id: "bannedHitCount",
        header: "Banned",
        cell: (info) => {
          const value = info.getValue();
          return (
            <span
              className={
                value > 0
                  ? "font-medium text-orange-400"
                  : "text-text-secondary"
              }
            >
              {value}
            </span>
          );
        },
      }),
    ],
    [],
  );

  const table = useReactTable({
    data: report?.submissions ?? [],
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  return (
    <div className="flex flex-col h-full bg-pane">
      <div className="border-b border-separator shrink-0">
        <div className="flex items-center justify-between h-10 px-3">
          <span className="text-[11px] font-semibold text-text-primary uppercase tracking-wider">
            Inspector
          </span>
        </div>
      </div>

      <div className="px-3 py-2.5 space-y-2 border-b border-separator shrink-0">
        {hasPolicies ? (
          <>
            <div className="space-y-1">
              <span className="block text-[11px] font-medium text-text-primary">
                Choose policy
              </span>
              <div className="flex items-center gap-2">
                <div className="relative min-w-0 flex-1">
                  <select
                    value={activePolicyID ?? ""}
                    onChange={(event) => void setActivePolicy(event.target.value || null)}
                    className="h-8 w-full appearance-none rounded-md border border-separator bg-canvas/70 pl-2.5 pr-8 text-[12px] font-medium text-text-primary outline-none hover:border-separator focus:border-accent"
                  >
                    {policies.map((policy) => (
                      <option key={policy.id} value={policy.id}>
                        {policy.name}
                      </option>
                    ))}
                  </select>
                  <span className="pointer-events-none absolute inset-y-0 right-2 flex items-center text-text-secondary">
                    <MdExpandMore size={17} />
                  </span>
                </div>
                <button
                  onClick={() => void runWorkspaceSession()}
                  disabled={isRunInProgress || !activePolicyID}
                  className={`
                    h-8 shrink-0 rounded-md px-3 text-[11px] font-semibold cursor-default
                    ${
                      isRunInProgress || !activePolicyID
                        ? "bg-hover text-text-secondary"
                        : "bg-accent text-white hover:bg-accent-hover"
                    }
                  `}
                >
                  {isWorkspaceRunInProgress ? "Running…" : "Run Workspace"}
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="px-0.5 py-0.5">
            <p className="text-[11px] font-medium text-text-primary">
              No policies found
            </p>
            <p className="mt-1 text-[10px] text-text-secondary">
              Create a policy in the Policies panel to run the workspace.
            </p>
          </div>
        )}
      </div>

      {latestRunError && (
        <div className="mx-3 mt-2 rounded-md px-3 py-2 text-[11px] bg-banner-error text-red-200">
          {latestRunError}
        </div>
      )}

      {report && table.getRowModel().rows.length > 0 && inspectorViewMode === "table" && (
        <div className="flex-1 overflow-auto">
          <table className="w-full border-separate border-spacing-0 text-[11px]">
            <thead className="sticky top-0 z-10 bg-pane">
              {table.getHeaderGroups().map((headerGroup) => (
                <tr
                  key={headerGroup.id}
                  className="text-text-secondary"
                >
                  {headerGroup.headers.map((header) => {
                    return (
                      <th
                        key={header.id}
                        className="border-b border-separator px-2 py-1.5 text-left font-medium"
                      >
                        {flexRender(
                          header.column.columnDef.header,
                          header.getContext(),
                        )}
                      </th>
                    );
                  })}
                </tr>
              ))}
            </thead>
            <tbody>
              {table.getRowModel().rows.map((row, index, rows) => (
                <tr
                  key={row.id}
                  onClick={() => openSubmissionDetail(row.original.id)}
                  className="hover:bg-hover/50 cursor-pointer"
                >
                  {row.getVisibleCells().map((cell) => (
                    <td
                      key={cell.id}
                      className={`
                        px-2 py-1.5 align-middle
                        ${
                          index === rows.length - 1
                            ? "border-b border-separator"
                            : "border-b border-separator/30"
                        }
                      `}
                    >
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext(),
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {inspectorViewMode === "detail" && (
        <div className="flex-1 min-h-0 flex flex-col">
          <div className="flex items-center gap-2 px-3 py-2 border-b border-separator shrink-0">
            <button
              onClick={closeSubmissionDetail}
              aria-label="Back to submissions table"
              title="Back"
              className="text-accent hover:text-accent-hover"
            >
              <MdChevronLeft size={19} />
            </button>
            <span className="text-[11px] font-semibold text-text-primary truncate">
              {selectedSubmission
                ? fileName(selectedSubmission.submissionPath)
                : "Submission details"}
            </span>
          </div>

          {!selectedSubmission ? (
            <div className="flex-1 flex items-center justify-center px-3">
              <p className="text-[11px] text-text-secondary">
                Submission is no longer available in the latest report.
              </p>
            </div>
          ) : (
            <>
              <div className="flex h-9 items-stretch border-b border-separator shrink-0">
                {DETAIL_TABS.map((tab, index) => (
                  <button
                    key={tab.id}
                    onClick={() => setInspectorDetailTab(tab.id)}
                    className={`
                      flex-1 min-w-0 h-full px-2 text-[10px] font-semibold cursor-default
                      ${index < DETAIL_TABS.length - 1 ? "border-r border-separator" : ""}
                      ${
                        inspectorDetailTab === tab.id
                          ? "bg-hover text-text-primary"
                          : "bg-pane text-text-primary hover:bg-hover/80"
                      }
                    `}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>

              <div className="flex-1 min-h-0 overflow-auto p-3">
                {inspectorDetailTab === "overview" && (
                  <div>
                    <div className="mb-3 flex items-center justify-between text-[11px]">
                      <span className="text-text-secondary">Compile details</span>
                    </div>
                    <div className="-mx-3 border-b border-t border-separator">
                      <pre className="px-3 py-2 text-[11px] whitespace-pre-wrap font-mono text-text-primary">
                        {selectedSubmission.stderr || "No compile output."}
                      </pre>
                    </div>

                    <div className="-mx-3 border-b border-separator px-3 py-1.5">
                      <div className="grid grid-cols-[120px_1fr] gap-3 text-[11px]">
                        <span className="text-text-secondary">C files</span>
                        <div className="flex flex-wrap gap-1.5">
                          {selectedSubmission.cFiles.length > 0 ? (
                            selectedSubmission.cFiles.map((cFile) => (
                              <span
                                key={cFile}
                                className="rounded-sm border border-separator bg-hover/30 px-2 py-0.5 text-[10px] font-mono text-text-primary"
                              >
                                {cFile}
                              </span>
                            ))
                          ) : (
                            <span className="text-text-secondary">No C files detected.</span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                {inspectorDetailTab === "banned" && (
                  <div className="space-y-3">
                    <div className="flex items-center justify-between text-[11px]">
                      <span className="text-text-secondary">Total hits</span>
                      <span className="font-semibold text-text-primary">
                        {selectedSubmission.bannedHitCount}
                      </span>
                    </div>

                    {selectedSubmission.bannedHits.length === 0 ? (
                      <p className="text-[11px] text-text-secondary">
                        No banned hits detected for this submission.
                      </p>
                    ) : (
                      <div className="-mx-3">
                        {groupedBannedHits.map((group, groupIndex) => {
                          const groupKey = `${selectedSubmission.id}::${group.functionName.toLowerCase()}`;
                          const isExpanded = expandedBannedGroups[groupKey] ?? true;

                          return (
                            <section
                              key={groupKey}
                              className={`border-b border-separator ${groupIndex === 0 ? "border-t" : ""}`}
                            >
                              <button
                                onClick={() =>
                                  setExpandedBannedGroups((state) => ({
                                    ...state,
                                    [groupKey]: !isExpanded,
                                  }))
                                }
                                className="flex w-full items-center gap-2 px-3 py-2 text-left text-[11px] hover:bg-hover/30 cursor-default"
                              >
                                <span className="font-semibold uppercase tracking-wide text-text-primary">
                                  {group.functionName}
                                </span>
                                <span className="text-text-secondary">
                                  ({group.hits.length})
                                </span>
                                <span className="ml-auto text-text-secondary">
                                  {isExpanded ? (
                                    <MdExpandMore size={18} />
                                  ) : (
                                    <MdChevronRight size={18} />
                                  )}
                                </span>
                              </button>

                              {isExpanded && (
                                <div className="pb-1">
                                  {group.hits.map((hit, index) => (
                                    <div
                                      key={`${groupKey}-${hit.line ?? index}-${index}`}
                                      className="flex items-start gap-2 border-b border-separator px-3 py-2 text-[11px] last:border-b-0"
                                    >
                                      <pre className="min-w-0 flex-1 whitespace-pre-wrap font-mono text-text-primary">
                                        {hit.snippet || "(no snippet)"}
                                      </pre>
                                      <span className="shrink-0 text-text-secondary">
                                        {hit.line !== null ? `L${hit.line}` : "L?"}
                                      </span>
                                    </div>
                                  ))}
                                </div>
                              )}
                            </section>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}

                {inspectorDetailTab === "tests" && (
                  <div className="space-y-3">
                    <div className="flex items-center justify-between text-[11px]">
                      <span className="text-text-secondary">Total tests</span>
                      <span className="font-semibold text-text-primary">
                        {activePolicyTestCases.length}
                      </span>
                    </div>
                    {activePolicyTestCases.length === 0 ? (
                      <p className="text-[11px] text-text-secondary">
                        No test cases found in the active policy.
                      </p>
                    ) : (
                      <div className="-mx-3">
                        {activePolicyTestCases.map((testCase, testIndex) => {
                          const result = selectedSubmission
                            ? testCaseResultsBySubmission[selectedSubmission.id]?.[
                                testCase.id
                              ] ?? null
                            : null;
                          const isSingleRunForThisCase =
                            isRunInProgress &&
                            activeTestRunContext?.mode === "single" &&
                            activeTestRunContext.submissionID === selectedSubmission?.id &&
                            activeTestRunContext.singleTestCaseID === testCase.id;
                          const isThisTestRunning = isSingleRunForThisCase;
                          const effectiveStatus = isThisTestRunning
                            ? "running"
                            : (result?.status ?? "idle");
                          const statusTone = statusToneClass(effectiveStatus);
                          const statusLabel = effectiveStatus.replace(/_/g, " ");

                          return (
                            <div
                              key={testCase.id}
                              className={`border-b border-separator px-3 py-2.5 ${testIndex === 0 ? "border-t" : ""}`}
                            >
                              {selectedSubmission && (
                                <div className="mb-1.5 flex items-center justify-between text-[10px]">
                                  <span className={`uppercase tracking-wider ${statusTone}`}>
                                    {statusLabel}
                                  </span>
                                  {result?.durationMs !== null &&
                                    result?.durationMs !== undefined && (
                                      <span className="text-text-secondary">
                                        {result.durationMs}ms
                                      </span>
                                    )}
                                </div>
                              )}
                              <div className="flex items-center gap-2">
                                <span className="truncate text-[12px] font-medium text-text-primary">
                                  {testCase.name || "Untitled test"}
                                </span>
                                <div className="ml-auto flex items-center gap-1.5">
                                  <button
                                    onClick={() =>
                                      void runSubmissionTestCase(
                                        selectedSubmission.id,
                                        testCase.id,
                                      )
                                    }
                                    disabled={
                                      isRunInProgress || !engineCapabilities.testCaseRun
                                    }
                                    className={`
                                      rounded px-2 py-1 text-[10px] cursor-default
                                      ${
                                        isRunInProgress || !engineCapabilities.testCaseRun
                                          ? "bg-hover text-text-secondary"
                                          : "bg-accent text-white hover:bg-accent-hover"
                                      }
                                    `}
                                  >
                                    {isThisTestRunning
                                      ? "Running…"
                                      : "Run Test"}
                                  </button>
                                </div>
                              </div>
                              <div className="mt-2 space-y-1 text-[11px] text-text-secondary">
                                <p>
                                  args:{" "}
                                  {testCase.args.length > 0 ? testCase.args.join(" ") : "(none)"}
                                </p>
                                <p>
                                  expected exit: {testCase.expectedExit || "(unspecified)"}
                                </p>
                                {selectedSubmission &&
                                  result &&
                                  result.message && <p>{result.message}</p>}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                )}

              </div>
            </>
          )}
        </div>
      )}

      {!report && !latestRunError && (
        <div className="flex-1 flex items-center justify-center">
          <p className="text-[11px] text-text-secondary/60">
            Run a session to see results.
          </p>
        </div>
      )}
    </div>
  );
}

function fileName(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  const segments = normalized.split("/");
  return segments[segments.length - 1] || path;
}

function groupBannedHits(
  hits: BannedHit[],
): { functionName: string; hits: BannedHit[] }[] {
  const groups = new Map<string, { functionName: string; hits: BannedHit[] }>();

  for (const hit of hits) {
    const key = hit.functionName.toLowerCase();
    const group = groups.get(key);
    if (group) {
      group.hits.push(hit);
      continue;
    }

    groups.set(key, {
      functionName: hit.functionName,
      hits: [hit],
    });
  }

  return Array.from(groups.values());
}

function statusToneClass(status: string): string {
  if (status === "pass") return "text-green-400";
  if (status === "timeout") return "text-yellow-400";
  if (status === "running") return "text-accent";
  if (status === "compile_failed" || status === "fail" || status === "error") {
    return "text-red-400";
  }
  return "text-text-secondary";
}
