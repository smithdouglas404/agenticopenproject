import type { Extension, onRequestPayload } from "@hocuspocus/server";
import type { IncomingMessage } from "http";
import * as Y from "yjs";
import { createEditor } from "./openProjectApi";

export class MarkdownConverter implements Extension {
  async onRequest({ request, response }: onRequestPayload): Promise<void> {
    if (request.method !== "POST" || request.url !== "/convert-markdown") {
      return;
    }

    const secret = request.headers["x-secret"];
    if (!process.env.SECRET || secret !== process.env.SECRET) {
      response.writeHead(401, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "Unauthorized" }));
      return;
    }

    let markdown: string;
    try {
      markdown = await readBody(request);
    } catch {
      response.writeHead(400, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "Failed to read request body" }));
      return;
    }

    try {
      const editor = createEditor();
      // @ts-expect-error BlockNote types are complicated
      const blocks = await editor.tryParseMarkdownToBlocks(markdown);
      const doc = new Y.Doc();
      const fragment = doc.getXmlFragment("document-store");
      // @ts-expect-error BlockNote types are complicated
      editor.blocksToYXmlFragment(blocks, fragment);
      const contentBinary = Buffer.from(Y.encodeStateAsUpdate(doc)).toString("base64");

      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ content_binary: contentBinary }));
    } catch {
      response.writeHead(500, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "Conversion failed" }));
    }
  }
}

function readBody(request: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    request.on("data", (chunk: Buffer) => chunks.push(chunk));
    request.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    request.on("error", reject);
  });
}
