import { useMemo } from "react";
import Editor from "@monaco-editor/react";
import { useAppStore } from "../../stores/appStore";

const EXT_TO_LANG: Record<string, string> = {
  ".c": "c",
  ".h": "c",
  ".cpp": "cpp",
  ".cc": "cpp",
  ".cxx": "cpp",
  ".hpp": "cpp",
  ".yaml": "yaml",
  ".yml": "yaml",
  ".json": "json",
  ".md": "markdown",
  ".txt": "plaintext",
  ".py": "python",
  ".sh": "shell",
  ".bash": "shell",
  ".makefile": "makefile",
};

export function CodeViewer() {
  const editorText = useAppStore((s) => s.editorText);
  const editorDocumentKind = useAppStore((s) => s.editorDocumentKind);
  const editorFilePath = useAppStore((s) => s.editorFilePath);

  const language = useMemo(() => {
    if (!editorFilePath) return "plaintext";
    const ext = "." + editorFilePath.split(".").pop()?.toLowerCase();
    return EXT_TO_LANG[ext] ?? "plaintext";
  }, [editorFilePath]);

  if (editorDocumentKind === "notice") {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-sm text-text-secondary/70">{editorText}</p>
      </div>
    );
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
        renderLineHighlight: "all",
        overviewRulerLanes: 0,
        hideCursorInOverviewRuler: true,
        scrollbar: {
          verticalScrollbarSize: 8,
          horizontalScrollbarSize: 8,
        },
        wordWrap: "off",
        contextmenu: false,
        find: {
          addExtraSpaceOnTop: false,
        },
      }}
      beforeMount={(monaco) => {
        monaco.editor.defineTheme("autoscan-dark", {
          base: "vs-dark",
          inherit: true,
          rules: [
            { token: "", foreground: "F0F6FC", background: "0D1117" },
            { token: "comment", foreground: "9198A1" },
            { token: "comment.doc", foreground: "9198A1" },
            { token: "keyword", foreground: "FF7B72" },
            { token: "keyword.operator", foreground: "FF7B72" },
            { token: "operator", foreground: "FF7B72" },
            { token: "string", foreground: "A5D6FF" },
            { token: "string.escape", foreground: "FF7B72" },
            { token: "number", foreground: "79C0FF" },
            { token: "type", foreground: "FFA657" },
            { token: "type.identifier", foreground: "FFA657" },
            { token: "entity.name.function", foreground: "D2A8FF" },
            { token: "support.function", foreground: "D2A8FF" },
            { token: "variable.parameter", foreground: "FFA657" },
            { token: "constant", foreground: "79C0FF" },
            { token: "constant.language", foreground: "79C0FF" },
            { token: "preprocessor", foreground: "FF7B72" },
            { token: "delimiter", foreground: "F0F6FC" },
            { token: "delimiter.bracket", foreground: "F0F6FC" },
          ],
          colors: {
            "editor.background": "#0d1117",
            "editor.foreground": "#f0f6fc",
            "editorLineNumber.foreground": "#9198a1",
            "editorLineNumber.activeForeground": "#f0f6fc",
            "editor.lineHighlightBackground": "#151b23",
            "editor.selectionBackground": "#4493f84d",
            "editor.inactiveSelectionBackground": "#4493f833",
            "editorCursor.foreground": "#58a6ff",
            "editorWhitespace.foreground": "#656c76",
            "editorIndentGuide.background1": "#3d444db3",
            "editorIndentGuide.activeBackground1": "#3d444db3",
            "editorRuler.foreground": "#3d444db3",
            "editorGutter.background": "#0d1117",
            "editorWidget.background": "#151b23",
            "editorWidget.border": "#3d444db3",
            "editorHoverWidget.background": "#151b23",
            "editorHoverWidget.border": "#3d444db3",
            "editorSuggestWidget.background": "#151b23",
            "editorSuggestWidget.border": "#3d444db3",
            "editorSuggestWidget.selectedBackground": "#656c7633",
            "editorBracketMatch.background": "#4493f84d",
            "editorBracketMatch.border": "#1f6feb",
            "scrollbarSlider.background": "#656c764d",
            "scrollbarSlider.hoverBackground": "#656c7666",
            "scrollbarSlider.activeBackground": "#656c7680",
          },
        });
      }}
      onMount={(editor, monaco) => {
        monaco.editor.setTheme("autoscan-dark");
        editor.updateOptions({
          theme: "autoscan-dark",
        });
      }}
    />
  );
}
