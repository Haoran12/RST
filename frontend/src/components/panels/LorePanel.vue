<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">Lore</div>
    </header>

    <ConfigSelector
      :options="loreOptions"
      :selected-value="selectedId"
      placeholder="选择 Lore 文件..."
      @select="handleSelect"
      @create="startCreate"
      @rename-confirm="handleRename"
      @delete="handleDelete"
    />

    <div class="panel-body">
      <div v-if="createMode" class="card">
        <div class="card-title">新建 Lore 文件</div>
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

      <div v-else-if="selectedItem" class="placeholder">
        <div class="placeholder-icon">??</div>
        <div>当前文件：{{ selectedItem.name }}</div>
        <div>Lore 编辑器将在 M3 中实现</div>
      </div>

      <div v-else class="empty">
        <div class="empty-icon">??</div>
        <div>请选择或新建一个 Lore 文件</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import { NButton, NForm, NFormItem, NInput, useMessage } from "naive-ui";

import ConfigSelector from "@/components/panels/ConfigSelector.vue";

interface LoreFile {
  id: string;
  name: string;
}

const STORAGE_KEY = "rst_lore_files";

const message = useMessage();
const selectedId = ref<string | null>(null);
const createMode = ref(false);
const createName = ref("");
const loreFiles = ref<LoreFile[]>([]);

const loreOptions = computed(() =>
  loreFiles.value.map((file) => ({ label: file.name, value: file.id })),
);

const selectedItem = computed(() =>
  loreFiles.value.find((file) => file.id === selectedId.value),
);

onMounted(() => {
  loreFiles.value = readStorage();
});

watch(
  loreFiles,
  (files) => {
    writeStorage(files);
    if (selectedId.value && !files.find((file) => file.id === selectedId.value)) {
      selectedId.value = null;
    }
  },
  { deep: true },
);

function readStorage(): LoreFile[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return [];
    }
    const parsed = JSON.parse(raw) as LoreFile[];
    if (Array.isArray(parsed)) {
      return parsed.filter((item) => item && item.id && item.name);
    }
    return [];
  } catch {
    return [];
  }
}

function writeStorage(files: LoreFile[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(files));
}

function handleSelect(value: string) {
  createMode.value = false;
  selectedId.value = value;
}

function startCreate() {
  createMode.value = true;
  selectedId.value = null;
  createName.value = "";
}

function cancelCreate() {
  createMode.value = false;
}

function submitCreate() {
  const name = createName.value.trim();
  if (!name) {
    message.error("请输入名称");
    return;
  }
  if (isNameTaken(name)) {
    message.error("名称已存在");
    return;
  }
  const id = typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now()}`;
  loreFiles.value = [...loreFiles.value, { id, name }];
  createMode.value = false;
  selectedId.value = id;
}

function handleRename(newName: string) {
  if (!selectedId.value) {
    return;
  }
  const trimmed = newName.trim();
  if (!trimmed) {
    message.error("请输入名称");
    return;
  }
  if (isNameTaken(trimmed, selectedId.value)) {
    message.error("名称已存在");
    return;
  }
  loreFiles.value = loreFiles.value.map((file) =>
    file.id === selectedId.value ? { ...file, name: trimmed } : file,
  );
}

function handleDelete() {
  if (!selectedId.value) {
    return;
  }
  loreFiles.value = loreFiles.value.filter((file) => file.id !== selectedId.value);
  selectedId.value = null;
}

function isNameTaken(name: string, ignoreId?: string): boolean {
  const lower = name.toLowerCase();
  return loreFiles.value.some(
    (file) => file.id !== ignoreId && file.name.toLowerCase() === lower,
  );
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

.placeholder {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--rst-text-secondary);
  text-align: center;
}

.placeholder-icon {
  font-size: 24px;
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
