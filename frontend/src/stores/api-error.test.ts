import { AxiosError } from "axios";
import { describe, expect, it } from "vitest";

import { parseApiError } from "@/stores/api-error";

describe("parseApiError", () => {
  it("returns timeout message for axios timeout errors", () => {
    const error = new AxiosError("timeout of 15000ms exceeded", "ECONNABORTED");
    expect(parseApiError(error)).toBe(
      "\u8bf7\u6c42\u8d85\u65f6\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5",
    );
  });

  it("returns canceled message for canceled requests", () => {
    const error = new AxiosError("canceled", "ERR_CANCELED");
    expect(parseApiError(error)).toBe("\u8bf7\u6c42\u5df2\u53d6\u6d88");
  });

  it("returns backend connectivity message when no response is present", () => {
    const error = new AxiosError("Network Error", "ERR_NETWORK");
    expect(parseApiError(error)).toBe("\u65e0\u6cd5\u8fde\u63a5\u5230\u540e\u7aef");
  });

  it("parses validation errors from 422 details", () => {
    const error = new AxiosError(
      "validation failed",
      undefined,
      undefined,
      undefined,
      {
        status: 422,
        statusText: "Unprocessable Entity",
        headers: {},
        config: { headers: {} } as never,
        data: {
          detail: [
            { loc: ["body", "name"], msg: "Field required" },
            { loc: ["body", "provider"], msg: "Invalid enum" },
          ],
        },
      },
    );

    expect(parseApiError(error)).toBe("name: Field required\uff0cprovider: Invalid enum");
  });
});
