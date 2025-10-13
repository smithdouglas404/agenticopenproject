import { Server } from "@hocuspocus/server";
import { OpenProjectApi } from "./extensions/openProjectApi";
import * as dotenv from "dotenv";

if (process.env.NODE_ENV !== "production") {
  dotenv.config();
}

const apiUrl = process.env.API_URL || "https://openproject.local";
const secret = process.env.SECRET;
const apiKey = process.env.API_KEY;
if (!secret || !apiKey) {
  console.log(`missing SECRET and API_KEY environment variables`);
  process.exit();
};

const server = new Server({
  port: 1234,
  quiet: false,
  extensions: [
    new OpenProjectApi({ apiUrl, apiKey, secret }),
  ],
});

server.listen();

