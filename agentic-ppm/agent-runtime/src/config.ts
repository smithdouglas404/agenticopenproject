/**
 * Central runtime configuration, read once from the environment.
 */
import dotenv from 'dotenv';

dotenv.config();

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 8745),
  /** When true, run the full dependency preflight report at boot (logs to stdout). */
  preflightOnBoot: process.env.PREFLIGHT_ON_BOOT === '1',
  /** When true, backfill the graph from OpenProject at boot (idempotent, runs in background). */
  runBackfillOnBoot: process.env.RUN_BACKFILL_ON_BOOT === '1',
  logLevel: process.env.LOG_LEVEL ?? 'info',

  openproject: {
    baseUrl: process.env.OPENPROJECT_BASE_URL ?? 'http://localhost:8080',
    apiKey: process.env.OPENPROJECT_API_KEY ?? '',
    webhookSecret: process.env.OPENPROJECT_WEBHOOK_SECRET ?? '',
    alertsProject: process.env.OPENPROJECT_ALERTS_PROJECT ?? 'agent-alerts',
    /** WP type used for Agent Alerts. Defaults to "Task" so it works on a stock instance. */
    alertType: process.env.OPENPROJECT_ALERT_TYPE ?? 'Task',
    /** Marker written to agent-created WPs so we can ignore our own webhook echoes. */
    syncSource: process.env.AGENT_SYNC_SOURCE ?? 'agentic-ppm',
    /** Optional custom-field API keys (e.g. "customField12"). Set only if they exist. */
    customFieldSyncSource: process.env.OPENPROJECT_CF_SYNC_SOURCE,
    customFieldAlertSeverity: process.env.OPENPROJECT_CF_ALERT_SEVERITY,
  },

  claude: {
    apiKey: process.env.ANTHROPIC_API_KEY ?? '',
    model: process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-6',
  },

  falkor: {
    host: process.env.FALKORDB_HOST ?? 'localhost',
    port: Number(process.env.FALKORDB_PORT ?? 6379),
    graph: process.env.FALKORDB_GRAPH ?? 'agentic_ppm',
    password: process.env.FALKORDB_PASSWORD,
  },

  detectors: {
    /** Periodic detector sweep interval in minutes (0 = disabled). */
    sweepMinutes: Number(process.env.DETECTOR_SWEEP_MINUTES ?? 60),
    /** Min minutes between event-triggered sweeps. */
    eventThrottleMinutes: Number(process.env.DETECTOR_EVENT_THROTTLE_MINUTES ?? 10),
    /** Publish new findings to OpenProject as Agent Alerts (else console-only). */
    publish: (process.env.DETECTOR_PUBLISH ?? '1') === '1',
  },

  console: {
    /** Optional bearer token guarding /console and /api when the service is public. */
    token: process.env.CONSOLE_TOKEN,
  },

  graphiti: {
    /** MCP server URL, e.g. http://graphiti-mcp:8000/sse. Unset = disabled. */
    mcpUrl: process.env.GRAPHITI_MCP_URL,
    /** MCP transport: 'sse' (default) or 'http' (streamable HTTP). */
    transport: (process.env.GRAPHITI_MCP_TRANSPORT ?? 'sse') as 'sse' | 'http',
    /** Namespace for episodes/entities; default to the FalkorDB graph name. */
    groupId: process.env.GRAPHITI_GROUP_ID ?? process.env.FALKORDB_GRAPH ?? 'agentic_ppm',
    /** Tool name on the Graphiti MCP server that ingests an episode. */
    addMemoryTool: process.env.GRAPHITI_ADD_MEMORY_TOOL ?? 'add_memory',
  },
} as const;

/** Throw early if anything needed to actually run the pipeline is missing. */
export function assertRuntimeConfig(): void {
  required('OPENPROJECT_API_KEY');
  required('ANTHROPIC_API_KEY');
}
