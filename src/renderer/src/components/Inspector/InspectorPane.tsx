import { useState, useMemo } from 'react'
import { useAppStore } from '../../stores/appStore'
import type { SubmissionResult } from '../../types/engine'

type SortKey = 'path' | 'compile' | 'banned'
type SortDir = 'asc' | 'desc'

export function InspectorPane() {
  const report = useAppStore((s) => s.latestRunReport)
  const policies = useAppStore((s) => s.policies)
  const activePolicyID = useAppStore((s) => s.activePolicyID)
  const runWorkspaceSession = useAppStore((s) => s.runWorkspaceSession)
  const isRunInProgress = useAppStore((s) => s.isRunInProgress)
  const latestRunError = useAppStore((s) => s.latestRunError)

  const [sortKey, setSortKey] = useState<SortKey>('path')
  const [sortDir, setSortDir] = useState<SortDir>('asc')

  const activePolicy = policies.find((p) => p.id === activePolicyID)

  const handleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    } else {
      setSortKey(key)
      setSortDir('asc')
    }
  }

  const sortedSubmissions = useMemo(() => {
    if (!report) return []
    const subs = [...report.submissions]
    subs.sort((a, b) => {
      let cmp = 0
      switch (sortKey) {
        case 'path':
          cmp = a.submissionPath.localeCompare(b.submissionPath)
          break
        case 'compile':
          cmp = a.compileStatus.localeCompare(b.compileStatus)
          break
        case 'banned':
          cmp = a.bannedHitCount - b.bannedHitCount
          break
      }
      return sortDir === 'asc' ? cmp : -cmp
    })
    return subs
  }, [report, sortKey, sortDir])

  return (
    <div className="flex flex-col h-full bg-pane">
      {/* Header */}
      <div className="border-y border-separator/70 shrink-0">
        <div className="flex items-center justify-between h-10 px-3">
          <span className="text-[11px] font-semibold text-text-secondary uppercase tracking-wider">
            Inspector
          </span>
        </div>
      </div>

      {/* Controls */}
      <div className="px-3 py-2.5 space-y-2 border-b border-separator/50 shrink-0">
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-text-secondary">Policy:</span>
          <span className="text-[11px] text-text-primary font-medium truncate">
            {activePolicy?.name ?? 'None'}
          </span>
          <select
            value={activePolicyID ?? ''}
            onChange={(e) => useAppStore.setState({ activePolicyID: e.target.value || null })}
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
            ${isRunInProgress || !activePolicyID
              ? 'bg-hover text-text-secondary'
              : 'bg-accent text-white hover:bg-accent-hover'}
          `}
        >
          {isRunInProgress ? 'Running…' : 'Run Workspace'}
        </button>
      </div>

      {/* Error */}
      {latestRunError && (
        <div className="mx-3 mt-2 rounded-md px-3 py-2 text-[11px] bg-banner-error text-red-200">
          {latestRunError}
        </div>
      )}

      {/* Summary */}
      {report && (
        <div className="px-3 py-2 border-b border-separator/50 shrink-0">
          <div className="grid grid-cols-3 gap-2 text-[11px]">
            <Stat label="Total" value={report.summary.totalSubmissions} />
            <Stat label="Pass" value={report.summary.compilePass} color="text-green-400" />
            <Stat label="Fail" value={report.summary.compileFail} color="text-red-400" />
            <Stat label="Timeout" value={report.summary.compileTimeout} color="text-yellow-400" />
            <Stat label="Clean" value={report.summary.cleanSubmissions} color="text-green-400" />
            <Stat label="Banned" value={report.summary.bannedHits} color="text-orange-400" />
          </div>
        </div>
      )}

      {/* Results Table */}
      {report && sortedSubmissions.length > 0 && (
        <div className="flex-1 overflow-auto">
          <table className="w-full text-[11px]">
            <thead className="sticky top-0 bg-pane">
              <tr className="text-text-secondary border-b border-separator/50">
                <SortHeader label="Submission" sortKey="path" current={sortKey} dir={sortDir} onClick={handleSort} />
                <SortHeader label="Compile" sortKey="compile" current={sortKey} dir={sortDir} onClick={handleSort} />
                <SortHeader label="Banned" sortKey="banned" current={sortKey} dir={sortDir} onClick={handleSort} />
              </tr>
            </thead>
            <tbody>
              {sortedSubmissions.map((sub) => (
                <ResultRow key={sub.submissionPath} result={sub} />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {!report && !latestRunError && (
        <div className="flex-1 flex items-center justify-center">
          <p className="text-[11px] text-text-secondary/60">Run a session to see results.</p>
        </div>
      )}
    </div>
  )
}

function Stat({ label, value, color }: { label: string; value: number; color?: string }) {
  return (
    <div>
      <span className="text-text-secondary">{label}: </span>
      <span className={`font-semibold ${color ?? 'text-text-primary'}`}>{value}</span>
    </div>
  )
}

function SortHeader({
  label,
  sortKey,
  current,
  dir,
  onClick
}: {
  label: string
  sortKey: SortKey
  current: SortKey
  dir: SortDir
  onClick: (key: SortKey) => void
}) {
  return (
    <th
      onClick={() => onClick(sortKey)}
      className="text-left px-2 py-1.5 font-medium cursor-default hover:text-text-primary"
    >
      {label}
      {current === sortKey && (
        <span className="ml-0.5 text-[9px]">{dir === 'asc' ? '▲' : '▼'}</span>
      )}
    </th>
  )
}

function ResultRow({ result }: { result: SubmissionResult }) {
  const name = result.submissionPath.split('/').pop() || result.submissionPath

  const statusColor = {
    pass: 'text-green-400',
    fail: 'text-red-400',
    timeout: 'text-yellow-400'
  }[result.compileStatus]

  return (
    <tr className="border-b border-separator/30 hover:bg-hover/50">
      <td className="px-2 py-1.5 text-text-primary truncate max-w-[180px]" title={result.submissionPath}>
        {name}
      </td>
      <td className={`px-2 py-1.5 font-medium ${statusColor}`}>
        {result.compileStatus}
      </td>
      <td className={`px-2 py-1.5 ${result.bannedHitCount > 0 ? 'text-orange-400 font-medium' : 'text-text-secondary'}`}>
        {result.bannedHitCount}
      </td>
    </tr>
  )
}
