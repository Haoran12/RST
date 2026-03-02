<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">{{ t("sessionPanel.title") }}</div>
      <SaveIndicator :status="saveStatus" />
    </header>

    <ConfigSelector
      :options="sessionOptions"
      :selected-value="selectedName"
      :placeholder="t('sessionPanel.selector.placeholder')"
      :loading="store.loading"
      @select="handleSelect"
      @create="startCreate"
      @rename-confirm="handleRename"
      @delete="handleDelete"
    />
    <div class="selector-divider" aria-hidden="true"></div>

    <div class="panel-body">
      <div v-if="createMode" class="card">
        <div class="card-title">{{ t("sessionPanel.create.title") }}</div>
        <n-form size="small" label-placement="top">
          <n-form-item :label="t('sessionPanel.fields.name')">
            <n-input
              v-model:value="createForm.name"
              :placeholder="t('sessionPanel.create.name_placeholder')"
            />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.mode')">
            <n-select v-model:value="createForm.mode" :options="modeOptions" />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.main_api')">
            <n-select
              v-model:value="createForm.main_api_config_id"
              :options="apiOptions"
              :placeholder="t('sessionPanel.create.main_api_placeholder')"
            />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.preset')">
            <n-select
              v-model:value="createForm.preset_id"
              :options="presetOptions"
              :placeholder="t('sessionPanel.create.preset_placeholder')"
            />
          </n-form-item>
          <div class="card-actions">
            <n-button secondary @click="cancelCreate">{{ t("common.cancel") }}</n-button>
            <n-button type="primary" @click="submitCreate">{{ t("common.create") }}</n-button>
          </div>
        </n-form>
      </div>

      <div v-else-if="store.currentSession" class="form">
        <n-form size="small" label-placement="top">
          <n-form-item :label="t('sessionPanel.fields.mode')">
            <n-select
              v-model:value="formState.mode"
              :options="modeOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.main_api')">
            <n-select
              v-model:value="formState.main_api_config_id"
              :options="apiOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.scheduler_api')">
            <n-select
              v-model:value="formState.scheduler_api_config_id"
              :options="apiOptions"
              clearable
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.preset')">
            <n-select
              v-model:value="formState.preset_id"
              :options="presetOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.scan_depth')">
            <div class="slider-row">
              <n-slider
                v-model:value="formState.scan_depth"
                :min="-1"
                :max="40"
                :step="1"
                :format-tooltip="formatDepthTooltip"
                @update:value="handleSliderUpdate('scan_depth')"
                @change="handleSliderCommit('scan_depth', $event)"
              />
              <n-input-number
                v-model:value="formState.scan_depth"
                :min="-1"
                :max="40"
                :step="1"
                :precision="0"
                @blur="handleNumericBlur('scan_depth')"
              />
            </div>
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.mem_length')">
            <div class="slider-row">
              <n-slider
                v-model:value="formState.mem_length"
                :min="-1"
                :max="400"
                :step="5"
                :format-tooltip="formatMemTooltip"
                @update:value="handleSliderUpdate('mem_length')"
                @change="handleSliderCommit('mem_length', $event)"
              />
              <n-input-number
                v-model:value="formState.mem_length"
                :min="-1"
                :max="400"
                :step="5"
                :precision="0"
                @blur="handleNumericBlur('mem_length')"
              />
            </div>
          </n-form-item>
          <n-form-item :label="t('sessionPanel.fields.lore_sync_interval')">
            <div class="slider-row">
              <n-slider
                v-model:value="formState.lore_sync_interval"
                :min="1"
                :max="syncIntervalUpperBound"
                :step="1"
                @update:value="handleSliderUpdate('lore_sync_interval')"
                @change="handleSliderCommit('lore_sync_interval', $event)"
              />
              <n-input-number
                v-model:value="formState.lore_sync_interval"
                :min="1"
                :max="syncIntervalUpperBound"
                :step="1"
                :precision="0"
                @blur="handleNumericBlur('lore_sync_interval')"
              />
            </div>
          </n-form-item>
          <div class="field-hint">{{ t("sessionPanel.hints.minus_one_all") }}</div>
          <n-form-item :label="t('sessionPanel.fields.user_description')">
            <n-input
              v-model:value="formState.user_description"
              type="textarea"
              :autosize="{ minRows: 4 }"
              @blur="flush"
            />
          </n-form-item>
        </n-form>
      </div>

      <div v-else class="empty">
        <div class="empty-icon">??</div>
        <div>{{ t("sessionPanel.empty") }}</div>
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
  useMessage,
} from "naive-ui";

import { useApiConfigStore } from "@/stores/api-config";
import { usePresetStore } from "@/stores/preset";
import { useSessionStore } from "@/stores/session";
import { useChatStore } from "@/stores/chat";
import { useAutoSave } from "@/composables/useAutoSave";
import { useI18n } from "@/composables/useI18n";
import { confirmLeaveSessionWhileBusy } from "@/utils/session-leave-guard";

import ConfigSelector from "@/components/panels/ConfigSelector.vue";
import SaveIndicator from "@/components/panels/SaveIndicator.vue";

const store = useSessionStore();
const apiStore = useApiConfigStore();
const presetStore = usePresetStore();
const chatStore = useChatStore();
const message = useMessage();
const { t } = useI18n();

const selectedName = ref<string | null>(null);
const createMode = ref(false);
const syncing = ref(false);
const sliderDraggingField = ref<"scan_depth" | "mem_length" | "lore_sync_interval" | null>(null);

const modeOptions = [
  { label: "RST", value: "RST" },
  { label: "ST", value: "ST" },
];

const formState = reactive({
  mode: "RST" as "ST" | "RST",
  is_closed: false,
  main_api_config_id: "",
  scheduler_api_config_id: null as string | null,
  preset_id: "",
  scan_depth: 4,
  mem_length: 40,
  lore_sync_interval: 3,
  user_description: "",
});

const createForm = reactive({
  name: "",
  mode: "RST" as "ST" | "RST",
  main_api_config_id: "",
  preset_id: "",
  lore_sync_interval: 3,
});

const sessionOptions = computed(() =>
  store.sessions.map((session) => ({
    label: session.name,
    value: session.name,
  })),
);

const apiOptions = computed(() =>
  apiStore.configs.map((config) => ({
    label: config.name,
    value: config.id,
  })),
);

const presetOptions = computed(() =>
  presetStore.presets.map((preset) => ({
    label: preset.name,
    value: preset.id,
  })),
);

const syncIntervalUpperBound = computed(() => {
  if (formState.mem_length < 0) {
    return 5;
  }
  return Math.max(1, Math.min(5, formState.mem_length));
});

const { saveStatus, markDirty, flush, cancel } = useAutoSave({
  saveFn: async () => {
    if (!selectedName.value || !store.currentSession) {
      return;
    }
    formState.scan_depth = coerceNumber(formState.scan_depth, -1, 40, 1);
    formState.mem_length = coerceNumber(formState.mem_length, -1, 400, 5);
    formState.lore_sync_interval = coerceNumber(
      formState.lore_sync_interval,
      1,
      syncIntervalUpperBound.value,
      1,
    );
    await store.saveSession(selectedName.value, {
      mode: formState.mode,
      is_closed: formState.is_closed,
      main_api_config_id: formState.main_api_config_id,
      scheduler_api_config_id: formState.scheduler_api_config_id ?? null,
      preset_id: formState.preset_id,
      scan_depth: formState.scan_depth,
      mem_length: formState.mem_length,
      lore_sync_interval: formState.lore_sync_interval,
      user_description: formState.user_description,
    });
  },
  delay: 300,
});

onMounted(() => {
  store.loadSessions();
  apiStore.loadConfigs();
  presetStore.loadPresets();
});

watch(
  () => store.currentSession,
  (session) => {
    syncing.value = true;
    if (session) {
      if (selectedName.value !== session.name) {
        selectedName.value = session.name;
      }
      formState.mode = session.mode;
      formState.is_closed = session.is_closed;
      formState.main_api_config_id = session.main_api_config_id;
      formState.scheduler_api_config_id = session.scheduler_api_config_id;
      formState.preset_id = session.preset_id;
      formState.scan_depth = session.scan_depth;
      formState.mem_length = session.mem_length;
      formState.lore_sync_interval = session.lore_sync_interval;
      formState.user_description = session.user_description;
    }
    syncing.value = false;
  },
  { immediate: true },
);

watch(
  formState,
  () => {
    if (
      syncing.value ||
      createMode.value ||
      !store.currentSession ||
      sliderDraggingField.value !== null
    ) {
      return;
    }
    markDirty();
  },
  { deep: true },
);

watch(selectedName, () => {
  cancel();
});

async function handleSelect(value: string) {
  if (value === selectedName.value) {
    return;
  }
  if (!(await confirmLeaveIfBusy())) {
    return;
  }
  createMode.value = false;
  selectedName.value = value;
  store.loadSession(value);
}

function startCreate() {
  createMode.value = true;
  selectedName.value = null;
  store.currentSession = null;
  createForm.name = "";
  createForm.mode = "RST";
  createForm.main_api_config_id = "";
  createForm.preset_id = "";
  createForm.lore_sync_interval = 3;
}

async function submitCreate() {
  if (!createForm.name.trim()) {
    message.error(t("sessionPanel.errors.name_required"));
    return;
  }
  if (!createForm.main_api_config_id) {
    message.error(t("sessionPanel.errors.main_api_required"));
    return;
  }
  if (!createForm.preset_id) {
    message.error(t("sessionPanel.errors.preset_required"));
    return;
  }
  const result = await store.createSession({
    name: createForm.name.trim(),
    mode: createForm.mode,
    main_api_config_id: createForm.main_api_config_id,
    preset_id: createForm.preset_id,
    lore_sync_interval: createForm.lore_sync_interval,
  });
  if (result) {
    createMode.value = false;
    selectedName.value = result.name;
  }
}

function cancelCreate() {
  createMode.value = false;
}

async function handleRename(newName: string) {
  if (!selectedName.value) {
    return;
  }
  const result = await store.renameSession(selectedName.value, { new_name: newName });
  if (result) {
    selectedName.value = result.name;
  }
}

async function handleDelete() {
  if (!selectedName.value) {
    return;
  }
  await store.removeSession(selectedName.value);
  selectedName.value = null;
}

function handleImmediateSave() {
  if (!selectedName.value) {
    return;
  }
  formState.scan_depth = coerceNumber(formState.scan_depth, -1, 40, 1);
  formState.mem_length = coerceNumber(formState.mem_length, -1, 400, 5);
  formState.lore_sync_interval = coerceNumber(
    formState.lore_sync_interval,
    1,
    syncIntervalUpperBound.value,
    1,
  );
  markDirty();
  void flush();
}

async function confirmLeaveIfBusy(): Promise<boolean> {
  const currentName = store.currentSession?.name ?? selectedName.value;
  if (!currentName) {
    return true;
  }
  if (chatStore.activeSession !== currentName || !chatStore.hasRunningWork) {
    return true;
  }
  const confirmed = await confirmLeaveSessionWhileBusy();
  if (!confirmed) {
    return false;
  }
  chatStore.cancelInFlightOperations();
  return true;
}

function handleSliderUpdate(field: "scan_depth" | "mem_length" | "lore_sync_interval") {
  sliderDraggingField.value = field;
}

function handleSliderCommit(
  field: "scan_depth" | "mem_length" | "lore_sync_interval",
  value: number,
) {
  sliderDraggingField.value = null;
  if (field === "scan_depth") {
    formState.scan_depth = coerceNumber(value, -1, 40, 1);
  } else if (field === "mem_length") {
    formState.mem_length = coerceNumber(value, -1, 400, 5);
  } else {
    formState.lore_sync_interval = coerceNumber(value, 1, syncIntervalUpperBound.value, 1);
  }
  if (!selectedName.value) {
    return;
  }
  markDirty();
  void flush();
}

function handleNumericBlur(field: "scan_depth" | "mem_length" | "lore_sync_interval") {
  if (field === "scan_depth") {
    formState.scan_depth = coerceNumber(formState.scan_depth, -1, 40, 1);
  } else if (field === "mem_length") {
    formState.mem_length = coerceNumber(formState.mem_length, -1, 400, 5);
  } else {
    formState.lore_sync_interval = coerceNumber(
      formState.lore_sync_interval,
      1,
      syncIntervalUpperBound.value,
      1,
    );
  }
  void flush();
}

function coerceNumber(value: number | null, min: number, max: number, step: number): number {
  if (value === null || Number.isNaN(value)) {
    return -1;
  }
  if (value === -1) {
    return -1;
  }
  const clamped = Math.min(max, Math.max(min, value));
  if (step <= 1) {
    return clamped;
  }
  return Math.round(clamped / step) * step;
}

function formatDepthTooltip(value: number) {
  return value === -1 ? t("common.all") : `${value}`;
}

function formatMemTooltip(value: number) {
  return value === -1 ? t("common.all") : `${value}`;
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
  grid-template-columns: minmax(0, 1fr) 92px;
  gap: 10px;
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

.field-hint {
  margin-top: 6px;
  font-size: 11px;
  color: var(--rst-text-secondary);
}

</style>
