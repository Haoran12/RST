<template>
  <div class="api-config-form">
    <div v-if="mode === 'edit' && !config" class="form-loading">
      <n-spin size="small" />
    </div>
    <n-form v-else size="small" label-placement="top">
      <n-form-item label="名称">
        <n-input v-model:value="formState.name" placeholder="配置名称" />
      </n-form-item>

      <n-form-item label="Provider">
        <n-select
          v-model:value="formState.provider"
          :options="providerOptions"
          placeholder="选择 Provider"
        />
      </n-form-item>

      <n-form-item label="Base URL">
        <n-input v-model:value="formState.base_url" placeholder="https://..." />
      </n-form-item>

      <n-form-item label="API Key">
        <n-input
          v-model:value="apiKeyInput"
          type="password"
          :placeholder="apiKeyPlaceholder"
          show-password-on="click"
        />
      </n-form-item>

      <n-form-item label="Model">
        <ModelSelector v-model="formState.model" :config-id="config?.id ?? null" />
      </n-form-item>

      <n-form-item label="Temperature">
        <div class="slider-row">
          <n-slider v-model:value="formState.temperature" :min="0" :max="2" :step="0.1" />
          <n-input-number v-model:value="formState.temperature" :min="0" :max="2" :step="0.1" />
        </div>
      </n-form-item>

      <n-form-item label="Max Tokens">
        <n-input-number v-model:value="formState.max_tokens" :min="1" :max="1000000" />
      </n-form-item>

      <n-form-item label="Stream">
        <n-switch v-model:value="formState.stream" />
      </n-form-item>

      <div class="form-actions">
        <n-button type="primary" :loading="saving" @click="handleSave">保存</n-button>
        <n-button secondary @click="$emit('cancel')">取消</n-button>
        <n-popconfirm
          v-if="mode === 'edit' && config"
          positive-text="确认删除"
          :positive-button-props="{ type: 'error' }"
          @positive-click="handleDelete"
        >
          <template #trigger>
            <n-button tertiary type="error">删除</n-button>
          </template>
          确认删除该配置？
        </n-popconfirm>
      </div>
    </n-form>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from "vue";
import {
  NButton,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NPopconfirm,
  NSelect,
  NSlider,
  NSpin,
  NSwitch,
  useMessage,
} from "naive-ui";

import {
  DEFAULT_BASE_URLS,
  type ApiConfigCreate,
  type ApiConfigDetail,
  type ProviderType,
  type ApiConfigUpdate,
} from "@/types/api-config";
import { useApiConfigStore } from "@/stores/api-config";

import ModelSelector from "./ModelSelector.vue";

const props = defineProps<{
  mode: "create" | "edit";
  config: ApiConfigDetail | null;
}>();

const emit = defineEmits<{
  (event: "saved", config: ApiConfigDetail): void;
  (event: "cancel"): void;
  (event: "deleted"): void;
}>();

const store = useApiConfigStore();
const saving = ref(false);
const apiKeyInput = ref("");
const lastProvider = ref<ProviderType>("openai");
const message = useMessage();

const formState = reactive({
  name: "",
  provider: "openai" as ProviderType,
  base_url: DEFAULT_BASE_URLS.openai,
  model: "",
  temperature: 0.7,
  max_tokens: 4096,
  stream: true,
});

const providerOptions = [
  { label: "OpenAI", value: "openai" },
  { label: "Gemini", value: "gemini" },
  { label: "Deepseek", value: "deepseek" },
  { label: "Anthropic", value: "anthropic" },
  { label: "OpenAI Compat", value: "openai_compat" },
];

const apiKeyPlaceholder = computed(() => {
  if (props.mode === "edit" && props.config) {
    return props.config.api_key_preview;
  }
  return "请输入 API Key";
});

watch(
  () => props.config,
  (config) => {
    if (!config) {
      if (props.mode === "create") {
        formState.name = "";
        formState.provider = "openai";
        formState.base_url = DEFAULT_BASE_URLS.openai;
        formState.model = "";
        formState.temperature = 0.7;
        formState.max_tokens = 4096;
        formState.stream = true;
        apiKeyInput.value = "";
        lastProvider.value = "openai";
      }
      return;
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

async function handleSave() {
  if (!formState.name.trim()) {
    message.error("请输入配置名称");
    return;
  }
  if (props.mode === "create" && !apiKeyInput.value.trim()) {
    message.error("请输入 API Key");
    return;
  }
  if (formState.provider === "openai_compat" && !formState.base_url.trim()) {
    message.error("请输入 Base URL");
    return;
  }
  saving.value = true;
  const payload: ApiConfigCreate & { id?: string } = {
    name: formState.name.trim(),
    provider: formState.provider,
    model: formState.model.trim(),
    temperature: formState.temperature,
    max_tokens: formState.max_tokens,
    stream: formState.stream,
    api_key: apiKeyInput.value.trim() || "",
  };

  if (!apiKeyInput.value.trim()) {
    delete (payload as ApiConfigUpdate).api_key;
  }
  if (formState.base_url.trim()) {
    payload.base_url = formState.base_url.trim();
  }

  let result: ApiConfigDetail | null = null;
  if (props.mode === "edit" && props.config) {
    result = await store.saveConfig(props.config.id, payload as ApiConfigUpdate);
  } else {
    result = await store.createConfig(payload as ApiConfigCreate);
  }
  saving.value = false;
  if (result) {
    emit("saved", result);
  }
}

async function handleDelete() {
  if (!props.config) {
    return;
  }
  await store.removeConfig(props.config.id);
  emit("deleted");
}
</script>

<style scoped lang="scss">
.api-config-form {
  padding: 12px;
  border-radius: 12px;
  background: var(--rst-bg-topbar);
  border: 1px solid var(--rst-border-color);
}

.slider-row {
  display: grid;
  grid-template-columns: 1fr 110px;
  gap: 12px;
  align-items: center;
}

.form-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}

.form-loading {
  display: flex;
  justify-content: center;
  padding: 16px 0;
}
</style>

