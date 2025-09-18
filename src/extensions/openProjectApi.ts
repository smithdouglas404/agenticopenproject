import { Extension } from "@hocuspocus/server";
import type { onLoadDocumentPayload, onStoreDocumentPayload } from "@hocuspocus/server";
import type { Document, OpenProjectApiConfiguration, ApiResponseDocument } from "../types";

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
      const { document_id } = data.context;

      console.log(`ZZZZ making request to ${this.configuration.apiUrl}/api/v3/documents/${document_id}`);

      // Did not check the URL. Might be wrong
      const response = await fetch(`${this.configuration.apiUrl}/api/v3/documents/${document_id}`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Basic YXBpa2V5OjE4ZjY2NTQzYjU0ODAzZDkzYzc1ZGU1MjY0YzdjZWRlYjllNzU5MWEzOWE4NmZiYzhhOGFjZTJmOTVhMjA4N2E=`,
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
  async onStoreDocument(_data: onStoreDocumentPayload): Promise<void> {
    console.log("Storing document");
  }
}

