import apiClient from "@/api/client";
import type {
  PresetCreate,
  PresetDetail,
  PresetRename,
  PresetSummary,
  PresetUpdate,
} from "@/types/preset";

export async function fetchPresets(): Promise<PresetSummary[]> {
  const { data } = await apiClient.get<PresetSummary[]>("/presets");
  return data;
}

export async function fetchPreset(id: string): Promise<PresetDetail> {
  const { data } = await apiClient.get<PresetDetail>(`/presets/${id}`);
  return data;
}

export async function createPreset(data: PresetCreate): Promise<PresetDetail> {
  const response = await apiClient.post<PresetDetail>("/presets", data);
  return response.data;
}

export async function updatePreset(
  id: string,
  data: PresetUpdate,
): Promise<PresetDetail> {
  const response = await apiClient.put<PresetDetail>(`/presets/${id}`, data);
  return response.data;
}

export async function deletePreset(id: string): Promise<void> {
  await apiClient.delete(`/presets/${id}`);
}

export async function renamePreset(
  id: string,
  data: PresetRename,
): Promise<PresetDetail> {
  const response = await apiClient.patch<PresetDetail>(
    `/presets/${id}/rename`,
    data,
  );
  return response.data;
}

