import axios from "axios";

type RuntimeWindow = Window & {
  __RST_API_BASE__?: string;
};

function resolveProductionBaseURL(): string {
  if (typeof window === "undefined") {
    return "";
  }

  const runtimeWindow = window as RuntimeWindow;
  const runtimeOverride = runtimeWindow.__RST_API_BASE__?.trim();
  if (runtimeOverride) {
    return runtimeOverride;
  }

  return window.location.origin;
}

// In dev, use the Vite proxy. In production/release, default to same-origin.
// An explicit runtime override can still be provided via window.__RST_API_BASE__.
const baseURL = import.meta.env.DEV ? "/api" : resolveProductionBaseURL();

const DEFAULT_API_TIMEOUT_MS = 300000;
const parsedTimeout = Number.parseInt(
  (import.meta.env.VITE_API_TIMEOUT_MS as string | undefined) ?? "",
  10,
);
export const API_TIMEOUT_MS =
  Number.isFinite(parsedTimeout) && parsedTimeout > 0 ? parsedTimeout : DEFAULT_API_TIMEOUT_MS;

export const apiClient = axios.create({
  baseURL,
  timeout: API_TIMEOUT_MS,
  headers: {
    "Content-Type": "application/json",
  },
});

export default apiClient;