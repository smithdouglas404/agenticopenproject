import { Server } from "@hocuspocus/server";
import { OpenProjectApi } from "./extensions/openProjectApi";

const server = new Server({
  port: 1234,
  quiet: false,
  extensions: [
    new OpenProjectApi({
      apiUrl: process.env.API_URL || "https://openproject.local",
      token: process.env.API_TOKEN || "",
    }),
  ],
});

server.listen();

