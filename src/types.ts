export interface Document {
  id: string;
  title: string;
  content: string;
}

export interface OpenProjectApiConfiguration {
  /** The base URL of the OpenProject instance, e.g. "https://openproject.example.com" */
  apiUrl: string;
  /** The API key for authentication with the OpenProject instance */
  apiKey: string;
  /** The secret used to verify JWT tokens */
  secret: string;
}

export interface ApiResponseDocument {
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
  contentBinary: string,
  createdAt: string,
  updatedAt: string,
}
