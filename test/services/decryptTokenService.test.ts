import { describe, expect, test } from "vitest";
import { decryptToken } from "../../src/services/decryptTokenService";

describe("decryptToken", () => {
  test("should decrypt a valid encrypted token", () => {
    const encrypted = "Yjo1x80JGIjrK8J6IDOuRn5kIOGvaAUw8C1so+dJJq7cgkllf3dQnw6d8bgiKbHXw8ZaMYE4IyOI1KQgX2ZRmx1mKBkxtb/fc7eCpGyTKGTA2Y1r/q7VJYiJZlpX7gx3nu569joEl/k=--mUkLaPiK0E82vGT9--gj1ZnTNlydL9j+Xw8+YFAA==";
    const decrypted = decryptToken(encrypted);
    expect(decrypted.resource_url).toBe("https://test.api/api/v3/documents/1");
    expect(decrypted.oauth_token).toBe("some_token_value");
    expect(decrypted.readonly).toBe(false);
  });
});
