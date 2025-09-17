import { Extension } from "@hocuspocus/server";
import type { onLoadDocumentPayload, onStoreDocumentPayload } from "@hocuspocus/server";

interface ApiResponseDocument {
  _embedded: {
    attachments: { total: number, count: number },
    project: { name: string },
  },
  _type: string,
  id: string,
  title: string,
  description: {
    format: string,
    raw: string,
    html: string,
  },
  createdAt: string,
  updatedAt: string,
}
export interface Document {
  id: string;
  title: string;
  content: string;
}

export interface OpenProjectApiConfiguration {
  apiUrl: string;
  token: string;
}
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

  async onLoadDocument(data: onLoadDocumentPayload): Promise<Document> {
    try {
      // We need to pass on the context the actual documentId.
      // This needs to happen in OpenProject.
      const documentId = data.context.documentId;

      // Did not check the URL. Might be wrong
      const response = await fetch(`${this.configuration.apiUrl}/api/v3/documents/${documentId}`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          // There is probably a better way than token based. Need to investigate.
          "Authorization": `token ${data.context.token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Error fetching document: ${response.statusText}`);
      }

      // We're returning data here on the onLoadDocument, but I'm not sure
      // how to use it, yet :)
      const documentData = await response.json() as ApiResponseDocument;
      return {
        id: documentData.id,
        title: documentData.title,
        content: documentData.description.raw,
      };
    } catch (error) {
      console.error("Failed to load document from OpenProject API:", error);
    }

    throw new Error("Could not load document");
  }

  /**
    * This is just a simulation of storing the document. This
    * method should be debounced properly. The idea would be to make
    * an API call to the server, sending the binary data AND a text
    * data
    */
  async onStoreDocument(data: onStoreDocumentPayload): Promise<void> {
    setTimeout(
      () => { console.log("Simulating storing document...", data); },
      500
    );
  }
}

