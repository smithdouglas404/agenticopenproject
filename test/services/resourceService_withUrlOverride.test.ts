import { afterAll, beforeAll, describe, expect, test, vi } from "vitest";
import { fetchResource } from "../../src/services/resourceService";

// we test this in a separate file because the resource service config (process env) is initialized
// once when the test suite starts, meaning we can't change it between cases in the same file
describe("fetchResource with overriden OpenProject URL", () => {
  beforeAll(() => {
    vi.hoisted(() => {
      vi.stubEnv("OPENPROJECT_URL", "http://web");
    });
  });

  afterAll(() => {
    vi.unstubAllEnvs();
  });

  test("Overrides the base URL protocol and host", async () => {
    const resourceUrl = "https://test.openproject.com/api/v3/documents/42";
    const response = await fetchResource(resourceUrl, "__valid_oauth_token").then(r => r.json());

    expect(response).toMatchObject({ __echo: { url: 'http://web/api/v3/documents/42' }});
  });
});
