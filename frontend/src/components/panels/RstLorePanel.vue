<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">RST Lore</div>
      <n-tag size="small" :bordered="false" type="info">
        {{ currentSession?.name ?? "No Session" }}
      </n-tag>
    </header>

    <div v-if="!currentSession" class="empty">
      <div class="empty-icon">📚</div>
      <div>请先在 Session 面板选择会话</div>
    </div>

    <n-spin v-else :show="loreStore.loading" class="panel-body">
      <n-tabs v-model:value="activeTab" type="line" animated>
        <n-tab-pane name="entries" tab="设定条目">
          <div class="toolbar">
            <n-select
              v-model:value="entryCategory"
              size="small"
              :options="entryCategoryOptions"
              @update:value="handleCategoryChange"
            />
            <n-space>
              <n-button size="small" tertiary @click="prepareNewEntry">新建</n-button>
              <n-button size="small" type="primary" @click="saveEntry">保存</n-button>
              <n-button
                size="small"
                type="error"
                tertiary
                :disabled="!entryForm.id"
                @click="removeEntry"
              >
                删除
              </n-button>
            </n-space>
          </div>

          <div class="grid">
            <div class="list">
              <button
                v-for="entry in loreStore.sortedEntries"
                :key="entry.id"
                type="button"
                class="list-item"
                :class="{ active: entry.id === entryForm.id }"
                @click="selectEntry(entry.id)"
              >
                <span class="name">{{ entry.name }}</span>
                <span class="meta">{{ entry.tags.join(", ") }}</span>
              </button>
            </div>

            <div class="editor">
              <n-input v-model:value="entryForm.name" placeholder="条目名称" />
              <n-input
                v-model:value="entryForm.content"
                type="textarea"
                :autosize="{ minRows: 8 }"
                placeholder="条目内容"
              />
              <n-input v-model:value="entryForm.tagsText" placeholder="标签，逗号分隔" />
              <div class="flags">
                <n-checkbox v-model:checked="entryForm.constant">常驻注入</n-checkbox>
                <n-checkbox v-model:checked="entryForm.disabled">禁用</n-checkbox>
              </div>
            </div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="characters" tab="人物">
          <div class="toolbar">
            <n-space>
              <n-button size="small" tertiary @click="prepareNewCharacter">新建人物</n-button>
              <n-button size="small" type="primary" @click="saveCharacter">保存人物</n-button>
              <n-button
                size="small"
                type="error"
                tertiary
                :disabled="!characterForm.character_id"
                @click="removeCharacter"
              >
                删除人物
              </n-button>
            </n-space>
          </div>

          <div class="grid">
            <div class="list">
              <button
                v-for="character in charactersSorted"
                :key="character.character_id"
                type="button"
                class="list-item"
                :class="{ active: character.character_id === characterForm.character_id }"
                @click="selectCharacter(character.character_id)"
              >
                <span class="name">{{ character.name }}</span>
                <span class="meta">{{ character.race }} · {{ character.role }}</span>
              </button>
            </div>

            <div class="editor">
              <n-input v-model:value="characterForm.name" placeholder="人物名" />
              <n-input v-model:value="characterForm.race" placeholder="种族" />
              <n-input v-model:value="characterForm.role" placeholder="身份/职业" />
              <n-input v-model:value="characterForm.faction" placeholder="阵营/组织" />
              <n-input v-model:value="characterForm.objective" placeholder="当前目标" />
              <n-input
                v-model:value="characterForm.personality"
                type="textarea"
                :autosize="{ minRows: 4 }"
                placeholder="性格描述"
              />
              <n-input
                v-model:value="characterForm.tagsText"
                placeholder="标签，逗号分隔"
              />
              <div class="flags">
                <n-checkbox v-model:checked="characterForm.constant">常驻注入</n-checkbox>
                <n-checkbox v-model:checked="characterForm.disabled">禁用</n-checkbox>
              </div>
            </div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="scheduler" tab="调度器">
          <div class="scheduler-card">
            <div class="status-grid">
              <div>
                <div class="status-label">Schedule</div>
                <div class="status-value">
                  {{ loreStore.scheduleStatus?.running ? "Running" : "Idle" }}
                </div>
                <div class="status-meta">
                  匹配数: {{ loreStore.scheduleStatus?.last_matched_count ?? 0 }}
                </div>
              </div>
              <div>
                <div class="status-label">Sync</div>
                <div class="status-value">
                  {{ loreStore.syncStatus?.running ? "Running" : "Idle" }}
                </div>
                <div class="status-meta">
                  轮数: {{ loreStore.syncStatus?.rounds_since_last_sync ?? 0 }} /
                  {{ loreStore.syncStatus?.sync_interval ?? 0 }}
                </div>
              </div>
            </div>

            <n-space>
              <n-button size="small" @click="refreshSchedulerState">刷新状态</n-button>
              <n-button size="small" type="primary" @click="triggerScheduleNow">手动调度</n-button>
              <n-button size="small" type="warning" @click="triggerSyncNow">手动同步</n-button>
            </n-space>

            <n-input
              v-model:value="templateForm.confirm_prompt"
              type="textarea"
              :autosize="{ minRows: 5 }"
              placeholder="confirm_prompt"
            />
            <n-input
              v-model:value="templateForm.extract_prompt"
              type="textarea"
              :autosize="{ minRows: 5 }"
              placeholder="extract_prompt"
            />
            <n-input
              v-model:value="templateForm.consolidate_prompt"
              type="textarea"
              :autosize="{ minRows: 5 }"
              placeholder="consolidate_prompt"
            />
            <n-button size="small" type="primary" @click="saveTemplate">保存模板</n-button>
          </div>
        </n-tab-pane>
      </n-tabs>
    </n-spin>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import {
  NButton,
  NCheckbox,
  NInput,
  NSelect,
  NSpace,
  NSpin,
  NTabPane,
  NTabs,
  NTag,
} from "naive-ui";

import { useLoreStore } from "@/stores/lore";
import { useSessionStore } from "@/stores/session";

import type { LoreCategory } from "@/types/lore";

const sessionStore = useSessionStore();
const loreStore = useLoreStore();
const { currentSession } = storeToRefs(sessionStore);

const activeTab = ref<"entries" | "characters" | "scheduler">("entries");
const entryCategory = ref<Exclude<LoreCategory, "character" | "memory">>(
  "world_base",
);

const entryCategoryOptions = [
  { label: "世界观", value: "world_base" },
  { label: "社会制度", value: "society" },
  { label: "地点", value: "place" },
  { label: "势力", value: "faction" },
  { label: "技能", value: "skills" },
  { label: "其他", value: "others" },
  { label: "故事线", value: "plot" },
];

const entryForm = reactive({
  id: "",
  name: "",
  content: "",
  tagsText: "",
  disabled: false,
  constant: false,
});

const characterForm = reactive({
  character_id: "",
  name: "",
  race: "",
  role: "",
  faction: "",
  objective: "",
  personality: "",
  tagsText: "",
  disabled: false,
  constant: false,
});

const templateForm = reactive({
  confirm_prompt: "",
  extract_prompt: "",
  consolidate_prompt: "",
});

const charactersSorted = computed(() =>
  [...loreStore.characters].sort((a, b) => a.name.localeCompare(b.name)),
);

onMounted(async () => {
  if (!currentSession.value) {
    await sessionStore.loadSessions();
  }
  await bootstrapCurrentSession();
});

watch(
  () => currentSession.value?.name,
  async () => {
    await bootstrapCurrentSession();
  },
);

watch(
  () => loreStore.schedulerTemplate,
  (value) => {
    if (!value) {
      return;
    }
    templateForm.confirm_prompt = value.confirm_prompt;
    templateForm.extract_prompt = value.extract_prompt;
    templateForm.consolidate_prompt = value.consolidate_prompt;
  },
  { deep: true },
);

async function bootstrapCurrentSession() {
  if (!currentSession.value?.name) {
    return;
  }
  await Promise.all([
    loreStore.loadEntries(currentSession.value.name, entryCategory.value),
    loreStore.loadCharacters(currentSession.value.name),
    loreStore.refreshSchedulerState(currentSession.value.name),
  ]);
  prepareNewEntry();
  prepareNewCharacter();
}

function parseTags(text: string): string[] {
  return text
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

async function handleCategoryChange() {
  if (!currentSession.value?.name) {
    return;
  }
  await loreStore.loadEntries(currentSession.value.name, entryCategory.value);
  prepareNewEntry();
}

function prepareNewEntry() {
  entryForm.id = "";
  entryForm.name = "";
  entryForm.content = "";
  entryForm.tagsText = "";
  entryForm.disabled = false;
  entryForm.constant = false;
}

function selectEntry(entryId: string) {
  const target = loreStore.entries.find((entry) => entry.id === entryId);
  if (!target) {
    return;
  }
  entryForm.id = target.id;
  entryForm.name = target.name;
  entryForm.content = target.content;
  entryForm.tagsText = target.tags.join(", ");
  entryForm.disabled = target.disabled;
  entryForm.constant = target.constant;
}

async function saveEntry() {
  if (!currentSession.value?.name || !entryForm.name.trim()) {
    return;
  }
  const payload = {
    name: entryForm.name.trim(),
    category: entryCategory.value,
    content: entryForm.content,
    tags: parseTags(entryForm.tagsText),
    disabled: entryForm.disabled,
    constant: entryForm.constant,
  };

  if (!entryForm.id) {
    const created = await loreStore.createEntry(currentSession.value.name, payload);
    if (created) {
      selectEntry(created.id);
    }
    return;
  }

  const updated = await loreStore.updateEntry(currentSession.value.name, entryForm.id, {
    name: payload.name,
    content: payload.content,
    tags: payload.tags,
    disabled: payload.disabled,
    constant: payload.constant,
  });
  if (updated) {
    selectEntry(updated.id);
  }
}

async function removeEntry() {
  if (!currentSession.value?.name || !entryForm.id) {
    return;
  }
  await loreStore.deleteEntry(currentSession.value.name, entryForm.id);
  prepareNewEntry();
}

function prepareNewCharacter() {
  characterForm.character_id = "";
  characterForm.name = "";
  characterForm.race = "";
  characterForm.role = "";
  characterForm.faction = "";
  characterForm.objective = "";
  characterForm.personality = "";
  characterForm.tagsText = "";
  characterForm.disabled = false;
  characterForm.constant = false;
}

function selectCharacter(characterId: string) {
  const target = loreStore.characters.find((item) => item.character_id === characterId);
  if (!target) {
    return;
  }
  characterForm.character_id = target.character_id;
  characterForm.name = target.name;
  characterForm.race = target.race;
  characterForm.role = target.role;
  characterForm.faction = target.faction;
  characterForm.objective = target.objective;
  characterForm.personality = target.personality;
  characterForm.tagsText = target.tags.join(", ");
  characterForm.disabled = target.disabled;
  characterForm.constant = target.constant;
}

async function saveCharacter() {
  if (!currentSession.value?.name || !characterForm.name.trim() || !characterForm.race.trim()) {
    return;
  }
  const payload = {
    name: characterForm.name.trim(),
    race: characterForm.race.trim(),
    role: characterForm.role,
    faction: characterForm.faction,
    objective: characterForm.objective,
    personality: characterForm.personality,
    tags: parseTags(characterForm.tagsText),
    disabled: characterForm.disabled,
    constant: characterForm.constant,
  };

  if (!characterForm.character_id) {
    const created = await loreStore.createCharacter(currentSession.value.name, payload);
    if (created) {
      selectCharacter(created.character_id);
    }
    return;
  }

  const updated = await loreStore.updateCharacter(
    currentSession.value.name,
    characterForm.character_id,
    payload,
  );
  if (updated) {
    selectCharacter(updated.character_id);
  }
}

async function removeCharacter() {
  if (!currentSession.value?.name || !characterForm.character_id) {
    return;
  }
  await loreStore.deleteCharacter(currentSession.value.name, characterForm.character_id);
  prepareNewCharacter();
}

async function refreshSchedulerState() {
  if (!currentSession.value?.name) {
    return;
  }
  await loreStore.refreshSchedulerState(currentSession.value.name);
}

async function triggerScheduleNow() {
  if (!currentSession.value?.name) {
    return;
  }
  await loreStore.triggerSchedule(currentSession.value.name);
}

async function triggerSyncNow() {
  if (!currentSession.value?.name) {
    return;
  }
  await loreStore.triggerSync(currentSession.value.name);
}

async function saveTemplate() {
  if (!currentSession.value?.name) {
    return;
  }
  await loreStore.updateSchedulerTemplate(currentSession.value.name, {
    confirm_prompt: templateForm.confirm_prompt,
    extract_prompt: templateForm.extract_prompt,
    consolidate_prompt: templateForm.consolidate_prompt,
  });
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
  min-height: 0;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 10px;
}

.toolbar :deep(.n-select) {
  width: 170px;
}

.grid {
  display: grid;
  grid-template-columns: 136px minmax(0, 1fr);
  gap: 10px;
  min-height: 360px;
}

.list {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  overflow-y: auto;
  background: var(--rst-bg-topbar);
}

.list-item {
  width: 100%;
  border: none;
  text-align: left;
  padding: 8px;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  gap: 3px;
  color: var(--rst-text-primary);
  background: transparent;
}

.list-item:hover,
.list-item.active {
  background: rgba(59, 130, 246, 0.2);
}

.list-item .name {
  font-size: 12px;
  font-weight: 600;
}

.list-item .meta {
  font-size: 11px;
  color: var(--rst-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.editor {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.flags {
  display: flex;
  gap: 16px;
  font-size: 12px;
}

.empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--rst-text-secondary);
}

.empty-icon {
  font-size: 28px;
}

.scheduler-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.status-label {
  font-size: 11px;
  text-transform: uppercase;
  color: var(--rst-text-secondary);
}

.status-value {
  font-size: 14px;
  font-weight: 600;
}

.status-meta {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

@media (max-width: 720px) {
  .grid {
    grid-template-columns: 1fr;
  }
}
</style>
