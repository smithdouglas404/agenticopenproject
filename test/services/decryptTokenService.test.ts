import { describe, expect, test } from "vitest";
import { decryptToken } from "../../src/services/decryptTokenService";

describe("decryptToken", () => {
  test("should decrypt a valid encrypted token", () => {
    const encrypted = "WMQFd3AwwHfm0KISsw==--J/B7zDes29uvIkc5--e2kVs6LdIw8UAJc0P8DVaA==";
    const decrypted = decryptToken(encrypted);
    expect(decrypted).toBe("ze123token123");
  });
});
