export interface BridgeSubmissionPayload {
  id: string;
  path: string;
  c_files: string[];
}

export interface BridgeDiscoveryPayload {
  submission_count: number;
  submissions: BridgeSubmissionPayload[];
}

export interface BridgeCompilePayload {
  submission_id: string;
  ok: boolean;
  exit_code: number;
  timed_out: boolean;
  duration_ms: number;
  stdout?: string;
  stderr?: string;
}

export interface BridgeScanPayload {
  submission_id: string;
  hits?: BridgeBannedHitPayload[];
  parse_errors?: string[];
}

export interface BridgeBannedHitPayload {
  function: string;
  file: string;
  line?: number;
  column?: number;
  snippet?: string;
}

export interface BridgeDiffLinePayload {
  type: "same" | "added" | "removed";
  content: string;
  line_num?: number;
}

export type BridgeTestCaseStatus =
  | "running"
  | "pass"
  | "fail"
  | "timeout"
  | "compile_failed"
  | "error";

export interface BridgeTestCaseStartedPayload {
  submission_id: string;
  test_case_index: number;
  test_case_name: string;
}

export interface BridgeTestCaseCompletePayload {
  submission_id: string;
  index: number;
  name: string;
  status: BridgeTestCaseStatus;
  exit_code: number;
  duration_ms: number;
  stdout?: string;
  stderr?: string;
  output_match?: "none" | "pass" | "fail" | "missing";
  expected_output?: string;
  actual_output?: string;
  diff_lines?: BridgeDiffLinePayload[];
  message?: string;
}

export interface BridgeTestsCompletePayload {
  submission_id: string;
  total: number;
  passed: number;
  failed: number;
  compile_failed: number;
  missing_expected_output: number;
}

export interface BridgeCapabilities {
  run_session: boolean;
  run_test_case: boolean;
  diff_payload: boolean;
}

export interface BridgeRunSummary {
  policy_name: string;
  root: string;
  started_at: string;
  finished_at: string;
  duration_ms: number;
  total_submissions: number;
  compile_pass: number;
  compile_fail: number;
  compile_timeout: number;
  clean_submissions: number;
  submissions_with_banned: number;
  banned_hits_total: number;
  top_banned_functions: Record<string, number>;
}

export interface BridgeRunSubmissionResult {
  submission: BridgeSubmissionPayload;
  compile: {
    ok: boolean;
    command?: string[];
    exit_code: number;
    stdout?: string;
    stderr?: string;
    duration_ms: number;
    timed_out: boolean;
  };
  scan: {
    hits?: BridgeBannedHitPayload[];
    parse_errors?: string[];
  };
  status:
    | "pending"
    | "running"
    | "clean"
    | "banned"
    | "failed"
    | "timed_out"
    | "error";
}

export interface BridgeRunPayload {
  policy_name: string;
  root: string;
  started_at: string;
  finished_at: string;
  results: BridgeRunSubmissionResult[];
  summary: BridgeRunSummary;
}

export interface SubmissionCompileResult {
  submissionId: string;
  ok: boolean;
  exitCode: number;
  timedOut: boolean;
  durationMs: number;
  stdout?: string;
  stderr?: string;
}

export interface SubmissionScanResult {
  submissionId: string;
  bannedHits: number;
  parseErrors: string[];
}

export interface SubmissionResult {
  id: string;
  submissionPath: string;
  status:
    | "pending"
    | "running"
    | "clean"
    | "banned"
    | "failed"
    | "timed_out"
    | "error";
  cFiles: string[];
  compileOk: boolean;
  compileStatus: "pass" | "fail" | "timeout";
  compileTimeout: boolean;
  exitCode: number | null;
  compileTimeMs: number;
  stderr: string;
  bannedHitCount: number;
  bannedHits: BannedHit[];
}

export interface BannedHit {
  functionName: string;
  filePath: string;
  line: number | null;
  column: number | null;
  snippet: string;
}

export interface RunSummary {
  policyName: string;
  root: string;
  startedAt: string;
  finishedAt: string;
  durationMs: number;
  totalSubmissions: number;
  compilePass: number;
  compileFail: number;
  compileTimeout: number;
  cleanSubmissions: number;
  submissionsWithBanned: number;
  bannedHits: number;
  topBannedFunctions: Record<string, number>;
}

export interface EngineRunReport {
  summary: RunSummary;
  submissions: SubmissionResult[];
}

export type EngineRunEvent =
  | { type: "started"; message: string }
  | { type: "version"; version?: string; message?: string }
  | {
      type: "discovery_complete";
      discovery: BridgeDiscoveryPayload;
    }
  | {
      type: "compile_complete";
      compile: BridgeCompilePayload;
    }
  | {
      type: "scan_complete";
      scan: BridgeScanPayload;
    }
  | {
      type: "run_complete";
      run: BridgeRunPayload;
    }
  | {
      type: "test_case_started";
      test_case_started: BridgeTestCaseStartedPayload;
    }
  | {
      type: "test_case_complete";
      test_case: BridgeTestCaseCompletePayload;
    }
  | {
      type: "tests_complete";
      tests_complete: BridgeTestsCompletePayload;
    }
  | { type: "error"; message: string };
