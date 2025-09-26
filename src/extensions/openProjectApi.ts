import { Extension } from "@hocuspocus/server";
import { createVerifier } from 'fast-jwt';
import type { onAuthenticatePayload, onLoadDocumentPayload, onStoreDocumentPayload } from "@hocuspocus/server";
import type { OpenProjectApiConfiguration } from "../types";
import * as Y from "yjs";

const secret = process.env.SECRET;
if (!secret) {
  console.log(`SECRET must be provided`);
  process.exit();
};

const verifyToken = createVerifier({ key: async () => secret, algorithms: ['HS256'] });

// my local dev env key, it's not a leak :)
const RAW_KEY = "cf58c5077dc4e3b36c474e59711f069f2d52e940c2fd1999ad073fa36e6693ca";
const API_KEY = Buffer.from(`apikey:${RAW_KEY}`, "utf-8").toString("base64");

export class OpenProjectApi implements Extension {
  configuration: OpenProjectApiConfiguration = {
    apiUrl: "https://openproject.local",
    token: "",
  };

  constructor(configuration: OpenProjectApiConfiguration) {
    this.configuration = {
      ...this.configuration,
      ...configuration
    };
  }

  async onAuthenticate(data: onAuthenticatePayload) {
    const { token, documentName } = data;
    if (!token) {
      throw new Error('Unauthorized: Token missing.');
    }
    let tokenPayload;
    try {
      tokenPayload = await verifyToken(token);
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

    const targetUrl = `${this.configuration.apiUrl}/api/v3/documents/${documentId}/content_binary`;
    console.log(`GET ${targetUrl}`);
    const response = await fetch(targetUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/octet-stream",
        "Authorization": `Basic ${API_KEY}`,
      },
    });

    // When there is no data on the server, assume it is a new document, so we just return
    if (response.status === 404) {
      return;
    }

    if (!response.ok) {
      console.warn(`Error fetching document: ${response.statusText}`);
    }

    const update = new Uint8Array(await response.arrayBuffer());
    Y.applyUpdate(data.document, update);
  }

  /**
    * Store data to the API. The data is a YDoc update
    */
  async onStoreDocument(data: onStoreDocumentPayload): Promise<void> {
    const { documentId } = data.context;

    const targetUrl = `${this.configuration.apiUrl}/api/v3/documents/${documentId}/content_binary`;
    console.log(`PUT ${targetUrl}`);
    const response = await fetch(targetUrl, {
      method: "PUT",
      headers: {
        "Content-Type": "application/octet-stream",
        "Authorization": `Basic ${API_KEY}`,
      },
      body: Buffer.from(Y.encodeStateAsUpdate(data.document)),
    });

    if (!response.ok) {
      console.warn(`Error storing document: ${response.statusText}`);
    }
  }
}

