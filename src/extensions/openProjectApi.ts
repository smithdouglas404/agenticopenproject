import type { onAuthenticatePayload, onLoadDocumentPayload, onStoreDocumentPayload } from "@hocuspocus/server";
import { Extension } from "@hocuspocus/server";
import { createVerifier } from 'fast-jwt';
import * as Y from "yjs";
import type { ApiResponseDocument, OpenProjectApiConfiguration } from "../types";

export class OpenProjectApi implements Extension {
  configuration: OpenProjectApiConfiguration;
  verifier: ReturnType<typeof createVerifier>;
  apiKey: string;

  constructor(configuration: OpenProjectApiConfiguration) {
    this.configuration = configuration;
    this.verifier = createVerifier({ key: async () => this.configuration.secret, algorithms: ['HS256'] });
    this.apiKey = Buffer.from(`apikey:${this.configuration.apiKey}`, "utf-8").toString("base64");
  }

  async onAuthenticate(data: onAuthenticatePayload) {
    const { token, documentName } = data;
    if (!token) {
      throw new Error('Unauthorized: Token missing.');
    }
    let tokenPayload;
    try {
      tokenPayload = await this.verifier(token);
    } catch (_err) {
      throw new Error('Unauthorized: Invalid token.');
    }
    if(documentName != tokenPayload.document_name) {
      throw new Error('Unauthorized: This document cannot be accessed with this token.');
    }
    data.context.documentId = tokenPayload.document_id;
  }

  /**
    * Retrieve data from the API. This should return the YDoc data
    */
  async onLoadDocument(data: onLoadDocumentPayload) {
    const { documentId } = data.context;

    const targetUrl = `${this.configuration.apiUrl}/api/v3/documents/${documentId}`;
    console.log(`GET ${targetUrl}`);

    const response = await fetch(targetUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${this.apiKey}`,
      },
    });

    if (!response.ok) {
      console.warn(`Error fetching document: ${response.statusText}`);
      return;
    }

    const jsonData = await response.json() as ApiResponseDocument;
    if (jsonData.contentBinary) {
      const update = new Uint8Array(Buffer.from(jsonData.contentBinary, 'base64'));
      Y.applyUpdate(data.document, update);
    }
  }

  /**
    * Store data to the API. The data is a YDoc update
    */
  async onStoreDocument(data: onStoreDocumentPayload): Promise<void> {
    const { documentId } = data.context;

    const targetUrl = `${this.configuration.apiUrl}/api/v3/documents/${documentId}`;
    console.log(`PATCH ${targetUrl}`);

    const base64Data = Buffer.from(Y.encodeStateAsUpdate(data.document)).toString("base64");

    const response = await fetch(targetUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${this.apiKey}`,
      },
      body: JSON.stringify({
        content_binary: base64Data
      }),
    });

    if (!response.ok) {
      console.warn(`Error storing document: ${response.statusText}`);
    }
  }
}

