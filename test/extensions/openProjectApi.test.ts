import { describe, expect, test } from "vitest";
import { OpenProjectApi } from "../../src/extensions/openProjectApi";
import { onAuthenticatePayload } from "@hocuspocus/server";

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
});
