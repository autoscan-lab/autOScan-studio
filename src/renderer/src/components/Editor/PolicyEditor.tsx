import { useAppStore } from '../../stores/appStore'
import type { PolicyDraft } from '../../types/policy'

export function PolicyEditor() {
  const draft = useAppStore((s) => s.selectedPolicyDraft)
  const updateDraft = useAppStore((s) => s.updatePolicyDraft)
  const savePolicy = useAppStore((s) => s.savePolicy)
  const addTestCase = useAppStore((s) => s.addTestCase)
  const removeTestCase = useAppStore((s) => s.removeTestCase)
  const updateTestCase = useAppStore((s) => s.updateTestCase)
  const selectedTestCaseID = useAppStore((s) => s.selectedPolicyTestCaseID)
  const policyBanner = useAppStore((s) => s.policyBanner)
  const isPolicyDirty = useAppStore((s) => s.isPolicyDirty)

  if (!draft) {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-sm text-text-secondary/70">Select a policy to edit.</p>
      </div>
    )
  }

  const setField = <K extends keyof PolicyDraft>(key: K, value: PolicyDraft[K]) => {
    updateDraft({ ...draft, [key]: value })
  }

  const selectedTC = draft.testCases.find((tc) => tc.id === selectedTestCaseID)

  return (
    <div className="h-full overflow-y-auto p-4 space-y-5">
      {/* Banner */}
      {policyBanner && (
        <div
          className={`
            rounded-md px-3 py-2 text-[12px] font-medium
            ${policyBanner.kind === 'success' ? 'bg-banner-success text-green-200' : ''}
            ${policyBanner.kind === 'error' ? 'bg-banner-error text-red-200' : ''}
            ${policyBanner.kind === 'info' ? 'bg-banner-info text-blue-200' : ''}
          `}
        >
          {policyBanner.message}
        </div>
      )}

      {/* Name */}
      <Section title="Policy Name">
        <Input
          value={draft.name}
          onChange={(v) => setField('name', v)}
          placeholder="e.g. Lab 1"
        />
      </Section>

      {/* Compile */}
      <Section title="Compile">
        <div className="grid grid-cols-2 gap-3">
          <LabeledInput
            label="Compiler"
            value={draft.gcc}
            onChange={(v) => setField('gcc', v)}
          />
          <LabeledInput
            label="Source file"
            value={draft.sourceFile}
            onChange={(v) => setField('sourceFile', v)}
            placeholder="main.c"
          />
        </div>
        <LabeledInput
          label="Flags"
          value={draft.flags.join(' ')}
          onChange={(v) => setField('flags', v.split(/\s+/).filter(Boolean))}
          placeholder="-Wall -Wextra"
        />
      </Section>

      {/* Test Cases */}
      <Section title="Test Cases">
        <div className="flex flex-wrap gap-1.5 mb-3">
          {draft.testCases.map((tc) => (
            <button
              key={tc.id}
              onClick={() => useAppStore.setState({ selectedPolicyTestCaseID: tc.id })}
              className={`
                px-2.5 py-1 rounded text-[11px] font-medium cursor-default
                ${tc.id === selectedTestCaseID
                  ? 'bg-accent text-white'
                  : 'bg-hover text-text-secondary hover:text-text-primary'}
              `}
            >
              {tc.name || 'Untitled'}
            </button>
          ))}
          <button
            onClick={addTestCase}
            className="px-2.5 py-1 rounded text-[11px] text-text-secondary hover:text-text-primary bg-hover cursor-default"
          >
            +
          </button>
        </div>

        {selectedTC && (
          <div className="space-y-3 p-3 rounded-lg bg-canvas/50 border border-separator/50">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-semibold text-text-secondary uppercase tracking-wider">
                {selectedTC.name || 'Untitled Test'}
              </span>
              {draft.testCases.length > 1 && (
                <button
                  onClick={() => removeTestCase(selectedTC.id)}
                  className="text-[10px] text-text-secondary hover:text-red-400"
                >
                  Remove
                </button>
              )}
            </div>

            <LabeledInput
              label="Name"
              value={selectedTC.name}
              onChange={(v) => updateTestCase(selectedTC.id, { name: v })}
            />
            <LabeledInput
              label="Arguments"
              value={selectedTC.args.join(' ')}
              onChange={(v) =>
                updateTestCase(selectedTC.id, { args: v.split(/\s+/).filter(Boolean) })
              }
              placeholder="arg1 arg2"
            />
            <LabeledInput
              label="Stdin input"
              value={selectedTC.input}
              onChange={(v) => updateTestCase(selectedTC.id, { input: v })}
            />
            <div className="grid grid-cols-2 gap-3">
              <LabeledInput
                label="Expected exit code"
                value={selectedTC.expectedExit}
                onChange={(v) => updateTestCase(selectedTC.id, { expectedExit: v })}
                placeholder="0"
              />
              <LabeledInput
                label="Expected output file"
                value={selectedTC.expectedOutputFile}
                onChange={(v) => updateTestCase(selectedTC.id, { expectedOutputFile: v })}
              />
            </div>
          </div>
        )}
      </Section>

      {/* Library & Test Files */}
      <Section title="Library Files">
        <TagInput
          values={draft.libraryFiles}
          onChange={(v) => setField('libraryFiles', v)}
          placeholder="Add library file…"
        />
      </Section>

      <Section title="Test Files">
        <TagInput
          values={draft.testFiles}
          onChange={(v) => setField('testFiles', v)}
          placeholder="Add test file…"
        />
      </Section>

      {/* Save */}
      <div className="pt-2">
        <button
          onClick={savePolicy}
          disabled={!isPolicyDirty}
          className={`
            px-4 py-1.5 rounded-md text-[12px] font-semibold cursor-default
            ${isPolicyDirty
              ? 'bg-accent text-white hover:bg-accent-hover'
              : 'bg-hover text-text-secondary'}
          `}
        >
          Save Policy
        </button>
      </div>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h3 className="text-[11px] font-semibold text-text-secondary uppercase tracking-wider mb-2">
        {title}
      </h3>
      {children}
    </div>
  )
}

function Input({
  value,
  onChange,
  placeholder
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full bg-canvas rounded px-2.5 py-1.5 text-[12px] text-text-primary outline-none border border-separator focus:border-accent"
    />
  )
}

function LabeledInput({
  label,
  value,
  onChange,
  placeholder
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <div>
      <label className="block text-[10px] text-text-secondary mb-1">{label}</label>
      <Input value={value} onChange={onChange} placeholder={placeholder} />
    </div>
  )
}

function TagInput({
  values,
  onChange,
  placeholder
}: {
  values: string[]
  onChange: (v: string[]) => void
  placeholder: string
}) {
  return (
    <div>
      <div className="flex flex-wrap gap-1.5 mb-2">
        {values.map((v, i) => (
          <span
            key={i}
            className="flex items-center gap-1 bg-hover rounded px-2 py-0.5 text-[11px] text-text-secondary"
          >
            {v}
            <button
              onClick={() => onChange(values.filter((_, j) => j !== i))}
              className="text-text-secondary hover:text-red-400 text-[10px]"
            >
              ✕
            </button>
          </span>
        ))}
      </div>
      <input
        placeholder={placeholder}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            const val = (e.target as HTMLInputElement).value.trim()
            if (val) {
              onChange([...values, val])
              ;(e.target as HTMLInputElement).value = ''
            }
          }
        }}
        className="w-full bg-canvas rounded px-2.5 py-1.5 text-[12px] text-text-primary outline-none border border-separator focus:border-accent"
      />
    </div>
  )
}
