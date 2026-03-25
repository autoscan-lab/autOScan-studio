import { useEffect, useRef } from 'react'
import { useAppStore } from '../../stores/appStore'

export function OutputPane() {
  const outputText = useAppStore((s) => s.runOutputText)
  const statusMessage = useAppStore((s) => s.runStatusMessage)
  const isRunInProgress = useAppStore((s) => s.isRunInProgress)
  const clearOutput = useAppStore((s) => s.clearOutput)
  const cancelRun = useAppStore((s) => s.cancelRun)
  const scrollRef = useRef<HTMLPreElement>(null)

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [outputText])

  return (
    <div className="flex flex-col h-full bg-pane">
      <div className="flex items-center justify-between h-8 px-3 border-t border-separator/70 shrink-0">
        <div className="flex items-center gap-2">
          <span className="text-[11px] font-semibold text-text-secondary uppercase tracking-wider">
            Output
          </span>
          {isRunInProgress && (
            <span className="text-[10px] text-accent animate-pulse">Running…</span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <span className="text-[10px] text-text-secondary">{statusMessage}</span>
          {isRunInProgress ? (
            <button
              onClick={cancelRun}
              className="text-[10px] text-red-400 hover:text-red-300 cursor-default"
            >
              Cancel
            </button>
          ) : (
            <button
              onClick={clearOutput}
              className="text-[10px] text-text-secondary hover:text-text-primary cursor-default"
            >
              Clear
            </button>
          )}
        </div>
      </div>

      <pre
        ref={scrollRef}
        className="flex-1 overflow-auto px-3 py-2 text-[12px] leading-[18px] text-text-primary/90 font-mono whitespace-pre-wrap"
      >
        {outputText || 'No output yet.'}
      </pre>
    </div>
  )
}
