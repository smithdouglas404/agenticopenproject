import { Extension } from "@hocuspocus/server";
import { createVerifier } from 'fast-jwt';
import type { onLoadDocumentPayload, storePayload } from "@hocuspocus/server";
import type { OpenProjectApiConfiguration } from "../types";
import * as Y from "yjs";

const secret = process.env.SECRET;
if (!secret) {
  console.log(`SECRET must be provided`);
  process.exit();
};

const verifyToken = createVerifier({ key: async () => secret, algorithms: ['HS256'] });

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
      throw new Error('Unauthorized: Invalid token. This document cannot be accessed with this token.');
    }
    data.context.documentId = tokenPayload.document_id;
  }

  /**
    * Retrieve data from the API. This should return the YDoc data
    */
  async onLoadDocument(data: onLoadDocumentPayload) {
    const { documentId } = data.context;

    // my local dev env key, it's not a leak :)
    const apiKey = "cf58c5077dc4e3b36c474e59711f069f2d52e940c2fd1999ad073fa36e6693ca";
    const authBase64 = Buffer.from(`apikey:${apiKey}`, "utf-8").toString("base64");

    const targetUrl = `${this.configuration.apiUrl}/api/v3/documents/${documentId}/content_binary`;
    console.log(`Fetching document from ${targetUrl}`);
    const response = await fetch(targetUrl, {
      method: "GET",
      headers: {
        "Content-Type": "application/octet-stream",
        "Authorization": `Basic ${authBase64}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Error fetching document: ${response.statusText}`);
    }

    const update = new Uint8Array(await response.arrayBuffer());
    Y.applyUpdate(data.document, update);
  }

  /**
    * This is just a simulation of storing the document. This
    * method should be debounced properly. The idea would be to make
    * an API call to the server, sending the binary data AND a text
    * data
    */
  async store(_data: storePayload): Promise<void> {
    console.log("Storing document");
  }
}

