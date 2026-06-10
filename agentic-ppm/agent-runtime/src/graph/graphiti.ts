/**
 * Graphiti temporal-memory client (via the Graphiti MCP server).
 *
 * Decision: integrate Graphiti through its official MCP server rather than a
 * bespoke Python service. Graphiti layers ON TOP of FalkorDB (it uses the same
 * graph as its backend) and uses an LLM to extract entities/edges from each
 * episode, giving the agent temporal recall ("what changed, when").
 *
 * This runtime is an MCP *client*: it calls the server's `add_memory` tool to
 * record episodes. Graphiti is augmentation, not the Quick-slice critical path,
 * so every failure degrades to a log and the pipeline keeps running on FalkorDB.
 *
 * Configure GRAPHITI_MCP_URL to enable it (e.g. http://graphiti-mcp:8000/sse).
 */
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { SSEClientTransport } from '@modelcontextprotocol/sdk/client/sse.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { config } from '../config.js';

export interface GraphitiEpisode {
  /** Free-text description of what happened, e.g. "WP 1234 moved to At Risk". */
  content: string;
  /** Source system, e.g. "openproject". */
  source: string;
  /** When the event occurred (defaults to now). */
  occurredAt?: Date;
  /** Arbitrary structured payload merged into the episode body. */
  metadata?: Record<string, unknown>;
}

class GraphitiClient {
  private client: Client | null = null;
  private connecting: Promise<Client | null> | null = null;
  /** Once true, we stop retrying for this process to avoid log spam. */
  private disabled = false;

  private async connect(): Promise<Client | null> {
    if (this.disabled || !config.graphiti.mcpUrl) return null;
    if (this.client) return this.client;
    if (this.connecting) return this.connecting;

    this.connecting = (async () => {
      try {
        const url = new URL(config.graphiti.mcpUrl!);
        const transport =
          config.graphiti.transport === 'http'
            ? new StreamableHTTPClientTransport(url)
            : new SSEClientTransport(url);

        const client = new Client(
          { name: 'agentic-ppm-agent-runtime', version: '0.1.0' },
          { capabilities: {} },
        );
        await client.connect(transport);
        this.client = client;
        console.log(`[graphiti] connected to MCP server at ${config.graphiti.mcpUrl}`);
        return client;
      } catch (err: any) {
        console.warn(`[graphiti] MCP connect failed (${err.message}); disabling for this process`);
        this.disabled = true;
        return null;
      } finally {
        this.connecting = null;
      }
    })();

    return this.connecting;
  }

  async recordEpisode(episode: GraphitiEpisode): Promise<void> {
    const client = await this.connect();
    if (!client) {
      if (config.logLevel === 'debug') {
        console.log(`[graphiti:offline] ${episode.source}: ${episode.content}`);
      }
      return;
    }

    // Fold structured metadata into the episode body so Graphiti can extract it.
    const body = episode.metadata
      ? `${episode.content}\n\n${JSON.stringify(episode.metadata)}`
      : episode.content;

    try {
      await client.callTool({
        name: config.graphiti.addMemoryTool,
        arguments: {
          name: episode.content.slice(0, 80),
          episode_body: body,
          group_id: config.graphiti.groupId,
          source: 'text',
          source_description: episode.source,
        },
      });
    } catch (err: any) {
      console.warn(`[graphiti] add_memory failed: ${err.message}`);
    }
  }

  async close(): Promise<void> {
    await this.client?.close();
    this.client = null;
  }

  /** Connectivity check for the preflight CLI. */
  async ping(): Promise<{ enabled: boolean; ok: boolean; tools?: string[]; error?: string }> {
    if (!config.graphiti.mcpUrl) return { enabled: false, ok: false };
    // Reset any prior "disabled" latch so preflight always re-attempts.
    this.disabled = false;
    this.client = null;
    const client = await this.connect();
    if (!client) return { enabled: true, ok: false, error: 'connect failed (see log)' };
    try {
      const { tools } = await client.listTools();
      return { enabled: true, ok: true, tools: tools.map((t) => t.name) };
    } catch (err: any) {
      return { enabled: true, ok: false, error: err.message };
    }
  }
}

const singleton = new GraphitiClient();

export function recordEpisode(episode: GraphitiEpisode): Promise<void> {
  return singleton.recordEpisode(episode);
}

export function closeGraphiti(): Promise<void> {
  return singleton.close();
}

export function pingGraphiti() {
  return singleton.ping();
}
