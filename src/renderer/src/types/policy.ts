export interface PolicyFile {
  id: string
  name: string
  path: string
}

export interface TestCase {
  id: string
  name: string
  args: string[]
  input: string
  expectedExit: string
  expectedOutputFile: string
}

export interface PolicyDraft {
  name: string
  gcc: string
  flags: string[]
  sourceFile: string
  libraryFiles: string[]
  testFiles: string[]
  testCases: TestCase[]
}

export function createTestCase(overrides?: Partial<TestCase>): TestCase {
  return {
    id: crypto.randomUUID(),
    name: '',
    args: [],
    input: '',
    expectedExit: '',
    expectedOutputFile: '',
    ...overrides
  }
}

export function createStarterPolicy(name: string): PolicyDraft {
  return {
    name,
    gcc: 'gcc',
    flags: ['-Wall', '-Wextra'],
    sourceFile: 'main.c',
    libraryFiles: [],
    testFiles: [],
    testCases: [createTestCase({ name: 'No args', expectedExit: '0' })]
  }
}
