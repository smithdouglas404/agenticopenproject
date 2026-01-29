import { afterAll, beforeAll, describe, expect, test, vi } from "vitest";
import { fetchResource } from "../../src/services/resourceService";

const oauthToken: string = "xxxxx.yyyyy.zzzzz";
const fetchParams = {
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${oauthToken}`,
  },
  method: "GET"
};

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

  test("Overrides the base URL protocol and host", () => {
    using fetch = vi.spyOn(global, "fetch");
    const resourceUrl = "https://example.com/path/to/resource";
    
    fetchResource(resourceUrl, oauthToken);

    expect(fetch).toHaveBeenCalledWith("http://web/path/to/resource", fetchParams);
  });
});
