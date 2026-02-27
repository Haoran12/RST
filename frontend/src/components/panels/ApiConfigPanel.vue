<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">API Config</div>
      <SaveIndicator :status="saveStatus" />
    </header>

    <ConfigSelector
      :options="configOptions"
      :selected-value="selectedId"
      placeholder="选择配置..."
      :loading="store.loading"
      @select="handleSelect"
      @create="startCreate"
      @rename-confirm="handleRename"
      @delete="handleDelete"
    />

    <div class="panel-body">
      <div v-if="createMode" class="card">
        <div class="card-title">新建 API 配置</div>
        <n-form size="small" label-placement="top">
          <n-form-item label="名称">
            <n-input v-model:value="createForm.name" placeholder="请输入配置名称" />
          </n-form-item>
          <n-form-item label="Provider">
            <n-select v-model:value="createForm.provider" :options="providerOptions" />
          </n-form-item>
          <n-form-item label="API Key">
            <n-input
              v-model:value="createForm.api_key"
              type="password"
              show-password-on="click"
              placeholder="请输入 API Key"
            />
          </n-form-item>
          <div class="card-actions">
            <n-button secondary @click="cancelCreate">取消</n-button>
            <n-button type="primary" @click="submitCreate">创建</n-button>
          </div>
        </n-form>
      </div>

      <div v-else-if="store.currentConfig" class="form">
        <n-form size="small" label-placement="top">
          <n-form-item label="名称">
            <n-input v-model:value="formState.name" @blur="flush" />
          </n-form-item>
          <n-form-item label="Provider">
            <n-select
              v-model:value="formState.provider"
              :options="providerOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item label="Base URL">
            <n-input v-model:value="formState.base_url" @blur="flush" />
          </n-form-item>
          <n-form-item label="API Key">
            <n-input
              v-model:value="apiKeyInput"
              type="password"
              :placeholder="apiKeyPlaceholder"
              show-password-on="click"
              @blur="handleApiKeyBlur"
            />
          </n-form-item>
          <n-form-item label="Model">
            <ModelSelector
              v-model:modelValue="formState.model"
              :config-id="selectedId"
              @update:modelValue="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item label="Temperature">
            <div class="slider-row">
              <n-slider
                v-model:value="formState.temperature"
                :min="0"
                :max="2"
                :step="0.05"
                @update:value="handleImmediateSave"
              />
              <n-input-number
                v-model:value="formState.temperature"
                :min="0"
                :max="2"
                :step="0.05"
                :precision="2"
                @blur="flush"
              />
            </div>
          </n-form-item>
          <n-form-item label="Max Tokens">
            <div class="slider-row">
              <n-slider
                v-model:value="formState.max_tokens"
                :min="1"
                :max="1000000"
                :step="1"
                @update:value="handleImmediateSave"
              />
              <n-input-number
                v-model:value="formState.max_tokens"
                :min="1"
                :max="1000000"
                :step="1"
                :precision="0"
                @blur="flush"
              />
            </div>
          </n-form-item>
          <n-form-item label="Stream">
            <n-switch v-model:value="formState.stream" @update:value="handleImmediateSave" />
          </n-form-item>
        </n-form>
      </div>

      <div v-else class="empty">
        <div class="empty-icon">??</div>
        <div>请选择或新建一个配置</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from "vue";
import {
  NButton,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NSelect,
  NSlider,
  NSwitch,
  useMessage,
} from "naive-ui";

import { DEFAULT_BASE_URLS, type ProviderType } from "@/types/api-config";
import { useApiConfigStore } from "@/stores/api-config";
import { useAutoSave } from "@/composables/useAutoSave";

import ConfigSelector from "@/components/panels/ConfigSelector.vue";
import SaveIndicator from "@/components/panels/SaveIndicator.vue";
import ModelSelector from "@/components/api-config/ModelSelector.vue";

const store = useApiConfigStore();
const message = useMessage();

const selectedId = ref<string | null>(null);
const createMode = ref(false);
const syncing = ref(false);
const apiKeyInput = ref("");
const lastProvider = ref<ProviderType>("openai");

const providerOptions = [
  { label: "OpenAI", value: "openai" },
  { label: "Gemini", value: "gemini" },
  { label: "Deepseek", value: "deepseek" },
  { label: "Anthropic", value: "anthropic" },
  { label: "OpenAI Compat", value: "openai_compat" },
];

const formState = reactive({
  name: "",
  provider: "openai" as ProviderType,
  base_url: DEFAULT_BASE_URLS.openai,
  model: "",
  temperature: 0.7,
  max_tokens: 4096,
  stream: true,
});

const createForm = reactive({
  name: "",
  provider: "openai" as ProviderType,
  api_key: "",
});

const configOptions = computed(() =>
  store.configs.map((config) => ({
    label: config.name,
    value: config.id,
  })),
);

const apiKeyPlaceholder = computed(() => {
  if (store.currentConfig) {
    return store.currentConfig.api_key_preview;
  }
  return "请输入 API Key";
});

const { saveStatus, markDirty, flush, cancel } = useAutoSave({
  saveFn: async () => {
    if (!selectedId.value || !store.currentConfig) {
      return;
    }
    if (!formState.name.trim()) {
      return;
    }
    const payload = {
      name: formState.name.trim(),
      provider: formState.provider,
      base_url: formState.base_url.trim(),
      model: formState.model.trim(),
      temperature: formState.temperature,
      max_tokens: formState.max_tokens,
      stream: formState.stream,
    };
    if (apiKeyInput.value.trim()) {
      Object.assign(payload, { api_key: apiKeyInput.value.trim() });
    }
    await store.saveConfig(selectedId.value, payload);
    apiKeyInput.value = "";
  },
  delay: 300,
});

onMounted(() => {
  store.loadConfigs();
});

watch(
  () => store.currentConfig,
  (config) => {
    syncing.value = true;
    if (config) {
      if (selectedId.value !== config.id) {
        selectedId.value = config.id;
      }
      formState.name = config.name;
      formState.provider = config.provider;
      formState.base_url = config.base_url;
      formState.model = config.model;
      formState.temperature = config.temperature;
      formState.max_tokens = config.max_tokens;
      formState.stream = config.stream;
      apiKeyInput.value = "";
      lastProvider.value = config.provider;
    }
    syncing.value = false;
  },
  { immediate: true },
);

watch(
  () => formState.provider,
  (provider) => {
    const previousDefault = DEFAULT_BASE_URLS[lastProvider.value];
    if (!formState.base_url || formState.base_url === previousDefault) {
      formState.base_url = DEFAULT_BASE_URLS[provider];
    }
    lastProvider.value = provider;
  },
);

watch(
  formState,
  () => {
    if (syncing.value || createMode.value || !store.currentConfig) {
      return;
    }
    markDirty();
  },
  { deep: true },
);

watch(apiKeyInput, () => {
  if (syncing.value || createMode.value || !store.currentConfig) {
    return;
  }
  if (apiKeyInput.value.trim()) {
    markDirty();
  }
});

watch(selectedId, () => {
  cancel();
});

function handleSelect(value: string) {
  createMode.value = false;
  selectedId.value = value;
  store.loadConfig(value);
}

function startCreate() {
  createMode.value = true;
  selectedId.value = null;
  store.currentConfig = null;
  createForm.name = "";
  createForm.provider = "openai";
  createForm.api_key = "";
}

async function submitCreate() {
  if (!createForm.name.trim()) {
    message.error("请输入配置名称");
    return;
  }
  if (!createForm.api_key.trim()) {
    message.error("请输入 API Key");
    return;
  }
  const result = await store.createConfig({
    name: createForm.name.trim(),
    provider: createForm.provider,
    api_key: createForm.api_key.trim(),
  });
  if (result) {
    createMode.value = false;
    selectedId.value = result.id;
  }
}

function cancelCreate() {
  createMode.value = false;
}

async function handleRename(newName: string) {
  if (!selectedId.value) {
    return;
  }
  const result = await store.renameConfig(selectedId.value, newName);
  if (result) {
    selectedId.value = result.id;
  }
}

async function handleDelete() {
  if (!selectedId.value) {
    return;
  }
  await store.removeConfig(selectedId.value);
  selectedId.value = null;
}

function handleImmediateSave() {
  if (!selectedId.value) {
    return;
  }
  markDirty();
  void flush();
}

function handleApiKeyBlur() {
  if (!selectedId.value) {
    return;
  }
  if (!apiKeyInput.value.trim()) {
    apiKeyInput.value = "";
    return;
  }
  markDirty();
  void flush();
}
</script>

<style scoped lang="scss">
.panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 16px;
  color: var(--rst-text-primary);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--rst-border-color);
}

.panel-title {
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.panel-body {
  margin-top: 12px;
  flex: 1;
  overflow-y: auto;
}

.form {
  width: 100%;
}

.card {
  padding: 16px;
  border: 1px solid var(--rst-accent);
  border-radius: 12px;
  background: var(--rst-bg-topbar);
}

.card-title {
  font-weight: 600;
  margin-bottom: 8px;
}

.card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 8px;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--rst-text-secondary);
  height: 100%;
  text-align: center;
}

.empty-icon {
  font-size: 24px;
}

.slider-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 110px;
  gap: 12px;
  align-items: center;
  width: 100%;
}

.slider-row :deep(.n-slider) {
  width: 100%;
  min-width: 0;
  padding: 8px 0;
  --n-rail-height: 4px;
  --n-rail-color: var(--rst-border-color);
  --n-fill-color: var(--rst-accent);
  --n-handle-size: 14px;
}

.slider-row :deep(.n-slider-rail) {
  height: 4px;
  background: var(--rst-border-color);
  border-radius: 999px;
}

.slider-row :deep(.n-slider-rail__fill) {
  background: var(--rst-accent);
  border-radius: 999px;
}
</style>

