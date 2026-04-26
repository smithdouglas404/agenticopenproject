import { Logger } from "@hocuspocus/extension-logger";
import { Server } from "@hocuspocus/server";
import { MarkdownConverter } from "./extensions/markdownConverter";
import { OpenProjectApi } from "./extensions/openProjectApi";

const server = new Server({
  port: 1234,
  quiet: false,
  extensions: [
    new MarkdownConverter(),
    new OpenProjectApi(),
    new Logger({
      onChange: false,
    }),
  ],
});

server.listen();

