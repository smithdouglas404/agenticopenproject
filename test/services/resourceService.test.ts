import { describe, expect, test, vi } from "vitest";
import { fetchResource } from "../../src/services/resourceService";

// Web requests are mocked via the dynamic document response (see `handlers.ts`) returning
// the `__echo` field we use to confirm the called URL and host header.
describe("fetchResource", () => {
  test("requests the resource at the original URL, with the original host header", async () => {
    const resourceUrl = "https://test.openproject.com/api/v3/documents/42";
    const response = await fetchResource(resourceUrl, "__valid_oauth_token").then(r => r.json());

    expect(response).toMatchObject({ __echo: { url: resourceUrl }})
  });
});
