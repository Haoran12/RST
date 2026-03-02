import axios from "axios";

// Use Vite proxy in dev and explicit API base in production
const baseURL = import.meta.env.DEV
  ? "/api"
  : (import.meta.env.VITE_API_BASE as string | undefined) ?? "http://localhost:18080";

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
