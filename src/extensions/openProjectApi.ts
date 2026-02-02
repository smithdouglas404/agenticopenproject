import { BlockNoteSchema } from "@blocknote/core";
import { ServerBlockNoteEditor } from "@blocknote/server-util";
import type { onAuthenticatePayload, onLoadDocumentPayload, onStoreDocumentPayload } from "@hocuspocus/server";
import { Extension } from "@hocuspocus/server";
import { openProjectWorkPackageStaticBlockSpec } from "op-blocknote-extensions";
import * as Y from "yjs";
import { decryptToken } from "../services/decryptTokenService";
import type { ApiResponseDocument } from "../types";
import { fetchResource } from "../services/resourceService";

export const editorSchema = BlockNoteSchema.create().extend({
  blockSpecs: {
    "openProjectWorkPackage": openProjectWorkPackageStaticBlockSpec(),
  },
});

function printLog(message:string) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

export function createEditor() {
  return ServerBlockNoteEditor.create({ schema: editorSchema });
}

export class OpenProjectApi implements Extension {
  /**
    * Authenticate the user by validating the token and document access
    */
  async onAuthenticate(data: onAuthenticatePayload) {
    const { token: packedParams, documentName: resourceUrl } = data;

    if (!packedParams) {
      throw new Error('Unauthorized: Missing auth params');
    }

    const decryptedToken = decryptToken(packedParams);

    const {
      resource_url: tokenResourceUrl,
      oauth_token,
      // readonly,
    } = decryptedToken;

    const requestOrigin = data.request?.headers?.origin;
    if (requestOrigin && !tokenResourceUrl?.startsWith(requestOrigin)) {
      throw new Error('Unauthorized: Token origin does not match request origin.');
    }

    if (tokenResourceUrl !== resourceUrl) {
      throw new Error(`Unauthorized: Token resource URL does not match document. (Token: ${tokenResourceUrl}, Resource: ${resourceUrl})`);
    }

    const response = await fetchResource(resourceUrl, oauth_token);

    if (response.status != 200) {
      throw new Error(`Unauthorized: Invalid token or document access denied. (${response.status}: ${response.statusText})`);
    }
    const jsonData = await response.data as ApiResponseDocument;

    data.context.resourceUrl = resourceUrl;
    data.context.token = oauth_token;
    if (!jsonData._links?.update) {
      // https://tiptap.dev/docs/hocuspocus/guides/auth#read-only-mode
      data.connectionConfig.readOnly = true;
      data.context.readonly = true;
    }
  }

  /**
    * Retrieve data from the API. This should return the YDoc data
    */
  async onLoadDocument(data: onLoadDocumentPayload) {
    const { resourceUrl } = data.context;

    const response = await fetchResource(resourceUrl, data.context.token);

    if (response.status != 200) {
      console.warn(`Error fetching document (${response.status}: ${response.statusText})`);
      return;
    }

    const jsonData = await response.data as ApiResponseDocument;
    if (jsonData.contentBinary) {
      const update = new Uint8Array(Buffer.from(jsonData.contentBinary, 'base64'));
      Y.applyUpdate(data.document, update);
    }

    return data.document;
  }

  /**
    * Store data to the API. The data is a YDoc update
    */
  async onStoreDocument(data: onStoreDocumentPayload): Promise<void> {
    const { resourceUrl, readonly } = data.context;

    if (!resourceUrl) {
      console.warn("Missing parameters in context. Skipping store.");
      return;
    }
    if (readonly) {
      console.warn("Readonly user cannot make requests to store the document");
      return;
    }

    printLog(`PATCH ${resourceUrl}`);

    const base64Data = Buffer.from(Y.encodeStateAsUpdate(data.document)).toString("base64");

    // Create a copy of the document to avoid side effects
    const editor = createEditor();
    const tempYdoc = new Y.Doc();
    Y.applyUpdate(tempYdoc, Y.encodeStateAsUpdate(data.document));
    const tempFragment = tempYdoc.getXmlFragment("document-store");
    const editorData = editor.yXmlFragmentToBlocks(tempFragment);
    // @ts-expect-error BlockNote types are complicated
    const markdownData = await editor.blocksToMarkdownLossy(editorData);

    const response = await fetchResource(resourceUrl, data.context.token, {
      method: "PATCH",
      data: {
        content_binary: base64Data,
        description: markdownData,
      },
    });

    if (response.status != 200) {
      console.warn(`Error storing document (${response.status}: ${response.statusText})`);
      return;
    }

    data.document.connections.forEach(({ connection }) => connection.sendStateless("storeEvent"));
  }
}

