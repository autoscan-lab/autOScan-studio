export interface SubmissionCompileResult {
  submissionPath: string
  status: 'pass' | 'fail' | 'timeout'
  stderr: string
}

export interface SubmissionScanResult {
  submissionPath: string
  bannedHitCount: number
}

export interface SubmissionResult {
  submissionPath: string
  compileStatus: 'pass' | 'fail' | 'timeout'
  bannedHitCount: number
  exitCode: number | null
  stderr: string
}

export interface RunSummary {
  totalSubmissions: number
  compilePass: number
  compileFail: number
  compileTimeout: number
  cleanSubmissions: number
  bannedHits: number
}

export interface EngineRunReport {
  summary: RunSummary
  submissions: SubmissionResult[]
}

export type EngineRunEvent =
  | { type: 'started'; totalSubmissions: number }
  | { type: 'discovery_complete'; submissionCount: number }
  | { type: 'compile_complete'; results: SubmissionCompileResult[] }
  | { type: 'scan_complete'; results: SubmissionScanResult[] }
  | { type: 'run_complete'; report: EngineRunReport }
  | { type: 'error'; message: string }
