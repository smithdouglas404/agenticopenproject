export interface Document {
  id: string;
  title: string;
  content: string;
}

export interface OpenProjectApiConfiguration {
  apiUrl: string;
  token: string;
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
  createdAt: string,
  updatedAt: string,
}