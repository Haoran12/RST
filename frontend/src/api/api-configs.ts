import apiClient from "@/api/client";
import type {
  ApiConfigCreate,
  ApiConfigDetail,
  ApiConfigSummary,
  ApiConfigUpdate,
  ModelListResponse,
} from "@/types/api-config";

export async function fetchApiConfigs(): Promise<ApiConfigSummary[]> {
  const { data } = await apiClient.get<ApiConfigSummary[]>("/api-configs");
  return data;
}

export async function fetchApiConfig(id: string): Promise<ApiConfigDetail> {
  const { data } = await apiClient.get<ApiConfigDetail>(`/api-configs/${id}`);
  return data;
}

export async function createApiConfig(data: ApiConfigCreate): Promise<ApiConfigDetail> {
  const response = await apiClient.post<ApiConfigDetail>("/api-configs", data);
  return response.data;
}

export async function updateApiConfig(
  id: string,
  data: ApiConfigUpdate,
): Promise<ApiConfigDetail> {
  const response = await apiClient.put<ApiConfigDetail>(`/api-configs/${id}`, data);
  return response.data;
}

export async function deleteApiConfig(id: string): Promise<void> {
  await apiClient.delete(`/api-configs/${id}`);
}

export async function fetchModels(id: string): Promise<ModelListResponse> {
  const { data } = await apiClient.get<ModelListResponse>(`/api-configs/${id}/models`);
  return data;
}
