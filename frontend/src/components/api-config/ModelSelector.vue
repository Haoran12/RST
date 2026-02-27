<template>
  <div class="model-selector">
    <div class="model-actions">
      <n-button
        class="model-fetch-button"
        size="small"
        @click="handleFetch"
        :disabled="!configId"
      >
        获取模型列表
      </n-button>
      <span v-if="!configId" class="model-tip">请先保存配置后获取模型列表</span>
    </div>

    <n-alert v-if="errorMessage" type="warning" :bordered="false" class="model-alert">
      {{ errorMessage }}
    </n-alert>

    <n-select
      v-if="models.length > 0"
      class="model-select"
      :options="modelOptions"
      :value="modelValue"
      placeholder="选择模型"
      :menu-props="{ style: { maxHeight: '360px' } }"
      @update:value="handleSelect"
    />

    <n-input
      class="manual-input"
      :value="modelValue"
      placeholder="手动输入模型名称"
      @update:value="emitUpdate"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { NAlert, NButton, NInput, NSelect } from "naive-ui";

import { useApiConfigStore } from "@/stores/api-config";

const props = defineProps<{
  modelValue: string;
  configId: string | null;
}>();

const emit = defineEmits<{
  (event: "update:modelValue", value: string): void;
}>();

const store = useApiConfigStore();
const models = ref<string[]>([]);
const errorMessage = ref<string | null>(null);

const modelOptions = computed(() =>
  models.value.map((model) => ({ label: model, value: model })),
);

watch(
  () => props.configId,
  () => {
    models.value = [];
    errorMessage.value = null;
  },
);

function emitUpdate(value: string) {
  emit("update:modelValue", value);
}

function handleSelect(value: string) {
  emitUpdate(value);
}

async function handleFetch() {
  if (!props.configId) {
    return;
  }
  const response = await store.loadModels(props.configId);
  if (!response) {
    return;
  }
  models.value = response.models;
  errorMessage.value = response.error ?? null;
}
</script>

<style scoped lang="scss">
.model-selector {
  display: flex;
  flex-direction: column;
  gap: 10px;
  width: 150%;
  max-width: none;
  overflow: visible;
}

.model-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.model-tip {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.model-alert {
  font-size: 12px;
}

.model-fetch-button {
  --n-color: var(--rst-accent);
  --n-color-hover: var(--rst-accent);
  --n-color-pressed: var(--rst-accent);
  --n-border: 1px solid var(--rst-accent);
  --n-border-hover: 1px solid var(--rst-accent);
  --n-border-pressed: 1px solid var(--rst-accent);
  --n-text-color: var(--rst-text-primary);
  --n-text-color-hover: var(--rst-text-primary);
  --n-text-color-pressed: var(--rst-text-primary);
}

.manual-input {
  width: 100%;
}

@media (max-width: 900px) {
  .model-selector {
    width: 100%;
  }
}
</style>
