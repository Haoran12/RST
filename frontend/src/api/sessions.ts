import apiClient from "@/api/client";
import type {
  SessionCreate,
  SessionDetail,
  SessionRename,
  SessionSummary,
  SessionUpdate,
} from "@/types/session";

export async function fetchSessions(): Promise<SessionSummary[]> {
  const { data } = await apiClient.get<SessionSummary[]>("/sessions");
  return data;
}

export async function fetchSession(name: string): Promise<SessionDetail> {
  const { data } = await apiClient.get<SessionDetail>(`/sessions/${name}`);
  return data;
}

export async function createSession(data: SessionCreate): Promise<SessionDetail> {
  const response = await apiClient.post<SessionDetail>("/sessions", data);
  return response.data;
}

export async function updateSession(
  name: string,
  data: SessionUpdate,
): Promise<SessionDetail> {
  const response = await apiClient.put<SessionDetail>(`/sessions/${name}`, data);
  return response.data;
}

export async function deleteSession(name: string): Promise<void> {
  await apiClient.delete(`/sessions/${name}`);
}

export async function renameSession(
  name: string,
  data: SessionRename,
): Promise<SessionDetail> {
  const response = await apiClient.patch<SessionDetail>(
    `/sessions/${name}/rename`,
    data,
  );
  return response.data;
}

