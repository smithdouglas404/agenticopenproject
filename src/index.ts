import { Server } from "@hocuspocus/server";
import { createVerifier } from 'fast-jwt';
import { ServerBlockNoteEditor } from "@blocknote/server-util";
import {
  BlockNoteSchema,
  defaultBlockSpecs,
} from "@blocknote/core";
import { OpenProjectApi } from "./extensions/openProjectApi";

const secret = process.env.SECRET;
if (!secret) {
  console.log(`SECRET must be provided`);
  process.exit();
};

const verifyToken = createVerifier({
  key: async () => secret,
  algorithms: ['HS256'],
});

const server = new Server({
  port: 1234,
  quiet: false,
  extensions: [
    new OpenProjectApi({
      apiUrl: process.env.API_URL || "https://openproject.local",
      token: process.env.API_TOKEN || "",
    }),
  ],
  async onConnect(data) {
    console.log('CONNECTED: documentName: %0, socketId %0', data.documentName, data.socketId);
  },
  async afterUnloadDocument(data) {
    console.log(`Document ${data.documentName} was closed`);
  },
  async onChange(data) {
    console.log(`Document ${data.documentName} was changed`);
  },
  async onLoadDocument({ context, document }) {
    const fragment = document.getXmlFragment('document-store');
    if (fragment.length === 0) {
      const schema = BlockNoteSchema.create({
        blockSpecs: defaultBlockSpecs,
      });
      const editor = ServerBlockNoteEditor.create({schema});
      const blocks = await editor.tryParseMarkdownToBlocks(context.document_text);
      const doc = editor.blocksToYDoc(blocks, "document-store");
      return doc;
    }
  },
  async onAuthenticate(data) {
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
    console.log('Token payload:', tokenPayload);
    if(documentName != tokenPayload.document_name) {
      throw new Error('Unauthorized: Invalid token. This document cannot be accessed with this token.');
    }
    data.context.document_text = tokenPayload.document_text;
    data.context.document_id = tokenPayload.document_id;
  },
});

server.listen();
