<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">Appearance</div>
    </header>

    <div class="panel-body">
      <div class="card">
        <div class="card-title">Theme</div>
        <n-form size="small" label-placement="top">
          <n-form-item label="Mode">
            <n-select
              v-model:value="theme"
              size="small"
              :options="themeOptions"
            />
          </n-form-item>
        </n-form>
        <div class="card-hint">Switch between Dark and Light modes.</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { storeToRefs } from "pinia";
import { NForm, NFormItem, NSelect } from "naive-ui";

import { useAppearanceStore } from "@/stores/appearance";

const appearanceStore = useAppearanceStore();
const { theme } = storeToRefs(appearanceStore);
const themeOptions = appearanceStore.themeOptions;
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

.card {
  padding: 16px;
  border: 1px solid var(--rst-border-color);
  border-radius: 12px;
  background: var(--rst-bg-panel);
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.card-title {
  font-weight: 600;
}

.card-hint {
  font-size: 12px;
  color: var(--rst-text-secondary);
}
</style>
