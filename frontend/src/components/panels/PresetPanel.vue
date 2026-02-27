<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">Preset</div>
      <SaveIndicator :status="saveStatus" />
    </header>

    <ConfigSelector
      :options="presetOptions"
      :selected-value="selectedId"
      placeholder="选择 Preset..."
      :loading="store.loading"
      :disabled="hasSelection"
      @select="handleSelect"
      @create="startCreate"
      @rename-confirm="handleRename"
      @delete="handleDelete"
    />
    <div class="selector-divider" aria-hidden="true"></div>

    <div class="panel-body">
      <div v-if="createMode" class="card">
        <div class="card-title">新建 Preset</div>
        <n-form size="small" label-placement="top">
          <n-form-item label="名称">
            <n-input v-model:value="createName" placeholder="请输入名称" />
          </n-form-item>
          <div class="card-actions">
            <n-button secondary @click="cancelCreate">取消</n-button>
            <n-button type="primary" @click="submitCreate">创建</n-button>
          </div>
        </n-form>
      </div>

      <div v-else-if="entries.length" class="preset-body">
        <div class="entries-header">
          <div class="entries-title">Entries</div>
          <div class="entries-actions">
            <n-button size="small" type="primary" @click="openNewEntry">+ 添加条目</n-button>
            <n-popconfirm
              :show-icon="false"
              positive-text="确认删除"
              :positive-button-props="{ type: 'error' }"
              @positive-click="handleBulkDelete"
            >
              <template #trigger>
                <n-button
                  size="small"
                  secondary
                  class="entries-action entries-action--danger"
                  :disabled="!hasSelection"
                  aria-label="删除选中条目"
                  title="Delete"
                >
                  <svg class="icon-trash" viewBox="0 0 24 24" aria-hidden="true">
                    <path
                      d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v9h-2V9zm4 0h2v9h-2V9zM7 9h2v9H7V9z"
                      fill="currentColor"
                    />
                  </svg>
                </n-button>
              </template>
              确认删除选中条目？
            </n-popconfirm>
            <n-button
              size="small"
              secondary
              class="entries-action"
              :disabled="copyDisabled"
              aria-label="复制选中条目"
              title="Copy"
              @click="openCopyModal"
            >
              ⧉
            </n-button>
          </div>
        </div>
        <Draggable
          v-model="entries"
          item-key="name"
          handle=".drag-handle"
          class="entries-list"
          @end="handleReorder"
        >
          <template #item="{ element, index }">
            <div
              class="entry-row"
              :class="{ 'is-disabled': element.disabled }"
              @click="openEntry(index)"
            >
              <div class="drag-handle" @click.stop>⋮⋮</div>
              <div class="entry-checkbox" @click.stop>
                <n-checkbox
                  v-if="!isSystemEntry(element)"
                  size="small"
                  :checked="selectedIndexes.includes(index)"
                  @update:checked="(checked) => toggleEntrySelected(index, checked)"
                />
              </div>
              <div class="entry-name">
                <span>{{ element.name }}</span>
                <span v-if="isSystemEntry(element) && element.name !== 'Main_Prompt'" class="lock">🔒</span>
              </div>
              <div class="entry-actions" @click.stop>
                <div class="entry-toggle">
                  <n-switch
                    :value="!element.disabled"
                    @update:value="(value) => handleEntryToggle(element, value)"
                  />
                </div>
              </div>
            </div>
          </template>
        </Draggable>
      </div>

      <div v-else class="empty">
        <div class="empty-icon">📝</div>
        <div>请选择或新建一个 Preset</div>
      </div>
    </div>

    <ContentOverlay
      :visible="overlayVisible"
      :title="overlayTitle"
      :fields="overlayFields"
      :content-value="overlayContent"
      :content-readonly="overlayContentReadonly"
      @save="handleOverlaySave"
      @discard="closeOverlay"
    />

    <n-modal v-model:show="copyModalVisible" preset="card" title="复制到 Preset" size="small">
      <div class="copy-modal-body">
        <n-form size="small" label-placement="top">
          <n-form-item label="目标 Preset">
            <n-select
              v-model:value="copyTargetId"
              :options="copyTargetOptions"
              placeholder="选择目标 Preset"
              :disabled="copyTargetOptions.length === 0"
            />
          </n-form-item>
        </n-form>
        <div v-if="copyTargetOptions.length === 0" class="copy-hint">
          暂无可用的目标 Preset
        </div>
      </div>
      <template #footer>
        <div class="copy-modal-actions">
          <n-button secondary @click="closeCopyModal">取消</n-button>
          <n-button type="primary" :disabled="copyConfirmDisabled" @click="confirmCopy">
            确认复制
          </n-button>
        </div>
      </template>
    </n-modal>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import {
  NButton,
  NCheckbox,
  NForm,
  NFormItem,
  NInput,
  NModal,
  NPopconfirm,
  NSelect,
  NSwitch,
  useMessage,
} from "naive-ui";
import Draggable from "vuedraggable";

import type { PresetEntry } from "@/types/preset";
import { SYSTEM_ENTRIES } from "@/types/preset";
import { usePresetStore } from "@/stores/preset";
import { useSessionStore } from "@/stores/session";
import { fetchPreset, updatePreset } from "@/api/presets";

import ConfigSelector from "@/components/panels/ConfigSelector.vue";
import ContentOverlay from "@/components/panels/ContentOverlay.vue";
import SaveIndicator from "@/components/panels/SaveIndicator.vue";

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: Array<{ label: string; value: string }>;
}

const store = usePresetStore();
const sessionStore = useSessionStore();
const message = useMessage();

const selectedId = ref<string | null>(null);
const createMode = ref(false);
const createName = ref("");
const entries = ref<PresetEntry[]>([]);
const saveStatus = ref<"idle" | "saving" | "saved" | "error">("idle");
let savedTimer: number | undefined;

const overlayVisible = ref(false);
const overlayFields = ref<OverlayField[]>([]);
const overlayContent = ref("");
const overlayContentReadonly = ref(false);
const overlayTitle = ref("");
const editingIndex = ref<number | null>(null);
const editingIsNew = ref(false);
const selectedIndexes = ref<number[]>([]);
const copyModalVisible = ref(false);
const copyTargetId = ref<string | null>(null);

const presetOptions = computed(() =>
  store.presets.map((preset) => ({ label: preset.name, value: preset.id })),
);
const copyTargetOptions = computed(() =>
  store.presets
    .filter((preset) => preset.id !== selectedId.value)
    .map((preset) => ({ label: preset.name, value: preset.id })),
);
const hasSelection = computed(() => selectedIndexes.value.length > 0);
const copyDisabled = computed(() => !hasSelection.value || copyTargetOptions.value.length === 0);
const copyConfirmDisabled = computed(
  () => !hasSelection.value || !copyTargetId.value,
);
const selectedEntries = computed(() =>
  selectedIndexes.value
    .map((index) => entries.value[index])
    .filter((entry): entry is PresetEntry => Boolean(entry)),
);

const roleOptions = [
  { label: "system", value: "system" },
  { label: "user", value: "user" },
  { label: "assistant", value: "assistant" },
];

onMounted(async () => {
  await store.loadPresets();
  await applySessionDefaultPreset();
});

watch(
  () => store.currentPreset,
  (preset) => {
    entries.value = preset ? preset.entries.map((entry) => ({ ...entry })) : [];
    if (preset && selectedId.value !== preset.id) {
      selectedId.value = preset.id;
    }
    saveStatus.value = "idle";
    selectedIndexes.value = [];
  },
  { immediate: true },
);

watch(selectedId, () => {
  overlayVisible.value = false;
  editingIndex.value = null;
  editingIsNew.value = false;
  selectedIndexes.value = [];
});

async function applySessionDefaultPreset() {
  if (createMode.value) {
    return;
  }
  const sessionPresetId = sessionStore.currentSession?.preset_id;
  if (!sessionPresetId) {
    return;
  }
  const exists = store.presets.some((item) => item.id === sessionPresetId);
  if (!exists) {
    return;
  }
  selectedId.value = sessionPresetId;
  if (store.currentPreset?.id !== sessionPresetId) {
    await store.loadPreset(sessionPresetId);
  }
}

function isSystemEntry(entry: PresetEntry): boolean {
  return SYSTEM_ENTRIES.includes(entry.name);
}

function handleSelect(value: string) {
  createMode.value = false;
  selectedId.value = value;
  store.loadPreset(value);
}

function startCreate() {
  createMode.value = true;
  selectedId.value = null;
  store.currentPreset = null;
  createName.value = "";
}

async function submitCreate() {
  if (!createName.value.trim()) {
    message.error("请输入名称");
    return;
  }
  const result = await store.createPreset({ name: createName.value.trim() });
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
  const result = await store.renamePreset(selectedId.value, { new_name: newName });
  if (result) {
    selectedId.value = result.id;
  }
}

async function handleDelete() {
  if (!selectedId.value) {
    return;
  }
  await store.removePreset(selectedId.value);
  selectedId.value = null;
}

function openEntry(index: number) {
  const entry = entries.value[index];
  if (!entry) {
    return;
  }
  editingIndex.value = index;
  editingIsNew.value = false;
  openOverlay(entry, false);
}

function openNewEntry() {
  editingIndex.value = null;
  editingIsNew.value = true;
  openOverlay(
    {
      name: "",
      role: "system",
      content: "",
      disabled: false,
      comment: "",
    },
    true,
  );
}

function openOverlay(entry: PresetEntry, isNew: boolean) {
  const isSystem = isSystemEntry(entry);
  const isMainPrompt = entry.name === "Main_Prompt";

  overlayTitle.value = isNew ? "+新建条目" : `编辑: ${entry.name}`;
  overlayContent.value = entry.content;
  overlayContentReadonly.value = isSystem && !isMainPrompt;
  overlayFields.value = [
    {
      key: "name",
      label: "Name",
      type: "text",
      value: entry.name,
      readonly: isSystem,
    },
    {
      key: "role",
      label: "Role",
      type: "select",
      value: entry.role,
      readonly: isSystem,
      options: roleOptions,
    },
    {
      key: "disabled",
      label: "Disabled",
      type: "toggle",
      value: entry.disabled,
    },
    {
      key: "comment",
      label: "Comment",
      type: "text",
      value: entry.comment,
    },
  ];
  overlayVisible.value = true;
}

function closeOverlay() {
  overlayVisible.value = false;
  editingIndex.value = null;
  editingIsNew.value = false;
}

async function handleOverlaySave(data: { fields: Record<string, unknown>; content: string }) {
  const name = String(data.fields.name ?? "").trim();
  const role = String(data.fields.role ?? "system");
  const disabled = Boolean(data.fields.disabled);
  const comment = String(data.fields.comment ?? "");

  if (editingIsNew.value && !name) {
    message.error("请输入条目名称");
    return;
  }

  const updatedEntry: PresetEntry = {
    name,
    role: role as PresetEntry["role"],
    content: data.content,
    disabled,
    comment,
  };

  let nextEntries = [...entries.value];
  if (editingIsNew.value) {
    nextEntries.push(updatedEntry);
  } else if (editingIndex.value !== null) {
    nextEntries[editingIndex.value] = updatedEntry;
  }

  await persistEntries(nextEntries);
  closeOverlay();
}

async function saveEntries() {
  await persistEntries(entries.value);
}

function handleEntryToggle(entry: PresetEntry, enabled: boolean) {
  entry.disabled = !enabled;
  void saveEntries();
}

async function handleReorder() {
  selectedIndexes.value = [];
  await persistEntries(entries.value);
}

async function persistEntries(nextEntries: PresetEntry[]) {
  if (!selectedId.value) {
    return;
  }
  saveStatus.value = "saving";
  const result = await store.savePreset(selectedId.value, { entries: nextEntries });
  if (result) {
    entries.value = result.entries.map((entry) => ({ ...entry }));
    saveStatus.value = "saved";
    if (savedTimer) {
      window.clearTimeout(savedTimer);
    }
    savedTimer = window.setTimeout(() => {
      saveStatus.value = "idle";
    }, 1000);
  } else {
    saveStatus.value = "error";
  }
}

function toggleEntrySelected(index: number, checked: boolean) {
  if (checked) {
    if (!selectedIndexes.value.includes(index)) {
      selectedIndexes.value = [...selectedIndexes.value, index];
    }
  } else {
    selectedIndexes.value = selectedIndexes.value.filter((i) => i !== index);
  }
}

async function handleBulkDelete() {
  if (!hasSelection.value) {
    return;
  }
  const toDelete = new Set(selectedIndexes.value);
  const nextEntries = entries.value.filter((_, idx) => !toDelete.has(idx));
  await persistEntries(nextEntries);
  selectedIndexes.value = [];
}

function openCopyModal() {
  if (copyDisabled.value) {
    return;
  }
  copyTargetId.value = copyTargetOptions.value[0]?.value ?? null;
  copyModalVisible.value = true;
}

function closeCopyModal() {
  copyModalVisible.value = false;
  copyTargetId.value = null;
}

async function confirmCopy() {
  if (!copyTargetId.value || !hasSelection.value) {
    return;
  }
  try {
    const targetPreset = await fetchPreset(copyTargetId.value);
    const appendedEntries = selectedEntries.value.map((entry) => ({ ...entry }));
    await updatePreset(copyTargetId.value, {
      entries: [...targetPreset.entries, ...appendedEntries],
    });
    message.success("已复制到目标 Preset");
    closeCopyModal();
  } catch (_error) {
    message.error("复制失败，请稍后重试");
  }
}
</script>

<style scoped lang="scss">
.panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 16px;
  color: var(--rst-text-primary);
  position: relative;
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

.selector-divider {
  margin-top: 12px;
  border-top: 1px solid var(--rst-border-color);
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

.preset-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.entries-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  position: sticky;
  top: 0;
  z-index: 2;
  padding: 6px 0 10px;
  background: var(--rst-bg-panel);
}

.entries-title {
  font-weight: 600;
}

.entries-actions {
  display: flex;
  align-items: center;
  gap: 6px;
}

.entries-action {
  min-width: 34px;
  padding: 0 8px;
}

.entries-action--danger {
  --n-text-color: var(--rst-text-secondary);
  --n-text-color-hover: var(--rst-danger);
  --n-border-color-hover: var(--rst-danger);
  --n-text-color-pressed: var(--rst-danger);
  --n-border-color-pressed: var(--rst-danger);
  --n-color-hover: color-mix(in srgb, var(--rst-danger) 16%, transparent);
  --n-color-pressed: color-mix(in srgb, var(--rst-danger) 24%, transparent);
}

.entries-action--danger:not(:disabled):hover {
  color: var(--rst-danger);
}

.icon-trash {
  width: 16px;
  height: 16px;
  display: block;
}

.entries-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.entry-row {
  display: grid;
  grid-template-columns: 24px 22px 1fr auto;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--rst-border-color);
  border-radius: 8px;
  background: var(--rst-bg-topbar);
  cursor: pointer;
}

.entry-row:hover {
  border-color: var(--rst-accent);
}

.entry-row.is-disabled {
  opacity: 0.45;
}

.drag-handle {
  cursor: grab;
  color: var(--rst-text-secondary);
}

.entry-checkbox {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 24px;
}

.entry-name {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
}

.lock {
  font-size: 12px;
  opacity: 0.7;
}

.entry-toggle {
  display: flex;
  align-items: center;
}

.entry-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.copy-modal-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.copy-modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.copy-hint {
  font-size: 12px;
  color: var(--rst-text-secondary);
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
</style>
