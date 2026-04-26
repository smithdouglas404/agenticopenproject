import type { onRequestPayload } from "@hocuspocus/server";
import type { IncomingMessage, ServerResponse } from "http";
import { Readable } from "stream";
import { describe, expect, test, vi } from "vitest";
import { MarkdownConverter } from "../../src/extensions/markdownConverter";

function createRequest(options: {
  method: string;
  url: string;
  headers?: Record<string, string>;
  body?: string;
}): IncomingMessage {
  const readable = new Readable({ read() {} }) as unknown as IncomingMessage;
  readable.method = options.method;
  readable.url = options.url;
  (readable as any).headers = options.headers ?? {};

  process.nextTick(() => {
    if (options.body) {
      (readable as any).emit("data", Buffer.from(options.body));
    }
    (readable as any).emit("end");
  });

  return readable;
}

function createResponse() {
  let statusCode = 0;
  let responseBody = "";

  const response = {
    writeHead: vi.fn((code: number) => { statusCode = code; }),
    end: vi.fn((data: string) => { responseBody = data; }),
  } as unknown as ServerResponse;

  return {
    response,
    getStatus: () => statusCode,
    getBody: () => responseBody,
  };
}

describe("MarkdownConverter", () => {
  const SECRET = process.env.SECRET!;

  describe("onRequest", () => {
    test("passes through requests to other URLs without responding", async () => {
      const request = createRequest({ method: "GET", url: "/other-path" });
      const { response } = createResponse();

      await new MarkdownConverter().onRequest({ request, response } as onRequestPayload);

      expect(response.writeHead).not.toHaveBeenCalled();
      expect(response.end).not.toHaveBeenCalled();
    });

    test("passes through non-POST requests to /convert-markdown", async () => {
      const request = createRequest({ method: "GET", url: "/convert-markdown" });
      const { response } = createResponse();

      await new MarkdownConverter().onRequest({ request, response } as onRequestPayload);

      expect(response.writeHead).not.toHaveBeenCalled();
    });

    test("returns 401 when X-Secret header is missing", async () => {
      const request = createRequest({ method: "POST", url: "/convert-markdown", body: "# Hello" });
      const { response, getStatus, getBody } = createResponse();

      await new MarkdownConverter().onRequest({ request, response } as onRequestPayload);

      expect(getStatus()).toBe(401);
      expect(JSON.parse(getBody())).toEqual({ error: "Unauthorized" });
    });

    test("returns 401 when X-Secret header is wrong", async () => {
      const request = createRequest({
        method: "POST",
        url: "/convert-markdown",
        headers: { "x-secret": "wrong-secret" },
        body: "# Hello",
      });
      const { response, getStatus } = createResponse();

      await new MarkdownConverter().onRequest({ request, response } as onRequestPayload);

      expect(getStatus()).toBe(401);
    });

    test("returns 200 with content_binary for valid markdown", async () => {
      const request = createRequest({
        method: "POST",
        url: "/convert-markdown",
        headers: { "x-secret": SECRET },
        body: "# Hello World\n\nSome paragraph text.",
      });
      const { response, getStatus, getBody } = createResponse();

      await new MarkdownConverter().onRequest({ request, response } as onRequestPayload);

      expect(getStatus()).toBe(200);
      const parsed = JSON.parse(getBody());
      expect(parsed).toHaveProperty("content_binary");
      expect(typeof parsed.content_binary).toBe("string");
      expect(parsed.content_binary.length).toBeGreaterThan(0);
    });

    test("returns valid base64 that can be decoded to a YDoc", async () => {
      const Y = await import("yjs");
      const request = createRequest({
        method: "POST",
        url: "/convert-markdown",
        headers: { "x-secret": SECRET },
        body: "Hello",
      });
      const { response, getBody, getStatus } = createResponse();

      await new MarkdownConverter().onRequest({ request, response } as onRequestPayload);

      expect(getStatus()).toBe(200);
      const { content_binary } = JSON.parse(getBody());
      const binary = new Uint8Array(Buffer.from(content_binary, "base64"));
      const doc = new Y.Doc();
      expect(() => Y.applyUpdate(doc, binary)).not.toThrow();
      const fragment = doc.getXmlFragment("document-store");
      expect(fragment.length).toBeGreaterThan(0);
    });
  });
});
