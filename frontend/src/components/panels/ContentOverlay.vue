<template>
  <div v-if="visible" class="overlay" @click="handleOverlayClick">
    <div class="overlay-card" @click.stop>
      <header class="overlay-header">
        <div class="overlay-title">{{ title }}</div>
        <div v-if="disabledField" class="overlay-header-actions">
          <span class="overlay-header-label">{{ t("contentOverlay.enabled") }}</span>
          <n-switch v-model:value="disabledSwitch" size="small" />
        </div>
      </header>

      <div class="overlay-body">
        <slot name="body-prefix" />

        <div
          v-if="
            (renderedSections.length > 0 || bottomFields.length > 0) &&
            (props.sectionFilterable || props.sectionCollapsible)
          "
          class="section-toolbar"
        >
          <n-input
            v-if="props.sectionFilterable"
            v-model:value="sectionFilterQuery"
            size="small"
            clearable
            :placeholder="sectionFilterPlaceholder"
          />
          <div v-if="props.sectionCollapsible" class="section-toolbar-actions">
            <n-button tertiary size="tiny" @click="expandAllSections">
              {{ t("contentOverlay.section.expand_all") }}
            </n-button>
            <n-button tertiary size="tiny" @click="collapseAllSections">
              {{ t("contentOverlay.section.collapse_all") }}
            </n-button>
          </div>
        </div>

        <div v-if="filteredSections.length > 0" class="section-list">
          <section
            v-for="section in filteredSections"
            :key="section.key"
            class="field-section"
          >
            <div
              v-if="section.title || section.description"
              class="section-header"
              :class="{ 'section-header--toggle': props.sectionCollapsible }"
              @click="props.sectionCollapsible ? toggleSection(section.key) : undefined"
            >
              <div class="section-header-main">
                <div v-if="section.title" class="section-title">{{ section.title }}</div>
                <div v-if="section.description" class="section-description">
                  {{ section.description }}
                </div>
              </div>
              <button
                v-if="props.sectionCollapsible"
                type="button"
                class="section-toggle"
                @click.stop="toggleSection(section.key)"
              >
                <span class="section-count">{{ section.fields.length }}</span>
                <span class="section-arrow" :class="{ collapsed: isSectionCollapsed(section.key) }">⌄</span>
              </button>
            </div>

            <div v-if="!isSectionCollapsed(section.key)" class="field-grid" :style="sectionGridStyle(section)">
              <div
                v-for="field in section.fields"
                :key="field.key"
                class="field-item"
                :class="{
                  'field-item--readonly': field.readonly,
                  'field-item--full': isWideField(field),
                }"
              >
                <label class="field-label">{{ field.label }}</label>
                <div class="field-control">
                  <n-input
                    v-if="field.type === 'text'"
                    v-model:value="fieldValues[field.key] as string"
                    size="small"
                    :disabled="field.readonly"
                    :placeholder="field.placeholder ?? ''"
                  />
                  <n-input
                    v-else-if="field.type === 'textarea'"
                    v-model:value="fieldValues[field.key] as string"
                    size="small"
                    type="textarea"
                    :disabled="field.readonly"
                    :placeholder="field.placeholder ?? ''"
                    :autosize="{ minRows: 3, maxRows: 8 }"
                  />
                  <n-input-number
                    v-else-if="field.type === 'number'"
                    v-model:value="fieldValues[field.key] as number | null"
                    size="small"
                    :disabled="field.readonly"
                    :min="field.min"
                    :max="field.max"
                    :step="field.step ?? 1"
                    :placeholder="field.placeholder ?? ''"
                  />
                  <n-select
                    v-else-if="field.type === 'select'"
                    v-model:value="fieldValues[field.key] as string | number | Array<string | number>"
                    size="small"
                    :options="field.options ?? []"
                    :disabled="field.readonly"
                    :multiple="Boolean(field.multiple)"
                    :filterable="Boolean(field.multiple)"
                    :clearable="true"
                    :max-tag-count="field.multiple ? 'responsive' : undefined"
                  />
                  <n-switch
                    v-else
                    v-model:value="fieldValues[field.key] as boolean"
                    size="small"
                    :disabled="field.readonly"
                  />
                </div>
                <div v-if="field.description" class="field-description">
                  {{ field.description }}
                </div>
              </div>
            </div>
          </section>
        </div>
        <div
          v-else-if="
            props.sectionFilterable && normalizedSectionFilter && filteredBottomFields.length === 0
          "
          class="section-filter-empty"
        >
          {{ t("contentOverlay.section.no_match") }}
        </div>

        <div class="content-section">
          <label class="field-label">{{ contentLabel }}</label>
          <n-input
            v-model:value="contentInput"
            type="textarea"
            :disabled="props.contentReadonly"
            :autosize="{ minRows: 12, maxRows: 24 }"
            :placeholder="contentPlaceholder"
          />
          <div v-if="props.contentReadonly" class="readonly-hint">
            {{ t("contentOverlay.readonly_hint") }}
          </div>
        </div>

        <section v-if="filteredBottomFields.length > 0" class="field-section field-section--bottom">
          <div class="field-grid" style="--overlay-columns: 1">
            <div
              v-for="field in filteredBottomFields"
              :key="field.key"
              class="field-item"
              :class="{
                'field-item--readonly': field.readonly,
                'field-item--full': isWideField(field),
              }"
            >
              <label class="field-label">{{ field.label }}</label>
              <div class="field-control">
                <n-input
                  v-if="field.type === 'text'"
                  v-model:value="fieldValues[field.key] as string"
                  size="small"
                  :disabled="field.readonly"
                  :placeholder="field.placeholder ?? ''"
                />
                <n-input
                  v-else-if="field.type === 'textarea'"
                  v-model:value="fieldValues[field.key] as string"
                  size="small"
                  type="textarea"
                  :disabled="field.readonly"
                  :placeholder="field.placeholder ?? ''"
                  :autosize="{ minRows: 3, maxRows: 8 }"
                />
                <n-input-number
                  v-else-if="field.type === 'number'"
                  v-model:value="fieldValues[field.key] as number | null"
                  size="small"
                  :disabled="field.readonly"
                  :min="field.min"
                  :max="field.max"
                  :step="field.step ?? 1"
                  :placeholder="field.placeholder ?? ''"
                />
                <n-select
                  v-else-if="field.type === 'select'"
                  v-model:value="fieldValues[field.key] as string | number | Array<string | number>"
                  size="small"
                  :options="field.options ?? []"
                  :disabled="field.readonly"
                  :multiple="Boolean(field.multiple)"
                  :filterable="Boolean(field.multiple)"
                  :clearable="true"
                  :max-tag-count="field.multiple ? 'responsive' : undefined"
                />
                <n-switch
                  v-else
                  v-model:value="fieldValues[field.key] as boolean"
                  size="small"
                  :disabled="field.readonly"
                />
              </div>
              <div v-if="field.description" class="field-description">
                {{ field.description }}
              </div>
            </div>
          </div>
        </section>
      </div>

      <footer class="overlay-footer">
        <n-popconfirm
          v-if="props.showDelete"
          :show-icon="false"
          :positive-text="t('contentOverlay.delete.confirm_button')"
          :positive-button-props="{ type: 'error' }"
          @positive-click="emit('delete')"
        >
          <template #trigger>
            <n-button type="error" tertiary>{{
              props.deleteText ?? t("contentOverlay.delete.trigger")
            }}</n-button>
          </template>
          {{ t("contentOverlay.delete.prompt") }}
        </n-popconfirm>
        <div class="footer-actions">
          <n-button type="error" secondary @click="emit('discard')">{{
            t("contentOverlay.actions.discard")
          }}</n-button>
          <n-button type="primary" @click="handleSave">{{ t("contentOverlay.actions.save") }}</n-button>
        </div>
      </footer>
    </div>
  </div>

  <n-modal
    v-model:show="showUnsaved"
    preset="card"
    :title="t('contentOverlay.unsaved.title')"
    size="small"
    :mask-closable="false"
  >
    <div class="unsaved-body">
      {{ t("contentOverlay.unsaved.body") }}
    </div>
    <template #footer>
      <div class="unsaved-actions">
        <n-button secondary @click="handleUnsavedDiscard">{{
          t("contentOverlay.actions.discard")
        }}</n-button>
        <n-button type="primary" @click="handleUnsavedSave">{{ t("contentOverlay.actions.save") }}</n-button>
        <n-button tertiary @click="handleUnsavedBack">{{ t("contentOverlay.unsaved.back") }}</n-button>
      </div>
    </template>
  </n-modal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from "vue";
import {
  NButton,
  NInput,
  NInputNumber,
  NModal,
  NPopconfirm,
  NSelect,
  NSwitch,
  type SelectOption,
} from "naive-ui";

import { useI18n } from "@/composables/useI18n";

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "textarea" | "number" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: SelectOption[];
  multiple?: boolean;
  placeholder?: string;
  description?: string;
  min?: number;
  max?: number;
  step?: number;
  wide?: boolean;
}

interface OverlaySection {
  key: string;
  title?: string;
  description?: string;
  fields: OverlayField[];
  columns?: number;
}

const props = withDefaults(
  defineProps<{
    visible: boolean;
    title: string;
    fields?: OverlayField[];
    sections?: OverlaySection[];
    bottomFieldKeys?: string[];
    sectionCollapsible?: boolean;
    sectionFilterable?: boolean;
    sectionFilterPlaceholder?: string;
    contentValue: string;
    contentReadonly?: boolean;
    contentLabel?: string;
    contentPlaceholder?: string;
    showDelete?: boolean;
    deleteText?: string;
  }>(),
  {
    fields: () => [],
    sections: undefined,
    bottomFieldKeys: () => [],
    sectionCollapsible: false,
    sectionFilterable: false,
    sectionFilterPlaceholder: undefined,
    contentReadonly: false,
    contentLabel: undefined,
    contentPlaceholder: undefined,
    showDelete: false,
    deleteText: undefined,
  },
);

const emit = defineEmits<{
  (e: "save", data: { fields: Record<string, unknown>; content: string }): void;
  (e: "discard"): void;
  (e: "delete"): void;
}>();

const fieldValues = reactive<Record<string, unknown>>({});
const contentInput = ref("");
const showUnsaved = ref(false);
const initialSnapshot = ref("");
const sectionFilterQuery = ref("");
const collapsedSections = reactive<Record<string, boolean>>({});
const { t } = useI18n();

const contentLabel = computed(() => props.contentLabel ?? t("contentOverlay.content.label"));
const contentPlaceholder = computed(
  () => props.contentPlaceholder ?? t("contentOverlay.content.placeholder"),
);
const sectionFilterPlaceholder = computed(
  () => props.sectionFilterPlaceholder ?? t("contentOverlay.section.filter_placeholder"),
);
const normalizedSectionFilter = computed(() => sectionFilterQuery.value.trim().toLowerCase());
const bottomFieldKeySet = computed(() => new Set(props.bottomFieldKeys));

const allFields = computed<OverlayField[]>(() => {
  if (!props.sections || props.sections.length === 0) {
    return props.fields;
  }
  const merged: OverlayField[] = [];
  const seen = new Set<string>();
  props.sections.forEach((section) => {
    section.fields.forEach((field) => {
      if (seen.has(field.key)) {
        return;
      }
      seen.add(field.key);
      merged.push(field);
    });
  });
  props.fields.forEach((field) => {
    if (seen.has(field.key)) {
      return;
    }
    seen.add(field.key);
    merged.push(field);
  });
  return merged;
});

const renderedSections = computed<OverlaySection[]>(() => {
  if (props.sections && props.sections.length > 0) {
    return props.sections
      .map((section) => ({
        ...section,
        fields: section.fields.filter(
          (field) => field.key !== "disabled" && !bottomFieldKeySet.value.has(field.key),
        ),
      }))
      .filter((section) => section.fields.length > 0);
  }

  const baseFields = props.fields.filter(
    (field) =>
      field.key !== "disabled" &&
      field.key !== "comment" &&
      !bottomFieldKeySet.value.has(field.key),
  );
  const commentField = props.fields.find((field) => field.key === "comment");
  const sections: OverlaySection[] = [];

  if (baseFields.length > 0) {
    sections.push({
      key: "main",
      title: t("contentOverlay.section.fields"),
      fields: baseFields,
      columns: 2,
    });
  }
  if (commentField) {
    sections.push({
      key: "comment",
      title: t("contentOverlay.section.comment"),
      fields: [commentField],
      columns: 1,
    });
  }
  return sections;
});

const bottomFields = computed<OverlayField[]>(() =>
  allFields.value.filter(
    (field) => field.key !== "disabled" && bottomFieldKeySet.value.has(field.key),
  ),
);

const filteredSections = computed<OverlaySection[]>(() => {
  const query = normalizedSectionFilter.value;
  if (!query) {
    return renderedSections.value;
  }
  return renderedSections.value
    .map((section) => ({
      ...section,
      fields: section.fields.filter((field) => fieldMatchesFilter(field, query)),
    }))
    .filter((section) => section.fields.length > 0);
});

const filteredBottomFields = computed<OverlayField[]>(() => {
  const query = normalizedSectionFilter.value;
  if (!query) {
    return bottomFields.value;
  }
  return bottomFields.value.filter((field) => fieldMatchesFilter(field, query));
});

const disabledField = computed(
  () => allFields.value.find((field) => field.key === "disabled") ?? null,
);
const isDirty = computed(() => initialSnapshot.value !== buildSnapshot());

const disabledSwitch = computed({
  get: () => {
    if (!disabledField.value) {
      return false;
    }
    return !Boolean(fieldValues[disabledField.value.key]);
  },
  set: (value: boolean) => {
    if (!disabledField.value) {
      return;
    }
    fieldValues[disabledField.value.key] = !value;
  },
});

function fieldMatchesFilter(field: OverlayField, query: string): boolean {
  const candidates: string[] = [
    field.key,
    field.label,
    field.description ?? "",
    field.placeholder ?? "",
  ];

  if (field.options && field.options.length > 0) {
    field.options.forEach((option) => {
      if (typeof option === "object") {
        candidates.push(String(option.label ?? ""));
        candidates.push(String(option.value ?? ""));
      } else {
        candidates.push(String(option));
      }
    });
  }

  const liveValue = fieldValues[field.key];
  if (Array.isArray(liveValue)) {
    candidates.push(liveValue.map((item) => String(item)).join(", "));
  } else if (liveValue !== undefined && liveValue !== null) {
    candidates.push(String(liveValue));
  }

  return candidates.some((item) => item.toLowerCase().includes(query));
}

function resetSectionState() {
  sectionFilterQuery.value = "";
  Object.keys(collapsedSections).forEach((key) => {
    delete collapsedSections[key];
  });
  renderedSections.value.forEach((section) => {
    collapsedSections[section.key] = false;
  });
}

function syncFields() {
  Object.keys(fieldValues).forEach((key) => {
    delete fieldValues[key];
  });
  allFields.value.forEach((field) => {
    fieldValues[field.key] = field.value;
  });
  contentInput.value = props.contentValue;
  resetSectionState();
  initialSnapshot.value = buildSnapshot();
}

watch(
  () => props.visible,
  (visible) => {
    if (visible) {
      syncFields();
    }
  },
  { immediate: true },
);

watch(
  [() => props.fields, () => props.sections],
  () => {
    if (props.visible) {
      syncFields();
    }
  },
  { deep: true },
);

function handleSave() {
  emit("save", { fields: { ...fieldValues }, content: contentInput.value });
}

function buildSnapshot(): string {
  const orderedFields = allFields.value.map((field) => ({
    key: field.key,
    value: fieldValues[field.key],
  }));
  return JSON.stringify({ fields: orderedFields, content: contentInput.value });
}

function isSectionCollapsed(sectionKey: string): boolean {
  if (!props.sectionCollapsible) {
    return false;
  }
  if (normalizedSectionFilter.value) {
    return false;
  }
  return Boolean(collapsedSections[sectionKey]);
}

function toggleSection(sectionKey: string) {
  if (!props.sectionCollapsible) {
    return;
  }
  collapsedSections[sectionKey] = !collapsedSections[sectionKey];
}

function collapseAllSections() {
  if (!props.sectionCollapsible) {
    return;
  }
  renderedSections.value.forEach((section) => {
    collapsedSections[section.key] = true;
  });
}

function expandAllSections() {
  if (!props.sectionCollapsible) {
    return;
  }
  renderedSections.value.forEach((section) => {
    collapsedSections[section.key] = false;
  });
}

function isWideField(field: OverlayField): boolean {
  return Boolean(field.wide) || field.type === "textarea";
}

function sectionGridStyle(section: OverlaySection): Record<string, string> {
  const columns = Math.max(1, Math.min(4, section.columns ?? 2));
  return {
    "--overlay-columns": String(columns),
  };
}

function handleOverlayClick() {
  if (showUnsaved.value) {
    return;
  }
  attemptClose();
}

function attemptClose() {
  if (!isDirty.value) {
    emit("discard");
    return;
  }
  showUnsaved.value = true;
}

function handleUnsavedDiscard() {
  showUnsaved.value = false;
  emit("discard");
}

function handleUnsavedSave() {
  showUnsaved.value = false;
  handleSave();
  emit("discard");
}

function handleUnsavedBack() {
  showUnsaved.value = false;
}
</script>

<style scoped lang="scss">
.overlay {
  position: fixed;
  inset: 0;
  background: var(--rst-overlay-bg, rgba(0, 0, 0, 0.5));
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  z-index: 1200;
}

.overlay-card {
  width: 100%;
  max-width: 860px;
  height: 78vh;
  max-height: 92vh;
  background: var(--rst-bg-panel);
  border-radius: var(--rst-radius-lg);
  border: 1px solid var(--rst-border-color);
  display: flex;
  flex-direction: column;
}

.overlay-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-bottom: 1px solid var(--rst-border-color);
}

.overlay-title {
  font-weight: 600;
}

.overlay-header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.overlay-header-label {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.overlay-body {
  padding: 16px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 14px;
  flex: 1;
}

.section-toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
}

.section-toolbar :deep(.n-input) {
  flex: 1;
}

.section-toolbar-actions {
  display: flex;
  align-items: center;
  gap: 6px;
}

.section-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.field-section {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  padding: 12px;
  background: color-mix(in srgb, var(--rst-bg-topbar) 70%, transparent);
}

.field-section--bottom {
  margin-top: 4px;
}

.section-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 10px;
}

.section-header-main {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.section-header--toggle {
  cursor: pointer;
}

.section-title {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.section-description {
  font-size: 12px;
  color: var(--rst-text-secondary);
  line-height: 1.35;
}

.section-toggle {
  border: 1px solid var(--rst-border-color);
  border-radius: 999px;
  background: transparent;
  color: var(--rst-text-secondary);
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 2px 8px;
  font-size: 11px;
  line-height: 1;
}

.section-arrow {
  display: inline-flex;
  transform: rotate(0deg);
  transition: transform 0.16s ease;
}

.section-arrow.collapsed {
  transform: rotate(-90deg);
}

.section-filter-empty {
  border: 1px dashed var(--rst-border-color);
  border-radius: 10px;
  padding: 12px;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.field-grid {
  display: grid;
  grid-template-columns: repeat(var(--overlay-columns, 2), minmax(0, 1fr));
  gap: 10px 12px;
}

.field-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field-item--full {
  grid-column: 1 / -1;
}

.field-item--readonly {
  opacity: 0.62;
}

.field-label {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.field-control :deep(.n-input-number),
.field-control :deep(.n-select),
.field-control :deep(.n-input) {
  width: 100%;
}

.field-description {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.content-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.content-section :deep(.n-input) {
  flex: 1;
  display: flex;
}

.content-section :deep(textarea) {
  min-height: 260px;
  height: 100%;
}

.readonly-hint {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.overlay-footer {
  padding: 12px 16px 16px;
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
}

.footer-actions {
  display: flex;
  gap: 8px;
}

.unsaved-body {
  font-size: 13px;
  color: var(--rst-text-secondary);
}

.unsaved-actions {
  display: flex;
  gap: 8px;
  justify-content: flex-end;
}

@media (max-width: 720px) {
  .overlay-card {
    max-width: 100%;
    height: 92vh;
  }

  .section-toolbar {
    flex-direction: column;
    align-items: stretch;
  }

  .section-toolbar-actions {
    justify-content: flex-end;
  }

  .field-grid {
    grid-template-columns: 1fr !important;
  }
}
</style>

