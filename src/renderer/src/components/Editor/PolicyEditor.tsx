import { useEffect, useMemo, useState } from "react";
import {
  MdAdd,
  MdExpandLess,
  MdExpandMore,
  MdFolderOpen,
  MdDeleteOutline,
} from "react-icons/md";
import { useAppStore } from "../../stores/appStore";
import type { PolicyDraft } from "../../types/policy";

type FileFieldKind = "single" | "multiple";
type ImportTarget = "expected-output" | "library-files" | "test-files";

export function PolicyEditor() {
  const draft = useAppStore((s) => s.selectedPolicyDraft);
  const workspaceRootPath = useAppStore((s) => s.workspaceRootPath);
  const updateDraft = useAppStore((s) => s.updatePolicyDraft);
  const savePolicy = useAppStore((s) => s.savePolicy);
  const addTestCase = useAppStore((s) => s.addTestCase);
  const removeTestCase = useAppStore((s) => s.removeTestCase);
  const updateTestCase = useAppStore((s) => s.updateTestCase);
  const selectedTestCaseID = useAppStore((s) => s.selectedPolicyTestCaseID);
  const selectedPolicyID = useAppStore((s) => s.selectedPolicyID);
  const policyBanner = useAppStore((s) => s.policyBanner);
  const isPolicyDirty = useAppStore((s) => s.isPolicyDirty);

  const [compileOpen, setCompileOpen] = useState(false);
  const [supportFilesOpen, setSupportFilesOpen] = useState(false);
  const [testCasesOpen, setTestCasesOpen] = useState(false);

  useEffect(() => {
    setCompileOpen(false);
    setSupportFilesOpen(false);
    setTestCasesOpen(false);
  }, [selectedPolicyID]);

  if (!draft) {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-sm text-text-secondary/70">
          Select a policy to edit.
        </p>
      </div>
    );
  }

  const setField = <K extends keyof PolicyDraft>(
    key: K,
    value: PolicyDraft[K],
  ) => {
    updateDraft({ ...draft, [key]: value });
  };

  const selectedTC = draft.testCases.find((tc) => tc.id === selectedTestCaseID);

  const canImportFiles = Boolean(workspaceRootPath);

  const importFiles = async (
    target: ImportTarget,
    field: "libraryFiles" | "testFiles" | null,
    mode: FileFieldKind,
    currentValues: string[],
    onSingleSelect?: (value: string) => void,
  ) => {
    if (!workspaceRootPath) return;

    const picked = await window.api.openFiles(
      target === "expected-output"
        ? "Select Expected Output File"
        : target === "library-files"
          ? "Select Library Files"
          : "Select Test Files",
    );

    if (!picked.length) return;

    const imported = await window.api.importFiles(
      workspaceRootPath,
      target,
      picked,
    );
    const values = Array.isArray(imported)
      ? imported
      : picked.map((pickedPath: string) => {
          const name = pickedPath.split("/").pop() || pickedPath;
          return `.autoscan/${target}/${name}`;
        });

    if (mode === "single") {
      onSingleSelect?.(values[0] ?? "");
      return;
    }

    if (!field) return;

    const nextValues = Array.from(new Set([...currentValues, ...values]));
    setField(field, nextValues as PolicyDraft[typeof field]);
  };

  return (
    <div className="h-full overflow-y-auto p-4 space-y-4">
      {policyBanner && (
        <div
          className={`
            rounded-md px-3 py-2 text-[12px] font-medium
            ${policyBanner.kind === "success" ? "bg-banner-success text-green-200" : ""}
            ${policyBanner.kind === "error" ? "bg-banner-error text-red-200" : ""}
            ${policyBanner.kind === "info" ? "bg-banner-info text-blue-200" : ""}
          `}
        >
          {policyBanner.message}
        </div>
      )}

      <CollapsibleSection
        title="Compile"
        open={compileOpen}
        onToggle={() => setCompileOpen((v) => !v)}
      >
        <div className="grid grid-cols-2 gap-3">
          <LabeledInput
            label="Source file"
            value={draft.sourceFile}
            onChange={(v) => setField("sourceFile", v)}
            placeholder="main.c"
          />
          <LabeledInput
            label="Flags"
            value={draft.flags.join(" ")}
            onChange={(v) => setField("flags", v.split(/\s+/).filter(Boolean))}
            placeholder="-Wall -Wextra"
          />
        </div>
      </CollapsibleSection>

      <CollapsibleSection
        title="Support Files"
        open={supportFilesOpen}
        onToggle={() => setSupportFilesOpen((v) => !v)}
      >
        <div className="space-y-4">
          <FilePickerField
            label="Library files"
            values={draft.libraryFiles}
            emptyLabel="No library files imported."
            buttonLabel="Import library files"
            disabled={!canImportFiles}
            onImport={() =>
              importFiles(
                "library-files",
                "libraryFiles",
                "multiple",
                draft.libraryFiles,
              )
            }
            onRemove={(index) =>
              setField(
                "libraryFiles",
                draft.libraryFiles.filter((_, i) => i !== index),
              )
            }
          />

          <FilePickerField
            label="Test files"
            values={draft.testFiles}
            emptyLabel="No test files imported."
            buttonLabel="Import test files"
            disabled={!canImportFiles}
            onImport={() =>
              importFiles(
                "test-files",
                "testFiles",
                "multiple",
                draft.testFiles,
              )
            }
            onRemove={(index) =>
              setField(
                "testFiles",
                draft.testFiles.filter((_, i) => i !== index),
              )
            }
          />
        </div>
      </CollapsibleSection>

      <CollapsibleSection
        title="Test Cases"
        open={testCasesOpen}
        onToggle={() => setTestCasesOpen((v) => !v)}
      >
        <div className="mb-3 flex flex-wrap gap-2">
          {draft.testCases.map((tc) => (
            <button
              key={tc.id}
              onClick={() =>
                useAppStore.setState({ selectedPolicyTestCaseID: tc.id })
              }
              className={`
                h-9 rounded-md border px-3 text-[12px] font-medium cursor-default
                ${
                  tc.id === selectedTestCaseID
                    ? "border-accent bg-accent text-white"
                    : "border-separator bg-canvas/60 text-text-primary hover:bg-hover/70"
                }
              `}
            >
              {tc.name || "Untitled"}
            </button>
          ))}
          <button
            onClick={addTestCase}
            className="inline-flex h-9 items-center gap-1.5 rounded-md border border-separator bg-canvas/60 px-3 text-[12px] text-text-primary hover:bg-hover/70 cursor-default"
          >
            <MdAdd size={14} />
            Add
          </button>
        </div>

        {selectedTC && (
          <div className="space-y-4 rounded-lg border border-separator bg-pane/35 p-4">
            <div className="flex items-center justify-between gap-3">
              <span className="text-[11px] font-semibold uppercase tracking-wider text-text-primary/90">
                {selectedTC.name || "Untitled Test"}
              </span>
              {draft.testCases.length > 1 && (
                <button
                  onClick={() => removeTestCase(selectedTC.id)}
                  className="inline-flex items-center gap-1 text-[10px] text-text-primary hover:text-red-400"
                >
                  <MdDeleteOutline size={14} />
                  Remove
                </button>
              )}
            </div>

            <div className="grid grid-cols-1 gap-3">
              <LabeledInput
                label="Name"
                value={selectedTC.name}
                onChange={(v) => updateTestCase(selectedTC.id, { name: v })}
              />
              <LabeledInput
                label="Arguments"
                value={selectedTC.args.join(" ")}
                onChange={(v) =>
                  updateTestCase(selectedTC.id, {
                    args: v.split(/\s+/).filter(Boolean),
                  })
                }
                placeholder="arg1 arg2"
              />
              <LabeledInput
                label="Stdin input"
                value={selectedTC.input}
                onChange={(v) => updateTestCase(selectedTC.id, { input: v })}
              />
            </div>

            <div className="grid grid-cols-[140px_minmax(0,1fr)] gap-3 items-end">
              <LabeledInput
                label="Expected exit code"
                value={selectedTC.expectedExit}
                onChange={(v) =>
                  updateTestCase(selectedTC.id, { expectedExit: v })
                }
                placeholder="0"
              />
              <CompactSingleFilePickerField
                label="Expected output file"
                value={selectedTC.expectedOutputFile}
                emptyLabel="No expected output file selected."
                buttonLabel="Import expected output"
                disabled={!canImportFiles}
                onImport={() =>
                  importFiles("expected-output", null, "single", [], (value) =>
                    updateTestCase(selectedTC.id, {
                      expectedOutputFile: value,
                    }),
                  )
                }
                onClear={() =>
                  updateTestCase(selectedTC.id, { expectedOutputFile: "" })
                }
              />
            </div>
          </div>
        )}
      </CollapsibleSection>

      <div className="pt-1">
        <button
          onClick={savePolicy}
          disabled={!isPolicyDirty}
          className={`
            px-4 py-1.5 rounded-md text-[12px] font-semibold cursor-default
            ${
              isPolicyDirty
                ? "bg-accent text-white hover:bg-accent-hover"
                : "bg-hover text-text-secondary"
            }
          `}
        >
          Save Policy
        </button>
      </div>
    </div>
  );
}

function CollapsibleSection({
  title,
  open,
  onToggle,
  children,
}: {
  title: string;
  open: boolean;
  onToggle: () => void;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-lg border border-separator bg-pane/30 overflow-hidden">
      <button
        onClick={onToggle}
        className="flex w-full items-center justify-between px-3 py-2.5 text-left cursor-default hover:bg-hover/40"
      >
        <span className="text-[11px] font-semibold text-text-primary uppercase tracking-wider">
          {title}
        </span>
        <span className="text-text-primary">
          {open ? <MdExpandLess size={18} /> : <MdExpandMore size={18} />}
        </span>
      </button>
      {open && (
        <div className="border-t border-separator p-3">{children}</div>
      )}
    </section>
  );
}

function Input({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full bg-canvas rounded-md px-2.5 py-1.5 text-[12px] text-text-primary outline-none border border-separator focus:border-accent"
    />
  );
}

function LabeledInput({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <div>
      <label className="mb-1.5 block text-[11px] font-medium text-text-primary/90">
        {label}
      </label>
      <Input value={value} onChange={onChange} placeholder={placeholder} />
    </div>
  );
}

function FilePickerField({
  label,
  values,
  emptyLabel,
  buttonLabel,
  disabled,
  onImport,
  onRemove,
}: {
  label: string;
  values: string[];
  emptyLabel: string;
  buttonLabel: string;
  disabled: boolean;
  onImport: () => void;
  onRemove: (index: number) => void;
}) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-3">
        <label className="block text-[11px] font-medium text-text-primary/90">
          {label}
        </label>
        <button
          onClick={onImport}
          disabled={disabled}
          className={`
            inline-flex items-center gap-1 rounded-md border px-2.5 py-1.5 text-[11px] cursor-default
            ${disabled ? "border-separator bg-canvas/50 text-text-secondary/60" : "border-separator bg-canvas/70 text-text-primary hover:bg-hover/70"}
          `}
        >
          <MdFolderOpen size={14} />
          {buttonLabel}
        </button>
      </div>

      {values.length === 0 ? (
        <div className="rounded-md border border-separator bg-canvas/35 px-3 py-2.5 text-[11px] text-text-secondary">
          {emptyLabel}
        </div>
      ) : (
        <div className="space-y-1.5">
          {values.map((value, index) => (
            <div
              key={`${value}-${index}`}
              className="flex items-center gap-2 rounded-md border border-separator bg-canvas/60 px-2.5 py-2"
            >
              <span className="min-w-0 flex-1 truncate text-[12px] text-text-primary">
                {value}
              </span>
              <button
                onClick={() => onRemove(index)}
                className="text-text-secondary hover:text-red-400 cursor-default"
              >
                <MdDeleteOutline size={16} />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function CompactSingleFilePickerField({
  label,
  value,
  emptyLabel,
  buttonLabel,
  disabled,
  onImport,
  onClear,
}: {
  label: string;
  value: string;
  emptyLabel: string;
  buttonLabel: string;
  disabled: boolean;
  onImport: () => void;
  onClear: () => void;
}) {
  const hasValue = useMemo(() => Boolean(value.trim()), [value]);

  return (
    <div>
      <div className="mb-1.5 block text-[11px] font-medium text-text-primary/90">
        {label}
      </div>
      <div className="flex h-9 items-center gap-2">
        <div className="min-w-0 flex-1">
          {hasValue ? (
            <div className="flex h-9 items-center gap-2 rounded-md border border-separator bg-canvas/60 px-2.5">
              <span className="min-w-0 flex-1 truncate text-[12px] text-text-primary">
                {value}
              </span>
              <button
                onClick={onClear}
                className="text-text-secondary hover:text-red-400 cursor-default"
              >
                <MdDeleteOutline size={16} />
              </button>
            </div>
          ) : (
            <div className="flex h-9 items-center rounded-md border border-separator bg-canvas/35 px-3 text-[11px] text-text-secondary">
              {emptyLabel}
            </div>
          )}
        </div>

        <button
          onClick={onImport}
          disabled={disabled}
          className={`
            inline-flex h-9 shrink-0 items-center gap-1 rounded-md border px-3 text-[11px] cursor-default
            ${disabled ? "border-separator bg-canvas/50 text-text-secondary/60" : "border-separator bg-canvas/70 text-text-primary hover:bg-hover/70"}
          `}
        >
          <MdFolderOpen size={14} />
          {buttonLabel}
        </button>
      </div>
    </div>
  );
}
