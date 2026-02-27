import axios from "axios";

// Use Vite proxy in dev and explicit API base in production
const baseURL = import.meta.env.DEV
  ? "/api"
  : (import.meta.env.VITE_API_BASE as string | undefined) ?? "http://localhost:18080";

export const apiClient = axios.create({
  baseURL,
  timeout: 15000,
  headers: {
    "Content-Type": "application/json",
  },
});

export default apiClient;
