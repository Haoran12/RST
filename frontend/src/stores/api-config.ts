import { defineStore } from "pinia";
import { ref } from "vue";
import { message } from "@/utils/message";

import type {
  ApiConfigCreate,
  ApiConfigDetail,
  ApiConfigSummary,
  ApiConfigUpdate,
  ModelListResponse,
} from "@/types/api-config";
import { parseApiError } from "@/stores/api-error";
import {
  createApiConfig,
  deleteApiConfig,
  fetchApiConfig,
  fetchApiConfigs,
  fetchModels,
  updateApiConfig,
} from "@/api/api-configs";

export const useApiConfigStore = defineStore("api-config", () => {
  const configs = ref<ApiConfigSummary[]>([]);
  const currentConfig = ref<ApiConfigDetail | null>(null);
  const loading = ref(false);

  async function loadConfigs(): Promise<void> {
    loading.value = true;
    try {
      configs.value = await fetchApiConfigs();
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function loadConfig(id: string): Promise<void> {
    loading.value = true;
    try {
      currentConfig.value = await fetchApiConfig(id);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function createConfig(data: ApiConfigCreate): Promise<ApiConfigDetail | null> {
    loading.value = true;
    try {
      const result = await createApiConfig(data);
      currentConfig.value = result;
      await loadConfigs();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function saveConfig(
    id: string,
    data: ApiConfigUpdate,
  ): Promise<ApiConfigDetail | null> {
    loading.value = true;
    try {
      const result = await updateApiConfig(id, data);
      currentConfig.value = result;
      await loadConfigs();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function renameConfig(id: string, newName: string): Promise<ApiConfigDetail | null> {
    return saveConfig(id, { name: newName });
  }

  async function removeConfig(id: string): Promise<void> {
    loading.value = true;
    try {
      await deleteApiConfig(id);
      currentConfig.value = null;
      await loadConfigs();
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function loadModels(id: string): Promise<ModelListResponse | null> {
    loading.value = true;
    try {
      return await fetchModels(id);
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  return {
    configs,
    currentConfig,
    loading,
    loadConfigs,
    loadConfig,
    createConfig,
    saveConfig,
    renameConfig,
    removeConfig,
    loadModels,
  };
});

