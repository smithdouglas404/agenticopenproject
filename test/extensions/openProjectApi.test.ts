import { describe, expect, test, vi, beforeEach, afterEach } from "vitest";
import { OpenProjectApi } from "../../src/extensions/openProjectApi";
import { onAuthenticatePayload, onLoadDocumentPayload, onStoreDocumentPayload } from "@hocuspocus/server";
import * as Y from "yjs";

describe("OpenProjectApi", () => {
  describe("onAuthenticate", () => {
    test("when the token is not present throw an error", async () => {
      await expect(() =>
        new OpenProjectApi({}).onAuthenticate({
          token: null,
        } as unknown as onAuthenticatePayload)
      ).rejects.toThrowError("Unauthorized: Token missing.");
    });

    test("when the token has an invalid secret throw an error", async () => {
      /*
       * {
       *   "document_id": 121,
       *   "document_name": "TheDocName",
       *   "document_text": "empty except this"
       * }
       *
       * secret: "notTheSecret"
       */
      const tokenWithWrongSecret = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb2N1bWVudF9pZCI6MTIxLCJkb2N1bWVudF9uYW1lIjoiVGhlRG9jTmFtZSIsImRvY3VtZW50X3RleHQiOiJlbXB0eSBleGNlcHQgdGhpcyJ9.ANskFI50S6eEji-s5IYp7tLtNsuYpzE8Xz7kzj9CmsE";

      await expect(() =>
        new OpenProjectApi({}).onAuthenticate({
          token: tokenWithWrongSecret,
        } as unknown as onAuthenticatePayload)
      ).rejects.toThrowError("Unauthorized: Invalid token.");
    });

    test("when the document_name does not match the token, throw an error", async () => {
      /*
       * {
       *   "document_id": 121,
       *   "document_name": "TheDocName",
       *   "document_text": "empty except this"
       * }
       *
       * secret: "testSuperSecret1234"
       */
      const tokenWithWrongDocumentName = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb2N1bWVudF9pZCI6MTIxLCJkb2N1bWVudF9uYW1lIjoiVGhlRG9jTmFtZSIsImRvY3VtZW50X3RleHQiOiJlbXB0eSBleGNlcHQgdGhpcyJ9.X1uCNy7WlPmOWClAmYSCvNIvi0wahxg_D3UcC1UDmYU";

      await expect(() =>
        new OpenProjectApi({}).onAuthenticate({
          token: tokenWithWrongDocumentName,
          documentName: "AnotherDocName",
        } as unknown as onAuthenticatePayload)
      ).rejects.toThrowError("Unauthorized: This document cannot be accessed with this token.");
    });

    test("when the token matches all requirements, set the documentId on the context", async () => {
      /*
       * {
       *   "document_id": 121,
       *   "document_name": "TheDocName",
       *   "document_text": "empty except this"
       * }
       *
       * secret: "testSuperSecret1234"
       */
      const validToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb2N1bWVudF9pZCI6MTIxLCJkb2N1bWVudF9uYW1lIjoiVGhlRG9jTmFtZSIsImRvY3VtZW50X3RleHQiOiJlbXB0eSBleGNlcHQgdGhpcyJ9.X1uCNy7WlPmOWClAmYSCvNIvi0wahxg_D3UcC1UDmYU";

      const data = {
        context: {},
        token: validToken,
        documentName: "TheDocName",
      } as unknown as onAuthenticatePayload;

      await new OpenProjectApi({}).onAuthenticate(data);

      expect(data.context.documentId).toEqual(121);
    });
  });

  describe("onLoadDocument", () => {
    let fetchMock: any;

    beforeEach(() => {
      fetchMock = vi.fn();
      vi.stubGlobal('fetch', fetchMock);
    });

    afterEach(() => {
      vi.unstubAllGlobals();
    });

    test("should fetch document content and apply update to YDoc", async () => {
      // Create a valid YJS update by encoding state from a document with content
      const sourceDoc = new Y.Doc();
      const text = sourceDoc.getText('content');
      text.insert(0, 'test content');
      const validUpdate = Y.encodeStateAsUpdate(sourceDoc);

      fetchMock.mockResolvedValueOnce({
        ok: true,
        status: 200,
        arrayBuffer: () => Promise.resolve(validUpdate.buffer),
      });

      const document = new Y.Doc();
      const data = {
        context: { documentId: 121 },
        document,
      } as onLoadDocumentPayload;

      const api = new OpenProjectApi({ apiUrl: "https://test.api", token: "" });
      await api.onLoadDocument(data);

      expect(fetchMock).toHaveBeenCalledWith(
        "https://test.api/api/v3/documents/121/content_binary",
        {
          method: "GET",
          headers: {
            "Content-Type": "application/octet-stream",
            "Authorization": expect.stringContaining("Basic "),
          },
        }
      );

      // Verify the document was updated with the content
      const updatedContent = document.getText('content').toString();
      expect(updatedContent).toBe('test content');
    });

    test("should return early when response is not successful", async () => {
      fetchMock.mockResolvedValueOnce({
        ok: false,
        status: 404,
      });

      const data = {
        context: { documentId: 121 },
        document: new Y.Doc(),
      } as onLoadDocumentPayload;

      const initialContent = data.document.getText('content').toString();

      const api = new OpenProjectApi({ apiUrl: "https://test.api", token: "" });
      await api.onLoadDocument(data);

      expect(fetchMock).toHaveBeenCalled();

      const updatedContent = data.document.getText('content').toString();
      expect(updatedContent).toBe(initialContent);
    });
  });

  describe("onStoreDocument", () => {
    let fetchMock: any;

    beforeEach(() => {
      fetchMock = vi.fn();
      vi.stubGlobal('fetch', fetchMock);
    });

    afterEach(() => {
      vi.unstubAllGlobals();
    });

    test("should store document content successfully", async () => {
      fetchMock.mockResolvedValueOnce({
        ok: true,
        status: 200,
      });

      const document = new Y.Doc();
      const text = document.getText('content');
      text.insert(0, 'test document content');

      const data = {
        context: { documentId: 121 },
        document,
      } as onStoreDocumentPayload;

      const api = new OpenProjectApi({ apiUrl: "https://test.api", token: "" });
      await api.onStoreDocument(data);

      expect(fetchMock).toHaveBeenCalledWith(
        "https://test.api/api/v3/documents/121/content_binary",
        {
          method: "PUT",
          headers: {
            "Content-Type": "application/octet-stream",
            "Authorization": expect.stringContaining("Basic "),
          },
          body: Buffer.from(Y.encodeStateAsUpdate(data.document)),
        }
      );
    });
  });
});
