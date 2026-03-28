import { useEffect, useRef } from 'react'
import { useAppStore } from '../../stores/appStore'

export function OutputPane() {
  const outputText = useAppStore((s) => s.runOutputText)
  const scrollRef = useRef<HTMLPreElement>(null)

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [outputText])

  return (
    <div className="flex flex-col h-full bg-pane">
      <pre
        ref={scrollRef}
        className="flex-1 overflow-auto px-3 py-2 text-[12px] leading-[18px] text-text-primary/90 font-mono whitespace-pre-wrap border-t border-separator/70"
      >
        {outputText || 'No output yet.'}
      </pre>
    </div>
  )
}
