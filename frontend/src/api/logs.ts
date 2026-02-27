import apiClient from "@/api/client";
import type { LogEntry } from "@/types/log";

export async function fetchLogs(): Promise<LogEntry[]> {
  const { data } = await apiClient.get<LogEntry[]>("/logs");
  return data;
}

export async function fetchLogDetail(id: string): Promise<LogEntry> {
  const { data } = await apiClient.get<LogEntry>(`/logs/${encodeURIComponent(id)}`);
  return data;
}
