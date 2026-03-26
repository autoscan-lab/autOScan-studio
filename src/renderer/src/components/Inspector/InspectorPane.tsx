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
import type { SubmissionResult } from "../../types/engine";

const columnHelper = createColumnHelper<SubmissionResult>();

export function InspectorPane() {
  const report = useAppStore((s) => s.latestRunReport);
  const policies = useAppStore((s) => s.policies);
  const activePolicyID = useAppStore((s) => s.activePolicyID);
  const setActivePolicy = useAppStore((s) => s.setActivePolicy);
  const runWorkspaceSession = useAppStore((s) => s.runWorkspaceSession);
  const isRunInProgress = useAppStore((s) => s.isRunInProgress);
  const latestRunError = useAppStore((s) => s.latestRunError);

  const [sorting, setSorting] = useState<SortingState>([
    { id: "submissionPath", desc: false },
  ]);

  const activePolicy = policies.find((p) => p.id === activePolicyID);

  const columns = useMemo(
    () => [
      columnHelper.accessor("submissionPath", {
        id: "submissionPath",
        header: "Submission",
        cell: (info) => {
          const fullPath = info.getValue();
          const name = fullPath.split("/").pop() || fullPath;
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
            onChange={(e) => setActivePolicy(e.target.value || null)}
            className="ml-auto bg-canvas border border-separator rounded px-1.5 py-0.5 text-[10px] text-text-primary outline-none"
          >
            {policies.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </div>

        <button
          onClick={runWorkspaceSession}
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
          {isRunInProgress ? "Running…" : "Run Workspace"}
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

      {report && table.getRowModel().rows.length > 0 && (
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
                  className="border-b border-separator/30 hover:bg-hover/50"
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
