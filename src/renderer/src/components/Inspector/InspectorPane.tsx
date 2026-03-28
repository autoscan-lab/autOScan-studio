import { useMemo, useState } from "react";
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  type SortingState,
} from "@tanstack/react-table";
import { useAppStore } from "../../stores/appStore";
import type { InspectorDetailTab } from "../../stores/appStore";
import type { SubmissionResult } from "../../types/engine";

const columnHelper = createColumnHelper<SubmissionResult>();
const DETAIL_TABS: { id: InspectorDetailTab; label: string }[] = [
  { id: "overview", label: "Overview" },
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

  const [sorting, setSorting] = useState<SortingState>([
    { id: "submissionPath", desc: false },
  ]);

  const activePolicy = policies.find((policy) => policy.id === activePolicyID);
  const isWorkspaceRunInProgress =
    isRunInProgress && activeTestRunContext === null;
  const selectedSubmission =
    report?.submissions.find((submission) => submission.id === selectedSubmissionID) ??
    null;

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
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
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

      <div className="px-3 py-2.5 space-y-2 border-b border-separator/50 shrink-0">
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-text-primary">Policy:</span>
          <span className="text-[11px] text-text-primary font-medium truncate">
            {activePolicy?.name ?? "None"}
          </span>
          <select
            value={activePolicyID ?? ""}
            onChange={(event) => void setActivePolicy(event.target.value || null)}
            className="ml-auto bg-canvas border border-separator rounded px-1.5 py-0.5 text-[10px] text-text-primary outline-none"
          >
            {policies.map((policy) => (
              <option key={policy.id} value={policy.id}>
                {policy.name}
              </option>
            ))}
          </select>
        </div>

        <button
          onClick={() => void runWorkspaceSession()}
          disabled={isRunInProgress || !activePolicyID}
          className={`
            w-full py-1.5 rounded-md text-[12px] font-semibold cursor-default
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

      {latestRunError && (
        <div className="mx-3 mt-2 rounded-md px-3 py-2 text-[11px] bg-banner-error text-red-200">
          {latestRunError}
        </div>
      )}

      {report && (
        <div className="px-3 py-2 border-b border-separator/50 shrink-0">
          <div className="grid grid-cols-3 gap-2 text-[11px]">
            <Stat label="Total" value={report.summary.totalSubmissions} />
            <Stat
              label="Pass"
              value={report.summary.compilePass}
              color="text-green-400"
            />
            <Stat
              label="Fail"
              value={report.summary.compileFail}
              color="text-red-400"
            />
            <Stat
              label="Timeout"
              value={report.summary.compileTimeout}
              color="text-yellow-400"
            />
            <Stat
              label="Clean"
              value={report.summary.cleanSubmissions}
              color="text-green-400"
            />
            <Stat
              label="Banned"
              value={report.summary.bannedHits}
              color="text-orange-400"
            />
          </div>
        </div>
      )}

      {report && table.getRowModel().rows.length > 0 && inspectorViewMode === "table" && (
        <div className="flex-1 overflow-auto">
          <table className="w-full text-[11px]">
            <thead className="sticky top-0 bg-pane z-10">
              {table.getHeaderGroups().map((headerGroup) => (
                <tr
                  key={headerGroup.id}
                  className="border-b border-separator/50 text-text-secondary"
                >
                  {headerGroup.headers.map((header) => {
                    const canSort = header.column.getCanSort();
                    const sorted = header.column.getIsSorted();

                    return (
                      <th
                        key={header.id}
                        onClick={
                          canSort
                            ? header.column.getToggleSortingHandler()
                            : undefined
                        }
                        className={`px-2 py-1.5 text-left font-medium ${canSort ? "cursor-default hover:text-text-primary" : ""}`}
                      >
                        {flexRender(
                          header.column.columnDef.header,
                          header.getContext(),
                        )}
                        {sorted === "asc" && (
                          <span className="ml-0.5 text-[9px]">▲</span>
                        )}
                        {sorted === "desc" && (
                          <span className="ml-0.5 text-[9px]">▼</span>
                        )}
                      </th>
                    );
                  })}
                </tr>
              ))}
            </thead>
            <tbody>
              {table.getRowModel().rows.map((row) => (
                <tr
                  key={row.id}
                  onClick={() => openSubmissionDetail(row.original.id)}
                  className="border-b border-separator/30 hover:bg-hover/50 cursor-pointer"
                >
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className="px-2 py-1.5 align-middle">
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
          <div className="flex items-center gap-2 px-3 py-2 border-b border-separator/50 shrink-0">
            <button
              onClick={closeSubmissionDetail}
              aria-label="Back to submissions table"
              title="Back"
              className="text-[11px] text-accent hover:text-accent-hover"
            >
              ←
            </button>
            <span className="ml-1 text-[11px] font-semibold text-text-primary truncate">
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
              <div className="flex h-9 items-stretch border-b border-separator/50 shrink-0">
                {DETAIL_TABS.map((tab, index) => (
                  <button
                    key={tab.id}
                    onClick={() => setInspectorDetailTab(tab.id)}
                    className={`
                      flex-1 min-w-0 h-full px-2 text-[10px] font-semibold cursor-default
                      ${index < DETAIL_TABS.length - 1 ? "border-r border-separator/60" : ""}
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
                  <div className="space-y-3">
                    <section className="rounded-md border border-separator/60 bg-canvas/30">
                      <div className="flex items-center justify-between border-b border-separator/50 px-3 py-2">
                        <span className="text-[10px] uppercase tracking-wider text-text-secondary">
                          Compile Summary
                        </span>
                        <span
                          className={`text-[10px] font-semibold uppercase tracking-wider ${
                            selectedSubmission.compileStatus === "pass"
                              ? "text-green-400"
                              : selectedSubmission.compileStatus === "timeout"
                                ? "text-yellow-400"
                                : "text-red-400"
                          }`}
                        >
                          {selectedSubmission.compileStatus}
                        </span>
                      </div>

                      <dl className="grid grid-cols-[auto,1fr] gap-x-3 gap-y-2 px-3 py-2.5 text-[12px]">
                        <dt className="text-text-secondary">Time</dt>
                        <dd className="text-text-primary">
                          {selectedSubmission.compileTimeMs}ms
                        </dd>

                        <dt className="text-text-secondary">Exit Code</dt>
                        <dd className="text-text-primary">
                          {selectedSubmission.exitCode === null
                            ? "N/A"
                            : String(selectedSubmission.exitCode)}
                        </dd>

                        <dt className="text-text-secondary">Banned Hits</dt>
                        <dd
                          className={
                            selectedSubmission.bannedHitCount > 0
                              ? "text-orange-400"
                              : "text-text-primary"
                          }
                        >
                          {selectedSubmission.bannedHitCount}
                        </dd>
                      </dl>
                    </section>

                    <section className="rounded-md border border-separator/60 bg-canvas/30">
                      <div className="border-b border-separator/50 px-3 py-2">
                        <span className="text-[10px] uppercase tracking-wider text-text-secondary">
                          Compile
                        </span>
                      </div>
                      <div className="px-3 py-2.5">
                        <pre className="text-[11px] text-text-primary whitespace-pre-wrap font-mono">
                          {selectedSubmission.stderr || "No compile output."}
                        </pre>
                      </div>
                    </section>

                    <div>
                      <p className="text-[10px] text-text-secondary uppercase tracking-wider">
                        C Files
                      </p>
                      {selectedSubmission.cFiles.length > 0 ? (
                        <div className="mt-2 flex flex-wrap gap-1.5">
                          {selectedSubmission.cFiles.map((cFile) => (
                            <span
                              key={cFile}
                              className="rounded-sm border border-separator/60 bg-hover/40 px-2 py-0.5 text-[10px] font-mono text-text-primary"
                            >
                              {cFile}
                            </span>
                          ))}
                        </div>
                      ) : (
                        <p className="mt-2 text-[11px] text-text-secondary">
                          No C files detected.
                        </p>
                      )}
                    </div>
                  </div>
                )}

                {inspectorDetailTab === "banned" && (
                  <div className="space-y-3">
                    <Info
                      label="Banned hits"
                      value={String(selectedSubmission.bannedHitCount)}
                    />
                    <p className="text-[11px] text-text-secondary">
                      Per-hit snippets and line details will appear here when the
                      bridge report includes full banned hit payloads.
                    </p>
                  </div>
                )}

                {inspectorDetailTab === "tests" && (
                  <div className="space-y-3">
                    {activePolicyTestCases.length === 0 ? (
                      <p className="text-[11px] text-text-secondary">
                        No test cases found in the active policy.
                      </p>
                    ) : (
                      <div className="space-y-2">
                        {activePolicyTestCases.map((testCase) => {
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
                            <section
                              key={testCase.id}
                              className="rounded-md border border-separator/60 bg-canvas/40 p-3"
                            >
                              {selectedSubmission && (
                                <div className="mb-2 flex items-center justify-between text-[10px]">
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
                              <span className="text-[12px] font-medium text-text-primary truncate">
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
                            <div className="mt-2 text-[11px] text-text-secondary space-y-1">
                              <p>
                                args: {testCase.args.length > 0 ? testCase.args.join(" ") : "(none)"}
                              </p>
                              <p>
                                expected exit: {testCase.expectedExit || "(unspecified)"}
                              </p>
                              {selectedSubmission &&
                                result && (
                                  <>
                                    {result.message && <p>{result.message}</p>}
                                  </>
                                )}
                            </div>
                            </section>
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

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <span className="text-text-secondary">{label}: </span>
      <span className="text-text-primary">{value}</span>
    </div>
  );
}

function Stat({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color?: string;
}) {
  return (
    <div>
      <span className="text-text-secondary">{label}: </span>
      <span className={`font-semibold ${color ?? "text-text-primary"}`}>
        {value}
      </span>
    </div>
  );
}

function fileName(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  const segments = normalized.split("/");
  return segments[segments.length - 1] || path;
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
