import { describe, expect, test, vi } from "vitest";
import { fetchResource } from "../../src/services/resourceService";

const oauthToken: string = "xxxxx.yyyyy.zzzzz";
const fetchParams = {
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${oauthToken}`,
  },
  method: "GET"
};

describe("fetchResource", () => {
  test("returns the host if a direct host is not defined", () => {
    using fetch = vi.spyOn(global, "fetch");
    const resourceUrl = "https://example.com/path/to/resource";
    
    fetchResource(resourceUrl, oauthToken);

    expect(fetch).toHaveBeenCalledWith(resourceUrl, fetchParams);
  });
});
