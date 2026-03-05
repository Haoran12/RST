import apiClient from "@/api/client";
import type { LogEntry } from "@/types/log";

interface CleanupLogsResponse {
  removed: number;
}

export async function fetchLogs(): Promise<LogEntry[]> {
  const { data } = await apiClient.get<LogEntry[]>("/logs");
  return data;
}

export async function fetchLogDetail(id: string): Promise<LogEntry> {
  const { data } = await apiClient.get<LogEntry>(`/logs/${encodeURIComponent(id)}`);
  return data;
}

export async function cleanupExpiredLogs(retentionDays = 7): Promise<number> {
  const { data } = await apiClient.delete<CleanupLogsResponse>("/logs/expired", {
    params: { retention_days: retentionDays },
  });
  return data.removed;
}
