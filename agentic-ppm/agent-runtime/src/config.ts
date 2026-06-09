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
  logLevel: process.env.LOG_LEVEL ?? 'info',

  openproject: {
    baseUrl: process.env.OPENPROJECT_BASE_URL ?? 'http://localhost:8080',
    apiKey: process.env.OPENPROJECT_API_KEY ?? '',
    webhookSecret: process.env.OPENPROJECT_WEBHOOK_SECRET ?? '',
    alertsProject: process.env.OPENPROJECT_ALERTS_PROJECT ?? 'agent-alerts',
    /** Marker written to agent-created WPs so we can ignore our own webhook echoes. */
    syncSource: process.env.AGENT_SYNC_SOURCE ?? 'agentic-ppm',
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
} as const;

/** Throw early if anything needed to actually run the pipeline is missing. */
export function assertRuntimeConfig(): void {
  required('OPENPROJECT_API_KEY');
  required('ANTHROPIC_API_KEY');
}
