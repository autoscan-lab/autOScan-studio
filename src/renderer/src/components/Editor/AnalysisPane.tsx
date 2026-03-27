import type {
  AIMainPaneTab,
  DiffMainPaneTab,
  MainPaneTab,
  SimilarityMainPaneTab,
} from "../../stores/appStore";

export function AnalysisPane({ tab }: { tab: MainPaneTab }) {
  if (tab.kind === "diff") {
    return <DiffPane tab={tab} />;
  }

  if (tab.kind === "similarity") {
    return <SimilarityPane tab={tab} />;
  }

  if (tab.kind === "ai") {
    return <AIPane tab={tab} />;
  }

  return null;
}

function DiffPane({ tab }: { tab: DiffMainPaneTab }) {
  return (
    <div className="h-full overflow-auto p-4 space-y-4">
      <section className="rounded-md border border-separator/60 bg-pane/50 p-3">
        <p className="text-[11px] text-text-secondary uppercase tracking-wider">
          Diff Context
        </p>
        <div className="mt-2 text-[12px] text-text-primary space-y-1">
          <p>
            <span className="text-text-secondary">Submission:</span>{" "}
            {tab.payload.submissionID}
          </p>
          <p>
            <span className="text-text-secondary">Test case:</span>{" "}
            {tab.payload.testCaseID}
          </p>
        </div>
      </section>

      {tab.payload.state === "unavailable" && (
        <section className="rounded-md border border-separator/60 bg-canvas/40 p-4">
          <p className="text-[12px] text-text-primary">
            {tab.payload.message ||
              "Diff output is not available yet. Bridge test-case execution support is required."}
          </p>
        </section>
      )}

      {tab.payload.state === "ready" && (
        <>
          <section className="grid grid-cols-2 gap-3">
            <div className="rounded-md border border-separator/60 bg-canvas/40 p-3">
              <p className="text-[11px] text-text-secondary uppercase tracking-wider mb-2">
                Expected Output
              </p>
              <pre className="text-[12px] text-text-primary whitespace-pre-wrap font-mono">
                {tab.payload.expectedOutput ?? "(empty)"}
              </pre>
            </div>
            <div className="rounded-md border border-separator/60 bg-canvas/40 p-3">
              <p className="text-[11px] text-text-secondary uppercase tracking-wider mb-2">
                Actual Output
              </p>
              <pre className="text-[12px] text-text-primary whitespace-pre-wrap font-mono">
                {tab.payload.actualOutput ?? "(empty)"}
              </pre>
            </div>
          </section>

          <section className="rounded-md border border-separator/60 bg-canvas/40 p-3">
            <p className="text-[11px] text-text-secondary uppercase tracking-wider mb-2">
              Line Diff
            </p>
            {tab.payload.diffLines && tab.payload.diffLines.length > 0 ? (
              <div className="space-y-1">
                {tab.payload.diffLines.map((line, index) => (
                  <pre
                    key={`${line.type}-${line.line ?? index}-${index}`}
                    className={`text-[11px] whitespace-pre-wrap font-mono ${
                      line.type === "added"
                        ? "text-green-300"
                        : line.type === "removed"
                          ? "text-red-300"
                          : "text-text-secondary"
                    }`}
                  >
                    {line.type === "added"
                      ? "+ "
                      : line.type === "removed"
                        ? "- "
                        : "  "}
                    {line.line ? `${line.line}: ` : ""}
                    {line.content}
                  </pre>
                ))}
              </div>
            ) : (
              <p className="text-[11px] text-text-secondary">
                No line-level diff available.
              </p>
            )}
          </section>
        </>
      )}
    </div>
  );
}

function SimilarityPane({ tab }: { tab: SimilarityMainPaneTab }) {
  return (
    <div className="h-full overflow-auto p-4">
      <section className="rounded-md border border-separator/60 bg-pane/50 p-3">
        <p className="text-[11px] text-text-secondary uppercase tracking-wider">
          Similarity Analysis
        </p>
        <div className="mt-2 text-[12px] text-text-primary space-y-1">
          <p>
            <span className="text-text-secondary">Left submission:</span>{" "}
            {tab.payload.leftSubmissionID ?? "Unselected"}
          </p>
          <p>
            <span className="text-text-secondary">Right submission:</span>{" "}
            {tab.payload.rightSubmissionID ?? "Unselected"}
          </p>
          <p>{tab.payload.context}</p>
        </div>
      </section>
    </div>
  );
}

function AIPane({ tab }: { tab: AIMainPaneTab }) {
  return (
    <div className="h-full overflow-auto p-4">
      <section className="rounded-md border border-separator/60 bg-pane/50 p-3">
        <p className="text-[11px] text-text-secondary uppercase tracking-wider">
          AI Analysis
        </p>
        <div className="mt-2 text-[12px] text-text-primary space-y-1">
          <p>
            <span className="text-text-secondary">Submission:</span>{" "}
            {tab.payload.submissionID ?? "Unselected"}
          </p>
          <p>{tab.payload.context}</p>
        </div>
      </section>
    </div>
  );
}
