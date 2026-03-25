import { useMemo } from 'react'
import Editor from '@monaco-editor/react'
import { useAppStore } from '../../stores/appStore'

const EXT_TO_LANG: Record<string, string> = {
  '.c': 'c',
  '.h': 'c',
  '.cpp': 'cpp',
  '.cc': 'cpp',
  '.cxx': 'cpp',
  '.hpp': 'cpp',
  '.yaml': 'yaml',
  '.yml': 'yaml',
  '.json': 'json',
  '.md': 'markdown',
  '.txt': 'plaintext',
  '.py': 'python',
  '.sh': 'shell',
  '.bash': 'shell',
  '.makefile': 'makefile'
}

export function CodeViewer() {
  const editorText = useAppStore((s) => s.editorText)
  const editorDocumentKind = useAppStore((s) => s.editorDocumentKind)
  const editorFilePath = useAppStore((s) => s.editorFilePath)

  const language = useMemo(() => {
    if (!editorFilePath) return 'plaintext'
    const ext = '.' + editorFilePath.split('.').pop()?.toLowerCase()
    return EXT_TO_LANG[ext] ?? 'plaintext'
  }, [editorFilePath])

  if (editorDocumentKind === 'notice') {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-sm text-text-secondary/70">{editorText}</p>
      </div>
    )
  }

  return (
    <Editor
      value={editorText}
      language={language}
      theme="autoscan-dark"
      options={{
        readOnly: true,
        minimap: { enabled: false },
        fontSize: 13,
        fontFamily: "'SF Mono', 'Menlo', 'Monaco', 'Courier New', monospace",
        lineHeight: 20,
        padding: { top: 8 },
        scrollBeyondLastLine: false,
        renderLineHighlight: 'none',
        overviewRulerLanes: 0,
        hideCursorInOverviewRuler: true,
        scrollbar: {
          verticalScrollbarSize: 8,
          horizontalScrollbarSize: 8
        },
        wordWrap: 'off',
        contextmenu: false,
        find: {
          addExtraSpaceOnTop: false
        }
      }}
      beforeMount={(monaco) => {
        monaco.editor.defineTheme('autoscan-dark', {
          base: 'vs-dark',
          inherit: true,
          rules: [],
          colors: {
            'editor.background': '#22252C',
            'editor.foreground': '#F2F4F8',
            'editorLineNumber.foreground': '#929AAC60',
            'editorLineNumber.activeForeground': '#929AAC',
            'editor.selectionBackground': '#6E789050',
            'editorWidget.background': '#1C1F25',
            'editorWidget.border': '#323743'
          }
        })
      }}
    />
  )
}
