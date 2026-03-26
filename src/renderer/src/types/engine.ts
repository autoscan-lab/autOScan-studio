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
  banned_hits: number;
  parse_errors?: string[];
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
  id: string;
  path: string;
  status:
    | "pending"
    | "running"
    | "clean"
    | "banned"
    | "failed"
    | "timed_out"
    | "error";
  c_files: string[];
  compile_ok: boolean;
  compile_timeout: boolean;
  exit_code: number;
  compile_time_ms: number;
  stderr?: string;
  banned_count: number;
}

export interface BridgeRunPayload {
  summary: BridgeRunSummary;
  submissions: BridgeRunSubmissionResult[];
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
  | { type: "error"; message: string };
