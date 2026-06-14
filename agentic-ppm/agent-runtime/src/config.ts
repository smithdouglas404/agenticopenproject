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
    /** Open work items per assignee before CapacityOverload fires. */
    capacityThreshold: Number(process.env.CAPACITY_OVERLOAD_THRESHOLD ?? 10),
    /** Days without an update before a high-priority open item is stale (high at 2x). */
    staleHighPriorityDays: Number(process.env.STALE_HIGH_PRIORITY_DAYS ?? 14),
    /** Spent hours before CostBurnWithoutProgress fires on items with no estimate. */
    costBurnHoursThreshold: Number(process.env.COST_BURN_HOURS_THRESHOLD ?? 40),
  },

  rules: {
    /** Evaluate OpenProject-authored rules against the graph (master switch). */
    enabled: (process.env.RULES_ENABLED ?? '1') === '1',
    /** Where rules come from: the OpenProject module endpoint, or a local file/env. */
    source: (process.env.RULES_SOURCE ?? 'openproject') as 'openproject' | 'local',
    /** In-memory cache TTL for the rules endpoint (minutes). */
    refreshMinutes: Number(process.env.RULES_REFRESH_MINUTES ?? 5),
    /** Path to a JSON file of Rule[] when source === 'local' (else RULES_JSON env). */
    localFile: process.env.RULES_LOCAL_FILE,
    /** Shared secret sent as X-OP-Rules-Token to the module endpoints. */
    apiToken: process.env.RULES_API_TOKEN ?? '',
    /** Run rule evaluation as part of the periodic/event detector sweep. */
    evaluateOnSweep: (process.env.RULES_EVALUATE_ON_SWEEP ?? '1') === '1',
    /** Allow targeted rule evaluation from the webhook (changed-node path). */
    evaluateOnEvent: (process.env.RULES_EVALUATE_ON_EVENT ?? '1') === '1',
    /** Enable the GoRules ZEN decision core for kind:'decision' rules. */
    zenEnabled: (process.env.RULES_ZEN_ENABLED ?? '1') === '1',
  },

  grounding: {
    /** Downgrade published severity for agents with a poor resolved-prediction track record. */
    autoTuneSeverity: (process.env.LEARNING_AUTOTUNE ?? '1') === '1',
  },

  learning: {
    /** Record predictions and resolve them against actual outcomes (the learning loop). */
    enabled: (process.env.LEARNING_ENABLED ?? '1') === '1',
  },

  actions: {
    /** Execute concrete actions when a human approves a finding (HITL-gated). */
    enabled: (process.env.AGENT_ACTIONS ?? '1') === '1',
    /** WP type for agent-created follow-up tasks. */
    followupType: process.env.AGENT_FOLLOWUP_TYPE ?? 'Task',
    /** Write portfolio health to the OpenProject project status (Overview banner). */
    setProjectStatus: (process.env.AGENT_SET_PROJECT_STATUS ?? '1') === '1',
  },

  console: {
    /** Optional bearer token guarding /console and /api when the service is public. */
    token: process.env.CONSOLE_TOKEN,
  },

  memory: {
    /** Memory provider: falkor (default) | mem0 | none. */
    provider: (process.env.MEMORY_PROVIDER ?? 'falkor') as 'falkor' | 'mem0' | 'none',
    mem0ApiKey: process.env.MEM0_API_KEY,
    mem0BaseUrl: process.env.MEM0_BASE_URL ?? 'https://api.mem0.ai',
    mem0AgentId: process.env.MEM0_AGENT_ID ?? 'agentic-ppm',
  },

  mcp: {
    /**
     * MCP servers registered as mappable SOURCES (resources→objects, tools→
     * actions). Optional: none configured = no MCP adapters. Read from
     * MCP_SOURCES (comma-separated "url" or "url|transport") or a single
     * MCP_SERVER_URL. Transport defaults to MCP_DEFAULT_TRANSPORT (sse|http).
     */
    servers: parseMcpSources(),
  },
} as const;

/** Parse the optional MCP source list from the environment. */
function parseMcpSources(): { url: string; transport: 'sse' | 'http' }[] {
  const defaultTransport = (process.env.MCP_DEFAULT_TRANSPORT ?? 'sse') as 'sse' | 'http';
  const raw = process.env.MCP_SOURCES ?? process.env.MCP_SERVER_URL ?? '';
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .map((entry) => {
      // "url" or "url|transport".
      const [url, transport] = entry.split('|').map((p) => p.trim());
      return { url, transport: transport === 'http' ? 'http' : transport === 'sse' ? 'sse' : defaultTransport };
    });
}

/** Throw early if anything needed to actually run the pipeline is missing. */
export function assertRuntimeConfig(): void {
  required('OPENPROJECT_API_KEY');
}
