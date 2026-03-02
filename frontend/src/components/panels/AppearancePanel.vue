<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">{{ t("appearancePanel.title") }}</div>
    </header>

    <div class="panel-body">
      <div class="card">
        <div class="card-title">{{ t("appearancePanel.theme.title") }}</div>
        <n-form size="small" label-placement="top">
          <n-form-item :label="t('appearancePanel.theme.mode_label')">
            <n-select v-model:value="theme" size="small" :options="themeOptions" />
          </n-form-item>
        </n-form>
        <div class="card-hint">{{ t("appearancePanel.theme.hint") }}</div>
      </div>

      <div class="card">
        <div class="card-title">{{ t("appearancePanel.typography.title") }}</div>
        <n-form size="small" label-placement="top">
          <n-form-item :label="t('appearancePanel.typography.font_preset_label')">
            <n-select
              size="small"
              :value="selectedFontPreset"
              :options="fontPresetOptions"
              @update:value="handleFontPresetSelect"
            />
          </n-form-item>
          <n-form-item :label="t('appearancePanel.typography.font_family_label')">
            <n-input
              v-model:value="fontFamily"
              size="small"
              :placeholder="t('appearancePanel.typography.font_family_placeholder')"
            />
          </n-form-item>
          <n-form-item :label="t('appearancePanel.typography.font_scale_label')">
            <div class="scale-control">
              <div class="scale-slider">
                <n-slider
                  v-model:value="fontSizeScale"
                  :min="fontSizeScaleMin"
                  :max="fontSizeScaleMax"
                  :step="fontSizeScaleStep"
                />
              </div>
              <span class="scale-value">{{ fontScalePercent }}</span>
            </div>
          </n-form-item>
        </n-form>
        <div class="card-hint">{{ t("appearancePanel.typography.hint") }}</div>
      </div>

      <div class="card">
        <div class="card-title">{{ t("appearancePanel.markdown.title") }}</div>
        <n-form size="small" label-placement="top">
          <n-form-item :label="t('appearancePanel.markdown.paragraph_label')">
            <div class="color-control">
              <input v-model="markdownParagraphColor" class="color-input" type="color" />
              <span class="color-value">{{ markdownParagraphColor }}</span>
            </div>
          </n-form-item>
          <n-form-item :label="t('appearancePanel.markdown.heading_label')">
            <div class="color-control">
              <input v-model="markdownHeadingColor" class="color-input" type="color" />
              <span class="color-value">{{ markdownHeadingColor }}</span>
            </div>
          </n-form-item>
          <n-form-item :label="t('appearancePanel.markdown.italic_label')">
            <div class="color-control">
              <input v-model="markdownItalicColor" class="color-input" type="color" />
              <span class="color-value">{{ markdownItalicColor }}</span>
            </div>
          </n-form-item>
          <n-form-item :label="t('appearancePanel.markdown.quoted_label')">
            <div class="color-control">
              <input v-model="markdownQuotedColor" class="color-input" type="color" />
              <span class="color-value">{{ markdownQuotedColor }}</span>
            </div>
          </n-form-item>
        </n-form>
        <div class="card-hint">{{ t("appearancePanel.markdown.hint") }}</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { NForm, NFormItem, NInput, NSelect, NSlider } from "naive-ui";

import { useI18n } from "@/composables/useI18n";
import { useAppearanceStore, type ThemeMode } from "@/stores/appearance";

const appearanceStore = useAppearanceStore();
const { t } = useI18n();
const {
  theme,
  fontFamily,
  fontSizeScale,
  markdownParagraphColor,
  markdownHeadingColor,
  markdownItalicColor,
  markdownQuotedColor,
} = storeToRefs(appearanceStore);
const fontSizeScaleMin = appearanceStore.fontSizeScaleMin;
const fontSizeScaleMax = appearanceStore.fontSizeScaleMax;
const fontSizeScaleStep = appearanceStore.fontSizeScaleStep;
const fontPresetValues = [
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  '"Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif',
  '"Noto Sans SC", "Microsoft YaHei", sans-serif',
  '"Source Han Sans SC", "Microsoft YaHei", sans-serif',
  'Georgia, "Times New Roman", serif',
  '"Fira Sans", "Segoe UI", sans-serif',
];
const themeOptions = computed<Array<{ label: string; value: ThemeMode }>>(() => [
  { label: t("topbar.appearance.theme.dark"), value: "dark" },
  { label: t("topbar.appearance.theme.light"), value: "light" },
]);
const fontPresetOptions = computed<Array<{ label: string; value: string }>>(() => [
  {
    label: t("appearancePanel.typography.font_preset.system"),
    value: fontPresetValues[0],
  },
  {
    label: t("appearancePanel.typography.font_preset.segoe"),
    value: fontPresetValues[1],
  },
  {
    label: t("appearancePanel.typography.font_preset.noto"),
    value: fontPresetValues[2],
  },
  {
    label: t("appearancePanel.typography.font_preset.source_han"),
    value: fontPresetValues[3],
  },
  {
    label: t("appearancePanel.typography.font_preset.georgia"),
    value: fontPresetValues[4],
  },
  {
    label: t("appearancePanel.typography.font_preset.fira"),
    value: fontPresetValues[5],
  },
]);
const selectedFontPreset = computed<string | null>(() => {
  const current = fontFamily.value.trim();
  if (!current) {
    return null;
  }
  const matched = fontPresetValues.find((item) => item === current);
  return matched ?? null;
});
const fontScalePercent = computed(() => `${Math.round(fontSizeScale.value * 100)}%`);

function handleFontPresetSelect(value: string | null): void {
  if (!value) {
    return;
  }
  fontFamily.value = value;
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
  display: flex;
  flex-direction: column;
  gap: 12px;
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

.scale-control {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  min-width: 0;
}

.scale-slider {
  flex: 1;
  width: 0;
  min-width: 140px;
}

.scale-slider :deep(.n-slider) {
  width: 100%;
}

.panel-body :deep(.n-form-item) {
  min-width: 0;
}

.panel-body :deep(.n-form-item .n-form-item-blank) {
  min-width: 0;
}

.scale-value {
  min-width: 54px;
  text-align: right;
  font-size: 12px;
  color: var(--rst-text-secondary);
  flex-shrink: 0;
}

.color-control {
  display: flex;
  align-items: center;
  gap: 10px;
}

.color-input {
  width: 36px;
  height: 28px;
  border: 1px solid var(--rst-border-color);
  border-radius: 6px;
  background: transparent;
  cursor: pointer;
}

.color-value {
  min-width: 74px;
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  font-size: 12px;
  color: var(--rst-text-secondary);
}
</style>
