import type { PolicyDraft, TestCase } from '../types/policy'
import { createTestCase } from '../types/policy'

function normalizeExpectedOutputRef(raw: string): string {
  const trimmed = raw.trim()
  if (!trimmed) return ''
  const normalized = trimmed.replace(/\\/g, '/')
  const segments = normalized.split('/').filter(Boolean)
  return segments.length > 0 ? segments[segments.length - 1] : trimmed
}

function yamlScalar(value: string): string {
  if (!value) return '""'
  if (/[:#\[\]{}&*!|>'"%@`,?]/.test(value) || value.includes('\n')) {
    const escaped = value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')
    return `"${escaped}"`
  }
  return value
}

function yamlArray(items: string[]): string {
  return '[' + items.map((i) => yamlScalar(i)).join(', ') + ']'
}

export function serializePolicy(draft: PolicyDraft): string {
  const lines: string[] = []
  lines.push(`name: ${yamlScalar(draft.name)}`)
  lines.push('compile:')
  lines.push(`  gcc: ${yamlScalar(draft.gcc || 'gcc')}`)
  lines.push('  flags:')

  const flags = draft.flags.length > 0 ? draft.flags : ['-Wall', '-Wextra']
  for (const flag of flags) {
    lines.push(`    - ${yamlScalar(flag)}`)
  }

  lines.push(`  source_file: ${yamlScalar(draft.sourceFile)}`)
  lines.push('run:')
  lines.push('  test_cases:')

  const testCases =
    draft.testCases.length > 0
      ? draft.testCases
      : [{ id: '', name: 'No args', args: [], input: '', expectedExit: '0', expectedOutputFile: '' }]

  for (const tc of testCases) {
    lines.push(`    - name: ${yamlScalar(tc.name)}`)
    if (tc.args.length > 0) {
      lines.push(`      args: ${yamlArray(tc.args)}`)
    }
    if (tc.input.trim()) {
      lines.push(`      input: ${yamlScalar(tc.input)}`)
    }
    if (tc.expectedExit.trim()) {
      lines.push(`      expected_exit: ${tc.expectedExit.trim()}`)
    }
    if (tc.expectedOutputFile.trim()) {
      lines.push(
        `      expected_output_file: ${yamlScalar(
          normalizeExpectedOutputRef(tc.expectedOutputFile),
        )}`,
      )
    }
  }

  if (draft.libraryFiles.length > 0) {
    lines.push('library_files:')
    for (const f of draft.libraryFiles) {
      lines.push(`  - ${yamlScalar(f)}`)
    }
  }

  if (draft.testFiles.length > 0) {
    lines.push('test_files:')
    for (const f of draft.testFiles) {
      lines.push(`  - ${yamlScalar(f)}`)
    }
  }

  return lines.join('\n') + '\n'
}

function parseYAMLScalar(raw: string): string {
  let s = raw.trim()
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.slice(1, -1)
  }
  return s
}

function parseScalarList(lines: string[], index: { value: number }, minIndent: number): string[] {
  const result: string[] = []
  while (index.value < lines.length) {
    const line = lines[index.value]
    const trimmed = line.trimStart()
    const indent = line.length - trimmed.length
    if (indent < minIndent || (!trimmed.startsWith('- ') && trimmed !== '')) break
    if (trimmed.startsWith('- ')) {
      result.push(parseYAMLScalar(trimmed.slice(2)))
      index.value++
    } else {
      break
    }
  }
  return result
}

export function parsePolicy(text: string): PolicyDraft {
  const lines = text.replace(/\r\n/g, '\n').split('\n')
  const draft: PolicyDraft = {
    name: '',
    gcc: 'gcc',
    flags: [],
    sourceFile: '',
    libraryFiles: [],
    testFiles: [],
    testCases: []
  }

  const idx = { value: 0 }

  while (idx.value < lines.length) {
    const line = lines[idx.value]
    const trimmed = line.trim()

    if (!trimmed || trimmed.startsWith('#')) {
      idx.value++
      continue
    }

    const indent = line.length - line.trimStart().length
    if (indent > 0) {
      idx.value++
      continue
    }

    if (trimmed.startsWith('name:')) {
      draft.name = parseYAMLScalar(trimmed.slice('name:'.length))
      idx.value++
      continue
    }

    if (trimmed === 'compile:') {
      idx.value++
      while (idx.value < lines.length) {
        const cl = lines[idx.value]
        const ct = cl.trim()
        const ci = cl.length - cl.trimStart().length
        if (ci < 2 && ct !== '') break
        if (ct.startsWith('gcc:')) {
          draft.gcc = parseYAMLScalar(ct.slice('gcc:'.length))
        } else if (ct.startsWith('source_file:')) {
          draft.sourceFile = parseYAMLScalar(ct.slice('source_file:'.length))
        } else if (ct === 'flags:') {
          idx.value++
          draft.flags = parseScalarList(lines, idx, 4)
          continue
        }
        idx.value++
      }
      continue
    }

    if (trimmed === 'run:') {
      idx.value++
      while (idx.value < lines.length) {
        const rl = lines[idx.value]
        const rt = rl.trim()
        const ri = rl.length - rl.trimStart().length
        if (ri < 2 && rt !== '') break
        if (rt === 'test_cases:') {
          idx.value++
          draft.testCases = parseTestCases(lines, idx)
          continue
        }
        idx.value++
      }
      continue
    }

    if (trimmed === 'library_files:') {
      idx.value++
      draft.libraryFiles = parseScalarList(lines, idx, 2)
      continue
    }

    if (trimmed === 'test_files:') {
      idx.value++
      draft.testFiles = parseScalarList(lines, idx, 2)
      continue
    }

    idx.value++
  }

  if (draft.testCases.length === 0) {
    draft.testCases = [createTestCase({ name: 'No args', expectedExit: '0' })]
  }

  return draft
}

function parseTestCases(lines: string[], idx: { value: number }): TestCase[] {
  const cases: TestCase[] = []

  while (idx.value < lines.length) {
    const line = lines[idx.value]
    const trimmed = line.trim()
    const indent = line.length - line.trimStart().length
    if (indent < 4 && trimmed !== '') break

    if (trimmed.startsWith('- name:')) {
      const tc = createTestCase({
        name: parseYAMLScalar(trimmed.slice('- name:'.length))
      })
      idx.value++

      while (idx.value < lines.length) {
        const tl = lines[idx.value]
        const tt = tl.trim()
        const ti = tl.length - tl.trimStart().length
        if (ti < 6 && tt !== '') break
        if (tt.startsWith('- ')) break

        if (tt.startsWith('args:')) {
          const argsRaw = tt.slice('args:'.length).trim()
          if (argsRaw.startsWith('[') && argsRaw.endsWith(']')) {
            tc.args = argsRaw
              .slice(1, -1)
              .split(',')
              .map((a) => parseYAMLScalar(a.trim()))
              .filter(Boolean)
          }
        } else if (tt.startsWith('input:')) {
          tc.input = parseYAMLScalar(tt.slice('input:'.length))
        } else if (tt.startsWith('expected_exit:')) {
          tc.expectedExit = tt.slice('expected_exit:'.length).trim()
        } else if (tt.startsWith('expected_output_file:')) {
          tc.expectedOutputFile = normalizeExpectedOutputRef(
            parseYAMLScalar(tt.slice('expected_output_file:'.length)),
          )
        }
        idx.value++
      }

      cases.push(tc)
    } else {
      idx.value++
    }
  }

  return cases
}
