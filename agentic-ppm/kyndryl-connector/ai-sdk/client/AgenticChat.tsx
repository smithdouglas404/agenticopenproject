/**
 * <AgenticChat/> — the agentic chat surface (Vercel AI SDK v5 generative UI).
 *
 * Streams from POST /api/agent-chat (see ../server/routes/agentChat.route.ts)
 * and renders the model's typed tool parts as widgets (./widgets.tsx):
 * text is the LLM explaining; every number on screen is structured tool output
 * from the runtime's computed endpoints — the model cannot alter it.
 *
 * DROP-IN:
 *   - Inside the existing ClarityChat page: render <AgenticChat/> as a tab or
 *     panel — it brings its own scroll container and input box.
 *   - Or standalone: add a route that renders <AgenticChat/> full-page, e.g.
 *       <Route path="/agent-chat" component={AgenticChat} />
 *
 * Install (client): npm i ai @ai-sdk/react
 * Requires Tailwind (already in the Kyndral client). No other UI deps.
 */
import { useState, type FormEvent } from "react";
import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport } from "ai";
import {
  FindingCard,
  MetricsGrid,
  ProjectStatusList,
  RosterList,
  SweepResult,
  TrackRecordList,
  type FindingView,
  type Metric,
  type ProjectStatusItem,
  type RosterAgentView,
  type SweepResultData,
  type TrackRecordEntry,
} from "./widgets";

// ── Tool output contracts (mirror ../server/tools.ts; keep in sync) ─────────

interface MetricsOutput {
  computedAt: string;
  metrics: Metric[];
  error?: string;
}
interface FindingsOutput {
  count: number;
  findings: FindingView[];
}
interface RosterOutput {
  agents: RosterAgentView[];
}
interface TrackRecordOutput {
  agents: TrackRecordEntry[];
}
interface ProjectStatusOutput {
  count: number;
  items: ProjectStatusItem[];
}
interface DecisionOutput {
  ok: boolean;
  findingId: string;
  decision: "approved" | "rejected";
  actionDetail?: string;
  followupWpId?: number;
  error?: string;
}

/** Structural view of a v5 tool UI part (type "tool-<name>"). */
interface ToolPartLike {
  type: string;
  state: "input-streaming" | "input-available" | "output-available" | "output-error";
  output?: unknown;
  errorText?: string;
}

const TOOL_LABELS: Record<string, string> = {
  "tool-getPortfolioMetrics": "Computing portfolio metrics…",
  "tool-getFindings": "Fetching findings…",
  "tool-getAgentRoster": "Loading agent roster…",
  "tool-getAgentTrackRecord": "Loading track records…",
  "tool-getProjectStatus": "Loading project status…",
  "tool-approveFinding": "Recording approval…",
  "tool-rejectFinding": "Recording rejection…",
  "tool-triggerSweep": "Running detector sweep…",
};

// ── Component ────────────────────────────────────────────────────────────────

export default function AgenticChat() {
  const [input, setInput] = useState("");
  const { messages, sendMessage, status, error } = useChat({
    transport: new DefaultChatTransport({ api: "/api/agent-chat" }),
  });
  const busy = status === "submitted" || status === "streaming";

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    const text = input.trim();
    if (!text || busy) return;
    setInput("");
    void sendMessage({ text });
  }

  return (
    <div className="flex h-full min-h-0 flex-col bg-zinc-50 dark:bg-zinc-950">
      <div className="flex-1 space-y-4 overflow-y-auto p-4">
        {messages.length === 0 && (
          <div className="mx-auto mt-10 max-w-md text-center text-sm text-zinc-400 dark:text-zinc-500">
            Ask about portfolio health, open findings, agent track records — or say
            “approve finding …” to act. Numbers are computed by the runtime, not generated.
          </div>
        )}

        {messages.map((message) => (
          <div key={message.id} className={message.role === "user" ? "flex justify-end" : ""}>
            <div
              className={
                message.role === "user"
                  ? "max-w-[80%] rounded-2xl rounded-br-sm bg-indigo-600 px-3 py-2 text-sm text-white"
                  : "max-w-full text-sm text-zinc-800 dark:text-zinc-200"
              }
            >
              {message.parts.map((part, i) => {
                if (part.type === "text") return <TextBlock key={i} text={part.text} />;
                if (part.type.startsWith("tool-")) {
                  return <ToolPart key={i} part={part as unknown as ToolPartLike} />;
                }
                return null;
              })}
            </div>
          </div>
        ))}

        {busy && (
          <div className="flex items-center gap-1.5 text-zinc-400 dark:text-zinc-500">
            <Dot delay="0ms" /> <Dot delay="150ms" /> <Dot delay="300ms" />
          </div>
        )}
        {error && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700 dark:border-red-900 dark:bg-red-950 dark:text-red-300">
            Chat error: {error.message}
          </div>
        )}
      </div>

      <form onSubmit={onSubmit} className="border-t border-zinc-200 p-3 dark:border-zinc-800">
        <div className="flex gap-2">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Ask the portfolio agents…"
            className="flex-1 rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 outline-none focus:border-indigo-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100"
          />
          <button
            type="submit"
            disabled={busy || input.trim().length === 0}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-40"
          >
            Send
          </button>
        </div>
      </form>
    </div>
  );
}

// ── Part renderers ───────────────────────────────────────────────────────────

/** Markdown-ish text: paragraphs + **bold** spans (dependency-free). */
function TextBlock({ text }: { text: string }) {
  const paragraphs = text.split(/\n{2,}/).filter((p) => p.trim().length > 0);
  return (
    <>
      {paragraphs.map((p, i) => (
        <p key={i} className="my-1.5 whitespace-pre-wrap leading-relaxed first:mt-0 last:mb-0">
          {renderBold(p)}
        </p>
      ))}
    </>
  );
}

function renderBold(text: string) {
  const segments = text.split(/(\*\*[^*]+\*\*)/g);
  return segments.map((seg, i) =>
    seg.startsWith("**") && seg.endsWith("**") ? (
      <strong key={i} className="font-semibold">
        {seg.slice(2, -2)}
      </strong>
    ) : (
      <span key={i}>{seg}</span>
    ),
  );
}

/** Maps a streamed tool part onto its widget once output is available. */
function ToolPart({ part }: { part: ToolPartLike }) {
  if (part.state === "output-error") {
    return (
      <div className="my-1.5 rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs text-red-700 dark:border-red-900 dark:bg-red-950 dark:text-red-300">
        {TOOL_LABELS[part.type] ?? part.type} failed: {part.errorText ?? "unknown error"}
      </div>
    );
  }
  if (part.state !== "output-available") {
    return (
      <div className="my-1.5 flex items-center gap-2 text-xs text-zinc-400 dark:text-zinc-500">
        <Spinner /> {TOOL_LABELS[part.type] ?? "Working…"}
      </div>
    );
  }

  switch (part.type) {
    case "tool-getPortfolioMetrics": {
      const out = part.output as MetricsOutput;
      return <MetricsGrid metrics={out.metrics} computedAt={out.computedAt} />;
    }
    case "tool-getFindings": {
      const out = part.output as FindingsOutput;
      if (out.findings.length === 0) return <InlineNote text="No findings match." />;
      return (
        <div>
          {out.findings.map((f) => (
            <FindingCard key={f.id} finding={f} />
          ))}
        </div>
      );
    }
    case "tool-getAgentRoster": {
      const out = part.output as RosterOutput;
      return <RosterList agents={out.agents} />;
    }
    case "tool-getAgentTrackRecord": {
      const out = part.output as TrackRecordOutput;
      return <TrackRecordList accuracy={out.agents} />;
    }
    case "tool-getProjectStatus": {
      const out = part.output as ProjectStatusOutput;
      return <ProjectStatusList items={out.items} />;
    }
    case "tool-approveFinding":
    case "tool-rejectFinding": {
      const out = part.output as DecisionOutput;
      return (
        <div
          className={`my-1.5 rounded-lg border px-3 py-1.5 text-xs ${
            out.ok
              ? "border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-300"
              : "border-red-200 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950 dark:text-red-300"
          }`}
        >
          {out.ok
            ? `Finding ${out.findingId} ${out.decision}.` +
              (out.actionDetail ? ` ${out.actionDetail}.` : "") +
              (out.followupWpId ? ` Follow-up WP #${out.followupWpId}.` : "")
            : `Could not ${out.decision === "approved" ? "approve" : "reject"} ${out.findingId}: ${out.error}`}
        </div>
      );
    }
    case "tool-triggerSweep": {
      const out = part.output as SweepResultData;
      return <SweepResult result={out} />;
    }
    default:
      return null;
  }
}

function InlineNote({ text }: { text: string }) {
  return (
    <div className="my-1.5 rounded-lg border border-dashed border-zinc-300 px-3 py-1.5 text-xs text-zinc-500 dark:border-zinc-700 dark:text-zinc-400">
      {text}
    </div>
  );
}

function Spinner() {
  return (
    <svg viewBox="0 0 16 16" className="h-3.5 w-3.5 animate-spin" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="8" cy="8" r="6" className="opacity-25" />
      <path d="M14 8a6 6 0 0 0-6-6" strokeLinecap="round" />
    </svg>
  );
}

function Dot({ delay }: { delay: string }) {
  return (
    <span
      className="inline-block h-1.5 w-1.5 animate-bounce rounded-full bg-current"
      style={{ animationDelay: delay }}
    />
  );
}
