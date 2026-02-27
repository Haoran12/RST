<template>
  <div v-if="visible" class="overlay" @click="handleOverlayClick">
    <div class="overlay-card" @click.stop>
      <header class="overlay-header">
        <div class="overlay-title">{{ title }}</div>
        <div class="overlay-header-actions">
          <n-switch
            v-if="disabledField"
            v-model:value="disabledSwitch"
            size="small"
          />
        </div>
      </header>

      <div class="overlay-body">
        <div class="field-grid">
          <div
            v-for="field in mainFields"
            :key="field.key"
            class="field-item"
            :class="{ 'is-readonly': field.readonly }"
          >
            <label class="field-label">{{ field.label }}</label>
            <div class="field-control">
              <n-input
                v-if="field.type === 'text'"
                v-model:value="fieldValues[field.key] as string"
                size="small"
                :disabled="field.readonly"
              />
              <n-select
                v-else-if="field.type === 'select'"
                v-model:value="fieldValues[field.key] as string"
                size="small"
                :options="field.options ?? []"
                :disabled="field.readonly"
              />
              <n-switch
                v-else
                v-model:value="fieldValues[field.key] as boolean"
                size="small"
                :disabled="field.readonly"
              />
            </div>
          </div>
        </div>

        <div class="content-section">
          <label class="field-label">{{ contentLabel }}</label>
          <n-input
            v-model:value="contentInput"
            type="textarea"
            :disabled="props.contentReadonly"
            :autosize="{ minRows: 12, maxRows: 24 }"
            placeholder="请输入内容"
          />
          <div v-if="props.contentReadonly" class="readonly-hint">
            由系统在 Prompt 组装时自动填充
          </div>
        </div>

        <div v-if="commentField" class="comment-section" :class="{ 'is-readonly': commentField.readonly }">
          <label class="field-label">{{ commentField.label }}</label>
          <n-input
            v-model:value="fieldValues[commentField.key] as string"
            size="small"
            :disabled="commentField.readonly"
            placeholder="请输入备注"
          />
        </div>
      </div>

      <footer class="overlay-footer">
        <n-popconfirm
          v-if="props.showDelete"
          :show-icon="false"
          positive-text="确认删除"
          :positive-button-props="{ type: 'error' }"
          @positive-click="emit('delete')"
        >
          <template #trigger>
            <n-button type="error" tertiary>{{ props.deleteText ?? "删除" }}</n-button>
          </template>
          确认删除此条目？
        </n-popconfirm>
        <div class="footer-actions">
          <n-button type="error" secondary @click="emit('discard')">Discard</n-button>
          <n-button type="primary" @click="handleSave">Save</n-button>
        </div>
      </footer>
    </div>
  </div>

  <n-modal
    v-model:show="showUnsaved"
    preset="card"
    title="Unsaved Changes"
    size="small"
    :mask-closable="false"
  >
    <div class="unsaved-body">
      当前编辑内容尚未保存。请选择要执行的操作。
    </div>
    <template #footer>
      <div class="unsaved-actions">
        <n-button secondary @click="handleUnsavedDiscard">Discard</n-button>
        <n-button type="primary" @click="handleUnsavedSave">Save</n-button>
        <n-button tertiary @click="handleUnsavedBack">Back to Editing</n-button>
      </div>
    </template>
  </n-modal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from "vue";
import {
  NButton,
  NInput,
  NModal,
  NPopconfirm,
  NSelect,
  NSwitch,
} from "naive-ui";

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: Array<{ label: string; value: string }>;
}

const props = defineProps<{
  visible: boolean;
  title: string;
  fields: OverlayField[];
  contentValue: string;
  contentReadonly?: boolean;
  contentLabel?: string;
  showDelete?: boolean;
  deleteText?: string;
}>();

const emit = defineEmits<{
  (e: "save", data: { fields: Record<string, unknown>; content: string }): void;
  (e: "discard"): void;
  (e: "delete"): void;
}>();

const fieldValues = reactive<Record<string, unknown>>({});
const contentInput = ref("");
const showUnsaved = ref(false);
const initialSnapshot = ref("");

const contentLabel = computed(() => props.contentLabel ?? "Content");
const isDirty = computed(() => initialSnapshot.value !== buildSnapshot());
const mainFields = computed(() =>
  props.fields.filter((field) => field.key !== "comment" && field.key !== "disabled"),
);
const commentField = computed(() => props.fields.find((field) => field.key === "comment") ?? null);
const disabledField = computed(
  () => props.fields.find((field) => field.key === "disabled") ?? null,
);

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

function syncFields() {
  Object.keys(fieldValues).forEach((key) => {
    delete fieldValues[key];
  });
  props.fields.forEach((field) => {
    fieldValues[field.key] = field.value;
  });
  contentInput.value = props.contentValue;
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
  () => props.fields,
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
  const orderedFields = props.fields.map((field) => ({
    key: field.key,
    value: fieldValues[field.key],
  }));
  return JSON.stringify({ fields: orderedFields, content: contentInput.value });
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
  max-width: 720px;
  height: 70vh;
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

.overlay-header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.overlay-title {
  font-weight: 600;
}

.overlay-body {
  padding: 16px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 16px;
  flex: 1;
}

.field-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 12px;
}

.field-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.field-label {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.content-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 1;
}

.comment-section {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.content-section :deep(.n-input) {
  flex: 1;
  display: flex;
}

.content-section :deep(textarea) {
  min-height: 320px;
  height: 100%;
}

.readonly-hint {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.is-readonly {
  opacity: 0.6;
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
</style>
