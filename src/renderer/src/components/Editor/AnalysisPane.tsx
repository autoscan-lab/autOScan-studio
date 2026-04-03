import type {
  AIMainPaneTab,
  DiffMainPaneTab,
  DiffLine,
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
  const hasExpectedOutput = tab.payload.expectedOutput !== null;
  const actualOutput = tab.payload.actualOutput ?? tab.payload.stdout ?? "";
  const stderr = tab.payload.stderr ?? "";
  const hasStderr = stderr.trim().length > 0;

  if (!hasExpectedOutput) {
    return (
      <div className="h-full overflow-auto">
        <div className="px-4 py-3 text-[12px] leading-5 whitespace-pre-wrap font-mono text-text-primary">
          <pre className="whitespace-pre-wrap font-mono">
            {actualOutput || "(empty)"}
          </pre>
          {hasStderr && (
            <>
              <div className="mt-4 text-text-secondary">stderr</div>
              <pre className="mt-1 whitespace-pre-wrap font-mono text-red-300">
                {stderr}
              </pre>
            </>
          )}
        </div>
      </div>
    );
  }

  const unifiedLines = buildDiffLines(
    tab.payload.expectedOutput ?? "",
    actualOutput,
    tab.payload.diffLines,
  );

  return (
    <div className="h-full overflow-auto">
      <div className="px-4 py-3 text-[12px] leading-5 whitespace-pre-wrap font-mono">
        <div>
          {unifiedLines.map((line, index) => (
            <div
              key={`${line.kind}-${index}`}
              className={
                line.kind === "added"
                    ? "bg-green-950/25 text-green-300"
                    : line.kind === "removed"
                      ? "bg-red-950/25 text-red-300"
                      : "text-text-primary"
              }
            >
              {line.text}
            </div>
          ))}
        </div>
        {hasStderr && (
          <>
            <div className="mt-4 text-text-secondary">stderr</div>
            <pre className="mt-1 whitespace-pre-wrap font-mono text-red-300">
              {stderr}
            </pre>
          </>
        )}
      </div>
    </div>
  );
}

type DiffDisplayLine = {
  kind: "same" | "added" | "removed";
  text: string;
};

function buildDiffLines(
  expected: string,
  actual: string,
  diffLines: DiffLine[] | null,
): DiffDisplayLine[] {
  const lines: DiffDisplayLine[] = [];
  if (diffLines && diffLines.length > 0) {
    for (const line of diffLines) {
      const kind =
        line.type === "added"
          ? "added"
          : line.type === "removed"
            ? "removed"
            : "same";
      const prefix = kind === "added" ? "+" : kind === "removed" ? "-" : " ";
      lines.push({ kind, text: `${prefix}${line.content}` });
    }
    return lines;
  }

  if (expected === actual) {
    const expectedLines = splitLines(expected);
    if (expectedLines.length === 0) {
      lines.push({ kind: "same", text: " " });
      return lines;
    }

    for (const content of expectedLines) {
      lines.push({ kind: "same", text: ` ${content}` });
    }
    return lines;
  }

  const expectedLines = splitLines(expected);
  const actualLines = splitLines(actual);

  for (const content of expectedLines) {
    lines.push({ kind: "removed", text: `-${content}` });
  }
  for (const content of actualLines) {
    lines.push({ kind: "added", text: `+${content}` });
  }

  if (expectedLines.length === 0 && actualLines.length === 0) {
    lines.push({ kind: "same", text: " " });
  }

  return lines;
}

function splitLines(value: string): string[] {
  if (!value) return [];
  return value.replace(/\r\n/g, "\n").split("\n");
}

function SimilarityPane({ tab }: { tab: SimilarityMainPaneTab }) {
  return (
    <div className="h-full overflow-auto p-4">
      <section className="rounded-md border border-separator bg-pane/50 p-3">
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
      <section className="rounded-md border border-separator bg-pane/50 p-3">
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
