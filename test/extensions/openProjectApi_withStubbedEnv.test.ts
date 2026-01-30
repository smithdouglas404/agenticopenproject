import { onAuthenticatePayload } from "@hocuspocus/server";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, test, vi } from "vitest";
import { OpenProjectApi } from "../../src/extensions/openProjectApi";

describe("OpenProjectApi with stubbed env", () => {
  beforeAll(() => {
    vi.hoisted(() => {
      vi.stubEnv("OPENPROJECT_URL", "https://my.op-instance.com/");
    });
  });

  afterAll(() => {
    vi.unstubAllEnvs();
  });

  let fetchMock: any;
  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  test("when the url for the OpenProject instance is manually defined", async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () => Promise.resolve({}),
    });

    const data = {
      context: {},
      connectionConfig: {},
      token: "Yjo1x80JGIjrK8J6IDOuRn5kIOGvaAUw8C1so+dJJq7cgkllf3dQnw6d8bgiKbHXw8ZaMYE4IyOI1KQgX2ZRmx1mKBkxtb/fc7eCpGyTKGTA2Y1r/q7VJYiJZlpX7gx3nu569joEl/k=--mUkLaPiK0E82vGT9--gj1ZnTNlydL9j+Xw8+YFAA==",
      documentName: "https://test.api/api/v3/documents/1",
    } as unknown as onAuthenticatePayload;

    await new OpenProjectApi().onAuthenticate(data);

    expect(data.context.resourceUrl).toEqual("https://my.op-instance.com/api/v3/documents/1");
    expect(data.context.token).toEqual("some_token_value");
    expect(data.documentName).toEqual("https://test.api/api/v3/documents/1");
  });
});
