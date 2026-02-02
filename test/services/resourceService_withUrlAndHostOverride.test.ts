import { afterAll, beforeAll, describe, expect, test, vi } from "vitest";
import { fetchResource } from "../../src/services/resourceService";

// we test this in a separate file because the resource service config (process env) is initialized
// once when the test suite starts, meaning we can't change it between cases in the same file
describe("fetchResource with overriden OpenProject URL and host", () => {
  beforeAll(() => {
    vi.hoisted(() => {
      vi.stubEnv("OPENPROJECT_URL", "http://web");
      vi.stubEnv("OPENPROJECT_HOST", "test.openproject.com");
    });
  });

  afterAll(() => {
    vi.unstubAllEnvs();
  });

  test("Overrides the base URL protocol and host, as well as the Host header", async () => {
    const resourceUrl = "https://test.openproject.com/api/v3/documents/42";
    const response = await fetchResource(resourceUrl, "__valid_oauth_token");

    expect(response.data).toMatchObject({ __echo: { url: "http://web/api/v3/documents/42", hostHeader: "test.openproject.com" }})
  });
});
