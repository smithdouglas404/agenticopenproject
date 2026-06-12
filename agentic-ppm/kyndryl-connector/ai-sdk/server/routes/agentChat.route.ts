/**
 * POST /api/agent-chat — Vercel AI SDK (v5) streaming chat route.
 *
 * Body: { messages: UIMessage[] } (what useChat / DefaultChatTransport sends).
 * Streams a UI-message stream back (text deltas + typed tool parts) that the
 * client renders as generative-UI widgets (../../client/AgenticChat.tsx).
 *
 * DROP-IN (Kyndral server/routes.ts — or wherever app routes are registered):
 *
 *   import express from "express";
 *   import { initAgentChatRoute } from "./ai-sdk/server/routes/agentChat.route";
 *   app.use(initAgentChatRoute(express.Router()));
 *
 * Install:  npm i ai @ai-sdk/anthropic zod   (client also needs @ai-sdk/react)
 *
 * Env:
 *   ANTHROPIC_API_KEY   required — read by @ai-sdk/anthropic.
 *   ANTHROPIC_MODEL     optional model override (default claude-sonnet-4-5).
 *                       The chat model can be cheap (SmartModelRouter-friendly):
 *                       the data is precomputed by the runtime, the model only
 *                       explains it.
 *   AGENT_RUNTIME_URL   agent-runtime sidecar (default http://localhost:8745).
 *   CONSOLE_TOKEN       optional bearer token for the sidecar, if it has one set.
 *
 * NOTE: ensure express.json() runs before this route so req.body is parsed.
 */
import type { Router, Request, Response } from "express";
import { convertToModelMessages, stepCountIs, streamText, type UIMessage } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { agenticTools, AGENTIC_SYSTEM_PROMPT } from "../tools";

/** Up to 8 model↔tool steps per turn (fetch metrics, findings, then explain). */
const MAX_STEPS = 8;

export function initAgentChatRoute(router: Router): Router {
  router.post("/api/agent-chat", async (req: Request, res: Response) => {
    const messages = (req.body as { messages?: UIMessage[] } | undefined)?.messages;
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: "body must be { messages: UIMessage[] }" });
      return;
    }

    try {
      const result = streamText({
        // Model id configurable via env; default per the integration spec.
        model: anthropic(process.env.ANTHROPIC_MODEL ?? "claude-sonnet-4-5"),
        system: AGENTIC_SYSTEM_PROMPT,
        messages: await convertToModelMessages(messages),
        tools: agenticTools,
        stopWhen: stepCountIs(MAX_STEPS),
      });

      // Express adapter: pipes the UI-message stream (SSE) onto the response.
      result.pipeUIMessageStreamToResponse(res);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.warn(`[agent-chat] failed: ${message}`);
      if (!res.headersSent) res.status(500).json({ error: message });
      else res.end();
    }
  });

  return router;
}
