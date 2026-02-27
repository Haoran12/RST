<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">Session</div>
      <SaveIndicator :status="saveStatus" />
    </header>

    <ConfigSelector
      :options="sessionOptions"
      :selected-value="selectedName"
      placeholder="选择会话..."
      :loading="store.loading"
      @select="handleSelect"
      @create="startCreate"
      @rename-confirm="handleRename"
      @delete="handleDelete"
    />

    <div class="panel-body">
      <div v-if="createMode" class="card">
        <div class="card-title">新建会话</div>
        <n-form size="small" label-placement="top">
          <n-form-item label="名称">
            <n-input v-model:value="createForm.name" placeholder="请输入会话名称" />
          </n-form-item>
          <n-form-item label="Mode">
            <n-select v-model:value="createForm.mode" :options="modeOptions" />
          </n-form-item>
          <n-form-item label="Main API">
            <n-select
              v-model:value="createForm.main_api_config_id"
              :options="apiOptions"
              placeholder="选择 API 配置"
            />
          </n-form-item>
          <n-form-item label="Preset">
            <n-select
              v-model:value="createForm.preset_id"
              :options="presetOptions"
              placeholder="选择 Preset"
            />
          </n-form-item>
          <div class="card-actions">
            <n-button secondary @click="cancelCreate">取消</n-button>
            <n-button type="primary" @click="submitCreate">创建</n-button>
          </div>
        </n-form>
      </div>

      <div v-else-if="store.currentSession" class="form">
        <n-form size="small" label-placement="top">
          <n-form-item label="Mode">
            <n-select
              v-model:value="formState.mode"
              :options="modeOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item label="Main API">
            <n-select
              v-model:value="formState.main_api_config_id"
              :options="apiOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item label="Scheduler API">
            <n-select
              v-model:value="formState.scheduler_api_config_id"
              :options="apiOptions"
              clearable
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item label="Preset">
            <n-select
              v-model:value="formState.preset_id"
              :options="presetOptions"
              @update:value="handleImmediateSave"
            />
          </n-form-item>
          <n-form-item label="Scan Depth">
            <n-input-number
              v-model:value="formState.scan_depth"
              :min="1"
              :max="50"
              @blur="flush"
            />
          </n-form-item>
          <n-form-item label="Mem Length">
            <n-input-number
              v-model:value="formState.mem_length"
              :min="1"
              :max="500"
              @blur="flush"
            />
          </n-form-item>
          <n-form-item label="User Description">
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
        <div>请选择或新建一个会话</div>
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
  useMessage,
} from "naive-ui";

import { useApiConfigStore } from "@/stores/api-config";
import { usePresetStore } from "@/stores/preset";
import { useSessionStore } from "@/stores/session";
import { useAutoSave } from "@/composables/useAutoSave";

import ConfigSelector from "@/components/panels/ConfigSelector.vue";
import SaveIndicator from "@/components/panels/SaveIndicator.vue";

const store = useSessionStore();
const apiStore = useApiConfigStore();
const presetStore = usePresetStore();
const message = useMessage();

const selectedName = ref<string | null>(null);
const createMode = ref(false);
const syncing = ref(false);

const modeOptions = [
  { label: "RST", value: "RST" },
  { label: "ST", value: "ST" },
];

const formState = reactive({
  mode: "RST" as "ST" | "RST",
  main_api_config_id: "",
  scheduler_api_config_id: null as string | null,
  preset_id: "",
  scan_depth: 4,
  mem_length: 40,
  user_description: "",
});

const createForm = reactive({
  name: "",
  mode: "RST" as "ST" | "RST",
  main_api_config_id: "",
  preset_id: "",
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

const { saveStatus, markDirty, flush, cancel } = useAutoSave({
  saveFn: async () => {
    if (!selectedName.value || !store.currentSession) {
      return;
    }
    await store.saveSession(selectedName.value, {
      mode: formState.mode,
      main_api_config_id: formState.main_api_config_id,
      scheduler_api_config_id: formState.scheduler_api_config_id ?? null,
      preset_id: formState.preset_id,
      scan_depth: formState.scan_depth,
      mem_length: formState.mem_length,
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
      formState.main_api_config_id = session.main_api_config_id;
      formState.scheduler_api_config_id = session.scheduler_api_config_id;
      formState.preset_id = session.preset_id;
      formState.scan_depth = session.scan_depth;
      formState.mem_length = session.mem_length;
      formState.user_description = session.user_description;
    }
    syncing.value = false;
  },
  { immediate: true },
);

watch(
  formState,
  () => {
    if (syncing.value || createMode.value || !store.currentSession) {
      return;
    }
    markDirty();
  },
  { deep: true },
);

watch(selectedName, () => {
  cancel();
});

function handleSelect(value: string) {
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
}

async function submitCreate() {
  if (!createForm.name.trim()) {
    message.error("请输入会话名称");
    return;
  }
  if (!createForm.main_api_config_id) {
    message.error("请选择 Main API");
    return;
  }
  if (!createForm.preset_id) {
    message.error("请选择 Preset");
    return;
  }
  const result = await store.createSession({
    name: createForm.name.trim(),
    mode: createForm.mode,
    main_api_config_id: createForm.main_api_config_id,
    preset_id: createForm.preset_id,
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
</style>

