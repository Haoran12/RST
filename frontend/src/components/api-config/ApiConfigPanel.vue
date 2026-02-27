<template>
  <section class="api-config-panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">API 配置</div>
      <n-button size="small" type="primary" @click="startCreate">+ 新建</n-button>
    </header>

    <div class="panel-body">
      <div class="config-list">
        <div v-if="store.loading" class="list-loading">
          <n-spin size="small" />
        </div>
        <button
          v-for="config in store.configs"
          :key="config.id"
          class="config-item"
          :class="{ 'is-active': config.id === activeId }"
          type="button"
          @click="selectConfig(config.id)"
        >
          <div class="item-title">{{ config.name }}</div>
          <div class="item-meta">
            <n-tag size="small" type="info" :bordered="false">
              {{ providerLabel(config.provider) }}
            </n-tag>
            <span class="item-model">{{ config.model || "未设置" }}</span>
          </div>
        </button>
        <div v-if="!store.loading && store.configs.length === 0" class="list-empty">
          暂无配置
        </div>
      </div>

      <div v-if="panelMode" class="form-shell">
        <ApiConfigForm
          :mode="panelMode"
          :config="panelMode === 'edit' ? store.currentConfig : null"
          @saved="handleSaved"
          @deleted="handleDeleted"
          @cancel="handleCancel"
        />
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { NButton, NSpin, NTag } from "naive-ui";

import type { ProviderType } from "@/types/api-config";
import { useApiConfigStore } from "@/stores/api-config";

import ApiConfigForm from "./ApiConfigForm.vue";

const store = useApiConfigStore();
const panelMode = ref<"create" | "edit" | null>(null);
const activeId = ref<string | null>(null);

const providerNames: Record<ProviderType, string> = {
  openai: "OpenAI",
  gemini: "Gemini",
  deepseek: "Deepseek",
  anthropic: "Anthropic",
  openai_compat: "OpenAI Compat",
};

onMounted(() => {
  store.loadConfigs();
});

function providerLabel(provider: ProviderType): string {
  return providerNames[provider] ?? provider;
}

function startCreate() {
  panelMode.value = "create";
  activeId.value = null;
  store.currentConfig = null;
}

function selectConfig(id: string) {
  panelMode.value = "edit";
  activeId.value = id;
  store.loadConfig(id);
}

function handleSaved(config: { id: string }) {
  panelMode.value = "edit";
  activeId.value = config.id;
}

function handleDeleted() {
  panelMode.value = null;
  activeId.value = null;
}

function handleCancel() {
  panelMode.value = null;
  activeId.value = null;
}
</script>

<style scoped lang="scss">
.api-config-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 16px;
  color: var(--rst-text-primary);
  background: var(--rst-bg-panel);
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
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin-top: 12px;
  overflow: hidden;
}

.config-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 280px;
  overflow-y: auto;
  padding-right: 4px;
}

.config-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 10px 12px;
  border-radius: 8px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-topbar);
  color: inherit;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.2s ease, background 0.2s ease;
}

.config-item:hover {
  border-color: var(--rst-accent);
}

.config-item.is-active {
  border-color: var(--rst-accent);
  background: rgba(0, 122, 204, 0.2);
}

.item-title {
  font-size: 14px;
  font-weight: 600;
}

.item-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.item-model {
  font-size: 12px;
}

.list-loading {
  display: flex;
  justify-content: center;
  padding: 12px 0;
}

.list-empty {
  font-size: 12px;
  color: var(--rst-text-secondary);
  padding: 8px 0;
}

.form-shell {
  flex: 1;
  overflow-y: auto;
  padding-right: 4px;
}
</style>