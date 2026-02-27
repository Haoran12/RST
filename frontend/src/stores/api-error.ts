import axios from "axios";

import type { AxiosError } from "axios";

// Normalize axios errors into user-facing messages.
export function parseApiError(error: unknown): string {
  if (!axios.isAxiosError(error)) {
    return "请求失败";
  }
  if (error.code === "ERR_CANCELED") {
    return "请求已取消";
  }
  if (isTimeoutError(error)) {
    return "请求超时，请稍后重试";
  }
  if (!error.response) {
    return "无法连接到后端";
  }
  const detail = (error.response.data as { detail?: unknown } | undefined)?.detail;
  if (error.response.status === 422 && Array.isArray(detail)) {
    const messages = detail
      .map((item: { msg?: string; loc?: (string | number)[] }) => {
        const field = item.loc?.[1];
        return field ? `${field}: ${item.msg}` : item.msg;
      })
      .filter(Boolean);
    if (messages.length > 0) {
      return messages.join("，");
    }
  }
  if (typeof detail === "string" && detail.length > 0) {
    return detail;
  }
  return "请求失败";
}

function isTimeoutError(error: AxiosError): boolean {
  const code = error.code?.toUpperCase();
  if (code === "ECONNABORTED" || code === "ETIMEDOUT") {
    return true;
  }
  return error.message.toLowerCase().includes("timeout");
}

