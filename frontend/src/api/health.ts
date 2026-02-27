import apiClient from "@/api/client";

export interface HealthResponse {
  status: string;
}

export const fetchHealth = async (): Promise<HealthResponse> => {
  const response = await apiClient.get<HealthResponse>("/health");
  return response.data;
};
