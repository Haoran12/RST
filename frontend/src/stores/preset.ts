import { defineStore } from "pinia";
import { ref } from "vue";
import { message } from "@/utils/message";

import type {
  PresetCreate,
  PresetDetail,
  PresetRename,
  PresetSummary,
  PresetUpdate,
} from "@/types/preset";
import { parseApiError } from "@/stores/api-error";
import {
  createPreset,
  deletePreset,
  fetchPreset,
  fetchPresets,
  renamePreset,
  updatePreset,
} from "@/api/presets";

export const usePresetStore = defineStore("preset", () => {
  const presets = ref<PresetSummary[]>([]);
  const currentPreset = ref<PresetDetail | null>(null);
  const loading = ref(false);

  async function loadPresets(): Promise<void> {
    loading.value = true;
    try {
      presets.value = await fetchPresets();
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function loadPreset(id: string): Promise<void> {
    loading.value = true;
    try {
      currentPreset.value = await fetchPreset(id);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function createPresetAction(
    data: PresetCreate,
  ): Promise<PresetDetail | null> {
    loading.value = true;
    try {
      const result = await createPreset(data);
      currentPreset.value = result;
      await loadPresets();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function savePreset(
    id: string,
    data: PresetUpdate,
  ): Promise<PresetDetail | null> {
    loading.value = true;
    try {
      const result = await updatePreset(id, data);
      currentPreset.value = result;
      await loadPresets();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function removePresetAction(id: string): Promise<void> {
    loading.value = true;
    try {
      await deletePreset(id);
      currentPreset.value = null;
      await loadPresets();
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function renamePresetAction(
    id: string,
    data: PresetRename,
  ): Promise<PresetDetail | null> {
    loading.value = true;
    try {
      const result = await renamePreset(id, data);
      currentPreset.value = result;
      await loadPresets();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  return {
    presets,
    currentPreset,
    loading,
    loadPresets,
    loadPreset,
    createPreset: createPresetAction,
    savePreset,
    removePreset: removePresetAction,
    renamePreset: renamePresetAction,
  };
});

