<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">RST Lore</div>
      <div class="header-actions">
        <n-button
          size="small"
          secondary
          :disabled="!currentSession || loreStore.loading"
          @click="openImportPicker"
        >
          导入静态 Lore
        </n-button>
        <n-tag size="small" :bordered="false" type="info">
          {{ currentSession?.name ?? "No Session" }}
        </n-tag>
      </div>
    </header>

    <input
      ref="importInputRef"
      class="hidden-file-input"
      type="file"
      accept=".json,application/json"
      @change="handleFileChange"
    />

    <div v-if="!currentSession" class="empty">
      <div class="empty-icon">📚</div>
      <div>请先在 Session 面板选择会话</div>
    </div>

    <n-spin v-else :show="loreStore.loading" class="panel-body">
      <n-tabs v-model:value="activeTab" type="line" animated>
        <n-tab-pane name="entries" tab="其他设定">
          <div class="entries-filter-row">
            <n-select
              v-model:value="entryFilter"
              size="small"
              :options="entryFilterOptions"
              @update:value="handleEntryFilterChange"
            />
          </div>

          <div class="entries-panel">
            <div class="entries-actions-row">
              <div class="entries-title">Entries</div>
              <div class="entries-actions">
                <n-button size="small" type="primary" @click="openNewEntryOverlay">+ 添加条目</n-button>
                <n-popconfirm
                  :show-icon="false"
                  positive-text="确认删除"
                  :positive-button-props="{ type: 'error' }"
                  @positive-click="handleBulkDeleteEntries"
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
              v-if="entryRows.length > 0"
              v-model="entryRows"
              item-key="id"
              handle=".drag-handle"
              class="entry-list"
              @end="handleEntryReorder"
            >
              <template #item="{ element }">
                <div
                  class="entry-row"
                  :class="{ active: element.id === activeEntryId }"
                  @click="openEntryOverlay(element.id)"
                >
                  <div class="drag-handle" @click.stop>⋮⋮</div>
                  <div class="entry-checkbox" @click.stop>
                    <n-checkbox
                      size="small"
                      :checked="selectedEntryIds.includes(element.id)"
                      @update:checked="(checked) => toggleEntrySelected(element.id, checked)"
                    />
                  </div>
                  <div class="entry-main">
                    <span class="entry-name">{{ element.name }}</span>
                    <span class="entry-meta">{{ element.tags.join(", ") }}</span>
                  </div>
                  <div class="entry-mode">{{ entryTriggerLabel(element) }}</div>
                  <div class="entry-toggle" @click.stop>
                    <n-switch
                      :value="!element.disabled"
                      @update:value="(enabled) => handleEntryToggle(element.id, enabled)"
                    />
                  </div>
                </div>
              </template>
            </Draggable>

            <div v-else class="entry-list-empty">
              当前分类暂无条目
            </div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="characters" tab="人物">
          <div class="entries-panel">
            <div class="entries-actions-row">
              <div class="entries-title">Characters</div>
              <div class="entries-actions">
                <n-button size="small" type="primary" @click="openNewCharacterOverlay">
                  + 添加人物
                </n-button>
                <n-popconfirm
                  :show-icon="false"
                  positive-text="确认删除"
                  :positive-button-props="{ type: 'error' }"
                  @positive-click="handleBulkDeleteCharacters"
                >
                  <template #trigger>
                    <n-button
                      size="small"
                      secondary
                      class="entries-action entries-action--danger"
                      :disabled="!hasCharacterSelection"
                      aria-label="删除选中人物"
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
                  确认删除选中人物？
                </n-popconfirm>
                <n-button
                  size="small"
                  secondary
                  class="entries-action"
                  :disabled="!hasCharacterSelection"
                  aria-label="复制选中人物"
                  title="Copy"
                  @click="openCharacterCopyModal"
                >
                  ⧉
                </n-button>
              </div>
            </div>

            <div v-if="charactersSorted.length > 0" class="entry-list">
              <button
                v-for="character in charactersSorted"
                :key="character.character_id"
                type="button"
                class="character-row"
                :class="{ active: character.character_id === activeCharacterId }"
                @click="openCharacterOverlay(character.character_id)"
              >
                <div class="entry-checkbox" @click.stop>
                  <n-checkbox
                    size="small"
                    :checked="selectedCharacterIds.includes(character.character_id)"
                    @update:checked="(checked) => toggleCharacterSelected(character.character_id, checked)"
                  />
                </div>
                <div class="entry-main">
                  <span class="entry-name">{{ character.name }}</span>
                </div>
                <div class="entry-mode">{{ characterModeLabel(character) }}</div>
                <div class="entry-toggle" @click.stop>
                  <n-switch
                    :value="!character.disabled"
                    @update:value="(enabled) => handleCharacterToggle(character.character_id, enabled)"
                  />
                </div>
              </button>
            </div>

            <div v-else class="entry-list-empty">
              当前暂无人物条目
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

    <ContentOverlay
      :visible="entryOverlayVisible"
      :title="entryOverlayTitle"
      :fields="entryOverlayFields"
      :content-value="entryOverlayContent"
      content-label="条目内容"
      :show-delete="Boolean(editingEntryId)"
      delete-text="删除条目"
      @save="handleEntryOverlaySave"
      @discard="closeEntryOverlay"
      @delete="removeEntryFromOverlay"
    />

    <ContentOverlay
      :visible="characterOverlayVisible"
      :title="characterOverlayTitle"
      :fields="characterOverlayFields"
      :content-value="characterOverlayContent"
      content-label="性格描述"
      :show-delete="Boolean(editingCharacterId)"
      delete-text="删除人物"
      @save="handleCharacterOverlaySave"
      @discard="closeCharacterOverlay"
      @delete="removeCharacterFromOverlay"
    />

    <n-modal v-model:show="copyModalVisible" preset="card" title="复制到 Session" size="small">
      <div class="copy-modal-body">
        <n-select
          v-model:value="copyTargetSession"
          :options="targetSessionOptions"
          placeholder="选择目标 Session"
          :disabled="targetSessionOptions.length === 0"
        />
        <div v-if="targetSessionOptions.length === 0" class="copy-hint">
          暂无可用的目标 Session
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

    <n-modal v-model:show="characterCopyModalVisible" preset="card" title="复制人物到 Session" size="small">
      <div class="copy-modal-body">
        <n-select
          v-model:value="characterCopyTarget"
          :options="targetSessionOptions"
          placeholder="选择目标 Session"
          :disabled="targetSessionOptions.length === 0"
        />
        <div v-if="targetSessionOptions.length === 0" class="copy-hint">
          暂无可用的目标 Session
        </div>
      </div>
      <template #footer>
        <div class="copy-modal-actions">
          <n-button secondary @click="closeCharacterCopyModal">取消</n-button>
          <n-button
            type="primary"
            :disabled="characterCopyConfirmDisabled"
            @click="confirmCharacterCopy"
          >
            确认复制
          </n-button>
        </div>
      </template>
    </n-modal>

    <n-modal v-model:show="importModalVisible" preset="card" title="导入静态 Lore" size="small">
      <div class="import-modal-body">
        <div class="import-meta-row">
          <span class="import-meta-label">文件</span>
          <span>{{ importingFile?.name ?? "-" }}</span>
        </div>
        <div class="import-meta-row">
          <span class="import-meta-label">目标 Session</span>
          <span>{{ currentSession?.name ?? "-" }}</span>
        </div>
        <div class="import-warning">
          导入会以追加模式写入现有数据，不会覆盖已有条目。
        </div>
        <n-checkbox v-model:checked="splitFactionCharacters">
          拆分 faction 中嵌入的人物
        </n-checkbox>
      </div>
      <template #footer>
        <div class="import-modal-actions">
          <n-button secondary @click="closeImportModal">取消</n-button>
          <n-button
            type="primary"
            :disabled="!importingFile"
            :loading="loreStore.loading"
            @click="confirmImportLore"
          >
            确认导入
          </n-button>
        </div>
      </template>
    </n-modal>

    <n-modal
      v-model:show="reportOverlayVisible"
      preset="card"
      title="Lore 导入报告"
      size="large"
    >
      <div v-if="importReport" class="report-modal-body">
        <div class="report-summary">
          <div>来源文件：{{ importReport.source_file }}</div>
          <div>Session：{{ importReport.session_name }}</div>
          <div>总条目：{{ importReport.statistics.total_source_entries ?? 0 }}</div>
          <div>普通条目：{{ importReport.statistics.converted_entries ?? 0 }}</div>
          <div>人物：{{ importReport.statistics.converted_characters ?? 0 }}</div>
          <div>警告：{{ importReport.statistics.warnings_count ?? 0 }}</div>
          <div>错误：{{ importReport.statistics.errors_count ?? 0 }}</div>
        </div>

        <div class="report-action-list">
          <div
            v-for="(actionItem, index) in importReport.actions"
            :key="`${actionItem.source_id}-${index}`"
            class="report-action-card"
          >
            <div class="report-action-header">
              <div class="report-action-title">
                {{ index + 1 }}. {{ actionItem.name || "未命名条目" }}
              </div>
              <n-tag size="small" :bordered="false" type="info">
                {{ actionLabel(actionItem.action) }}
              </n-tag>
            </div>
            <div class="report-action-meta">
              source_id: {{ actionItem.source_id || "-" }}
            </div>
            <div class="report-action-meta">
              来源类别: {{ actionItem.source_category || "-" }} → 目标类别:
              {{ actionItem.target_category || "-" }}
            </div>
            <div v-if="actionItem.created_ids.length > 0" class="report-action-meta">
              创建对象: {{ actionItem.created_ids.join(", ") }}
            </div>
            <div v-if="actionItem.notes.length > 0" class="report-action-section">
              <div class="report-action-label">处理说明</div>
              <div
                v-for="(note, noteIndex) in actionItem.notes"
                :key="`${actionItem.source_id}-note-${noteIndex}`"
                class="report-action-line"
              >
                • {{ note }}
              </div>
            </div>
            <div v-if="actionItem.warnings.length > 0" class="report-action-section warning">
              <div class="report-action-label">警告</div>
              <div
                v-for="(warn, warnIndex) in actionItem.warnings"
                :key="`${actionItem.source_id}-warn-${warnIndex}`"
                class="report-action-line"
              >
                • {{ warn }}
              </div>
            </div>
            <div v-if="actionItem.errors.length > 0" class="report-action-section error">
              <div class="report-action-label">错误</div>
              <div
                v-for="(err, errIndex) in actionItem.errors"
                :key="`${actionItem.source_id}-err-${errIndex}`"
                class="report-action-line"
              >
                • {{ err }}
              </div>
            </div>
          </div>
        </div>
      </div>
      <template #footer>
        <div class="report-footer">
          <n-button secondary @click="reportOverlayVisible = false">关闭</n-button>
        </div>
      </template>
    </n-modal>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import {
  NButton,
  NCheckbox,
  NInput,
  NModal,
  NPopconfirm,
  NSelect,
  NSpace,
  NSpin,
  NSwitch,
  NTabPane,
  NTabs,
  NTag,
} from "naive-ui";
import Draggable from "vuedraggable";

import ContentOverlay from "@/components/panels/ContentOverlay.vue";
import { useLoreStore } from "@/stores/lore";
import { useSessionStore } from "@/stores/session";
import { message } from "@/utils/message";

import type { CharacterData, ConversionReport, LoreCategory, LoreEntry } from "@/types/lore";

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: Array<{ label: string; value: string }>;
}

const sessionStore = useSessionStore();
const loreStore = useLoreStore();
const { currentSession, sessions } = storeToRefs(sessionStore);

type EntryCategory = Exclude<LoreCategory, "character" | "memory">;

const activeTab = ref<"entries" | "characters" | "scheduler">("entries");
const entryCategory = ref<EntryCategory>("world_base");
const entryFilter = ref<EntryCategory>("world_base");

const entryCategoryOptions = [
  { label: "基础世界观", value: "world_base" },
  { label: "社会制度与文化等", value: "society" },
  { label: "地点", value: "place" },
  { label: "势力", value: "faction" },
  { label: "技能", value: "skills" },
  { label: "其他", value: "others" },
  { label: "情节", value: "plot" },
] as Array<{ label: string; value: EntryCategory }>;

const entryFilterOptions = [...entryCategoryOptions];

const triggerModeOptions = [
  { label: "RST", value: "rst" },
  { label: "Const", value: "const" },
];

const activeEntryId = ref<string | null>(null);
const editingEntryId = ref<string | null>(null);
const entryOverlayVisible = ref(false);
const entryOverlayTitle = ref("");
const entryOverlayFields = ref<OverlayField[]>([]);
const entryOverlayContent = ref("");
const entryRows = ref<LoreEntry[]>([]);
const selectedEntryIds = ref<string[]>([]);
const copyModalVisible = ref(false);
const copyTargetSession = ref<string | null>(null);

const activeCharacterId = ref<string | null>(null);
const editingCharacterId = ref<string | null>(null);
const characterOverlayVisible = ref(false);
const characterOverlayTitle = ref("");
const characterOverlayFields = ref<OverlayField[]>([]);
const characterOverlayContent = ref("");
const selectedCharacterIds = ref<string[]>([]);
const characterCopyModalVisible = ref(false);
const characterCopyTarget = ref<string | null>(null);

const templateForm = reactive({
  confirm_prompt: "",
  extract_prompt: "",
  consolidate_prompt: "",
});

const importInputRef = ref<HTMLInputElement | null>(null);
const importModalVisible = ref(false);
const importingFile = ref<File | null>(null);
const splitFactionCharacters = ref(false);
const reportOverlayVisible = ref(false);
const importReport = ref<ConversionReport | null>(null);

const charactersSorted = computed(() =>
  [...loreStore.characters].sort((a, b) => a.name.localeCompare(b.name)),
);
const targetSessionOptions = computed(() =>
  sessions.value
    .filter(
      (session) =>
        session.mode === "RST" &&
        !session.is_closed &&
        session.name !== currentSession.value?.name,
    )
    .map((session) => ({ label: session.name, value: session.name })),
);
const hasSelection = computed(() => selectedEntryIds.value.length > 0);
const copyDisabled = computed(() => !hasSelection.value || targetSessionOptions.value.length === 0);
const copyConfirmDisabled = computed(() => !hasSelection.value || !copyTargetSession.value);
const selectedEntries = computed(() => {
  const wanted = new Set(selectedEntryIds.value);
  return entryRows.value.filter((entry) => wanted.has(entry.id));
});
const hasCharacterSelection = computed(() => selectedCharacterIds.value.length > 0);
const selectedCharacters = computed(() => {
  const wanted = new Set(selectedCharacterIds.value);
  return loreStore.characters.filter((character) => wanted.has(character.character_id));
});
const characterCopyConfirmDisabled = computed(
  () => !hasCharacterSelection.value || !characterCopyTarget.value || targetSessionOptions.value.length === 0,
);

onMounted(async () => {
  if (sessions.value.length === 0) {
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
  () => loreStore.entries,
  (entries) => {
    entryRows.value = entries.map((entry) => ({ ...entry, tags: [...entry.tags] }));
    const validIds = new Set(entryRows.value.map((entry) => entry.id));
    selectedEntryIds.value = selectedEntryIds.value.filter((entryId) => validIds.has(entryId));
    if (activeEntryId.value && !validIds.has(activeEntryId.value)) {
      activeEntryId.value = null;
    }
    if (editingEntryId.value && !validIds.has(editingEntryId.value)) {
      closeEntryOverlay();
    }
  },
  { immediate: true, deep: true },
);

watch(
  () => loreStore.characters,
  (characters) => {
    const validIds = new Set(characters.map((item) => item.character_id));
    selectedCharacterIds.value = selectedCharacterIds.value.filter((id) => validIds.has(id));
    if (activeCharacterId.value && !validIds.has(activeCharacterId.value)) {
      activeCharacterId.value = null;
    }
    if (editingCharacterId.value && !validIds.has(editingCharacterId.value)) {
      closeCharacterOverlay();
    }
  },
  { immediate: true, deep: true },
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
    resetEntryListState();
    entryRows.value = [];
    entryFilter.value = entryCategory.value;
    resetCharacterListState();
    return;
  }
  await Promise.all([
    loreStore.loadEntries(currentSession.value.name, entryCategory.value),
    loreStore.loadCharacters(currentSession.value.name),
    loreStore.refreshSchedulerState(currentSession.value.name),
  ]);
  entryFilter.value = entryCategory.value;
  resetEntryListState();
  resetCharacterListState();
}

function parseTags(text: string): string[] {
  return text
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

async function handleEntryFilterChange(value: EntryCategory | null) {
  if (!value) {
    return;
  }
  entryFilter.value = value;
  entryCategory.value = value;
  activeTab.value = "entries";
  if (!currentSession.value?.name) {
    return;
  }
  await loreStore.loadEntries(currentSession.value.name, entryCategory.value);
  resetEntryListState();
}

function resetEntryListState() {
  selectedEntryIds.value = [];
  closeCopyModal();
  resetEntryOverlay();
}

function resetEntryOverlay() {
  activeEntryId.value = null;
  editingEntryId.value = null;
  entryOverlayVisible.value = false;
  entryOverlayTitle.value = "";
  entryOverlayFields.value = [];
  entryOverlayContent.value = "";
}

function entryTriggerLabel(entry: LoreEntry): string {
  return entry.constant ? "Const" : "RST";
}

function buildEntryOverlayFields(entry: {
  name: string;
  constant: boolean;
  tags: string[];
  disabled: boolean;
}): OverlayField[] {
  return [
    {
      key: "name",
      label: "Name",
      type: "text",
      value: entry.name,
    },
    {
      key: "trigger_mode",
      label: "Mode",
      type: "select",
      value: entry.constant ? "const" : "rst",
      options: triggerModeOptions,
    },
    {
      key: "tags",
      label: "关键词（逗号分隔）",
      type: "text",
      value: entry.tags.join(", "),
    },
    {
      key: "disabled",
      label: "Disabled",
      type: "toggle",
      value: entry.disabled,
    },
  ];
}

function openNewEntryOverlay() {
  editingEntryId.value = null;
  activeEntryId.value = null;
  entryOverlayTitle.value = "+新建条目";
  entryOverlayFields.value = buildEntryOverlayFields({
    name: "",
    constant: false,
    tags: [],
    disabled: false,
  });
  entryOverlayContent.value = "";
  entryOverlayVisible.value = true;
}

function openEntryOverlay(entryId: string) {
  const target = entryRows.value.find((entry) => entry.id === entryId);
  if (!target) {
    return;
  }
  activeEntryId.value = target.id;
  editingEntryId.value = target.id;
  entryOverlayTitle.value = `编辑: ${target.name}`;
  entryOverlayFields.value = buildEntryOverlayFields(target);
  entryOverlayContent.value = target.content;
  entryOverlayVisible.value = true;
}

function closeEntryOverlay() {
  entryOverlayVisible.value = false;
  editingEntryId.value = null;
  entryOverlayTitle.value = "";
  entryOverlayFields.value = [];
  entryOverlayContent.value = "";
}

async function handleEntryOverlaySave(data: { fields: Record<string, unknown>; content: string }) {
  if (!currentSession.value?.name) {
    return;
  }
  const name = String(data.fields.name ?? "").trim();
  if (!name) {
    message.error("请输入条目名称");
    return;
  }
  const triggerMode = String(data.fields.trigger_mode ?? "rst");
  const payload = {
    name,
    content: data.content,
    tags: parseTags(String(data.fields.tags ?? "")),
    disabled: Boolean(data.fields.disabled),
    constant: triggerMode === "const",
  };

  const result = editingEntryId.value
    ? await loreStore.updateEntry(currentSession.value.name, editingEntryId.value, payload)
    : await loreStore.createEntry(currentSession.value.name, {
        ...payload,
        category: entryCategory.value,
      });

  if (!result) {
    return;
  }
  activeEntryId.value = result.id;
  closeEntryOverlay();
}

async function removeEntryFromOverlay() {
  if (!currentSession.value?.name || !editingEntryId.value) {
    return;
  }
  const entryId = editingEntryId.value;
  await loreStore.deleteEntry(currentSession.value.name, entryId);
  selectedEntryIds.value = selectedEntryIds.value.filter((id) => id !== entryId);
  if (activeEntryId.value === entryId) {
    activeEntryId.value = null;
  }
  closeEntryOverlay();
}

async function handleEntryToggle(entryId: string, enabled: boolean) {
  if (!currentSession.value?.name) {
    return;
  }
  const target = entryRows.value.find((entry) => entry.id === entryId);
  if (!target) {
    return;
  }
  await loreStore.updateEntry(currentSession.value.name, target.id, {
    disabled: !enabled,
  });
}

function toggleEntrySelected(entryId: string, checked: boolean) {
  if (checked) {
    if (!selectedEntryIds.value.includes(entryId)) {
      selectedEntryIds.value = [...selectedEntryIds.value, entryId];
    }
    return;
  }
  selectedEntryIds.value = selectedEntryIds.value.filter((id) => id !== entryId);
}

async function handleBulkDeleteEntries() {
  if (!currentSession.value?.name || !hasSelection.value) {
    return;
  }
  const ids = [...selectedEntryIds.value];
  for (const id of ids) {
    await loreStore.deleteEntry(currentSession.value.name, id);
  }
  selectedEntryIds.value = [];
  if (activeEntryId.value && ids.includes(activeEntryId.value)) {
    activeEntryId.value = null;
  }
  if (editingEntryId.value && ids.includes(editingEntryId.value)) {
    closeEntryOverlay();
  }
}

function openCopyModal() {
  if (copyDisabled.value) {
    return;
  }
  copyTargetSession.value = targetSessionOptions.value[0]?.value ?? null;
  copyModalVisible.value = true;
}

function closeCopyModal() {
  copyModalVisible.value = false;
  copyTargetSession.value = null;
}

async function confirmCopy() {
  if (!copyTargetSession.value || selectedEntries.value.length === 0) {
    return;
  }
  let copiedCount = 0;
  for (const entry of selectedEntries.value) {
    if (entry.category === "character" || entry.category === "memory") {
      continue;
    }
    const created = await loreStore.createEntry(copyTargetSession.value, {
      name: entry.name,
      category: entry.category,
      content: entry.content,
      tags: [...entry.tags],
      disabled: entry.disabled,
      constant: entry.constant,
    });
    if (created) {
      copiedCount += 1;
    }
  }
  closeCopyModal();
  if (copiedCount > 0) {
    message.success(`已复制 ${copiedCount} 个条目到目标 Session`);
  }
}

async function handleEntryReorder() {
  if (!currentSession.value?.name || entryRows.value.length === 0) {
    return;
  }
  const reordered = await loreStore.reorderEntries(currentSession.value.name, {
    category: entryCategory.value,
    entry_ids: entryRows.value.map((entry) => entry.id),
  });
  if (!reordered) {
    entryRows.value = loreStore.entries.map((entry) => ({ ...entry, tags: [...entry.tags] }));
  }
}

function resetCharacterOverlay() {
  activeCharacterId.value = null;
  editingCharacterId.value = null;
  characterOverlayVisible.value = false;
  characterOverlayTitle.value = "";
  characterOverlayFields.value = [];
  characterOverlayContent.value = "";
}

function resetCharacterListState() {
  selectedCharacterIds.value = [];
  closeCharacterCopyModal();
  resetCharacterOverlay();
}

function characterModeLabel(character: CharacterData): string {
  return character.constant ? "Const" : "RST";
}

function buildCharacterOverlayFields(character: {
  name: string;
  race: string;
  role: string;
  faction: string;
  objective: string;
  tags: string[];
  constant: boolean;
  disabled: boolean;
}): OverlayField[] {
  return [
    {
      key: "name",
      label: "Name",
      type: "text",
      value: character.name,
    },
    {
      key: "race",
      label: "Race",
      type: "text",
      value: character.race,
    },
    {
      key: "role",
      label: "Role",
      type: "text",
      value: character.role,
    },
    {
      key: "faction",
      label: "Faction",
      type: "text",
      value: character.faction,
    },
    {
      key: "objective",
      label: "Objective",
      type: "text",
      value: character.objective,
    },
    {
      key: "tags",
      label: "Tags",
      type: "text",
      value: character.tags.join(", "),
    },
    {
      key: "mode",
      label: "Mode",
      type: "select",
      value: character.constant ? "const" : "rst",
      options: triggerModeOptions,
    },
    {
      key: "disabled",
      label: "Disabled",
      type: "toggle",
      value: character.disabled,
    },
  ];
}

function openNewCharacterOverlay() {
  editingCharacterId.value = null;
  activeCharacterId.value = null;
  characterOverlayTitle.value = "+新建人物";
  characterOverlayFields.value = buildCharacterOverlayFields({
    name: "",
    race: "",
    role: "",
    faction: "",
    objective: "",
    tags: [],
    constant: false,
    disabled: false,
  });
  characterOverlayContent.value = "";
  characterOverlayVisible.value = true;
}

function openCharacterOverlay(characterId: string) {
  const target = loreStore.characters.find((item) => item.character_id === characterId);
  if (!target) {
    return;
  }
  activeCharacterId.value = target.character_id;
  editingCharacterId.value = target.character_id;
  characterOverlayTitle.value = `编辑: ${target.name}`;
  characterOverlayFields.value = buildCharacterOverlayFields({
    name: target.name,
    race: target.race,
    role: target.role,
    faction: target.faction,
    objective: target.objective,
    tags: target.tags,
    constant: target.constant,
    disabled: target.disabled,
  });
  characterOverlayContent.value = target.personality;
  characterOverlayVisible.value = true;
}

function closeCharacterOverlay() {
  characterOverlayVisible.value = false;
  editingCharacterId.value = null;
  characterOverlayTitle.value = "";
  characterOverlayFields.value = [];
  characterOverlayContent.value = "";
}

async function handleCharacterOverlaySave(data: {
  fields: Record<string, unknown>;
  content: string;
}) {
  if (!currentSession.value?.name) {
    return;
  }
  const name = String(data.fields.name ?? "").trim();
  const race = String(data.fields.race ?? "").trim();
  if (!name || !race) {
    message.error("人物名称和种族不能为空");
    return;
  }
  const payload = {
    name,
    race,
    role: String(data.fields.role ?? ""),
    faction: String(data.fields.faction ?? ""),
    objective: String(data.fields.objective ?? ""),
    personality: data.content,
    tags: parseTags(String(data.fields.tags ?? "")),
    disabled: Boolean(data.fields.disabled),
    constant: String(data.fields.mode ?? "rst") === "const",
  };

  const result = editingCharacterId.value
    ? await loreStore.updateCharacter(currentSession.value.name, editingCharacterId.value, payload)
    : await loreStore.createCharacter(currentSession.value.name, payload);

  if (!result) {
    return;
  }
  activeCharacterId.value = result.character_id;
  closeCharacterOverlay();
}

async function removeCharacterFromOverlay() {
  if (!currentSession.value?.name || !editingCharacterId.value) {
    return;
  }
  const characterId = editingCharacterId.value;
  await loreStore.deleteCharacter(currentSession.value.name, characterId);
  selectedCharacterIds.value = selectedCharacterIds.value.filter((id) => id !== characterId);
  if (activeCharacterId.value === characterId) {
    activeCharacterId.value = null;
  }
  closeCharacterOverlay();
}

async function handleCharacterToggle(characterId: string, enabled: boolean) {
  if (!currentSession.value?.name) {
    return;
  }
  const target = loreStore.characters.find((item) => item.character_id === characterId);
  if (!target) {
    return;
  }
  await loreStore.updateCharacter(currentSession.value.name, characterId, {
    disabled: !enabled,
  });
}

function toggleCharacterSelected(characterId: string, checked: boolean) {
  if (checked) {
    if (!selectedCharacterIds.value.includes(characterId)) {
      selectedCharacterIds.value = [...selectedCharacterIds.value, characterId];
    }
    return;
  }
  selectedCharacterIds.value = selectedCharacterIds.value.filter((id) => id !== characterId);
}

async function handleBulkDeleteCharacters() {
  if (!currentSession.value?.name || !hasCharacterSelection.value) {
    return;
  }
  const ids = [...selectedCharacterIds.value];
  for (const characterId of ids) {
    await loreStore.deleteCharacter(currentSession.value.name, characterId);
  }
  selectedCharacterIds.value = [];
  if (activeCharacterId.value && ids.includes(activeCharacterId.value)) {
    activeCharacterId.value = null;
  }
  if (editingCharacterId.value && ids.includes(editingCharacterId.value)) {
    closeCharacterOverlay();
  }
}

function openCharacterCopyModal() {
  if (!hasCharacterSelection.value) {
    return;
  }
  characterCopyTarget.value = targetSessionOptions.value[0]?.value ?? null;
  characterCopyModalVisible.value = true;
}

function closeCharacterCopyModal() {
  characterCopyModalVisible.value = false;
  characterCopyTarget.value = null;
}

async function confirmCharacterCopy() {
  if (!characterCopyTarget.value || selectedCharacters.value.length === 0) {
    return;
  }
  let copiedCount = 0;
  for (const character of selectedCharacters.value) {
    const created = await loreStore.createCharacter(characterCopyTarget.value, {
      name: character.name,
      race: character.race,
      birth: character.birth,
      homeland: character.homeland,
      aliases: [...character.aliases],
      role: character.role,
      faction: character.faction,
      objective: character.objective,
      personality: character.personality,
      relationship: character.relationship.map((item) => ({ ...item })),
      tags: [...character.tags],
      disabled: character.disabled,
      constant: character.constant,
    });
    if (created) {
      copiedCount += 1;
    }
  }
  closeCharacterCopyModal();
  if (copiedCount > 0) {
    message.success(`已复制 ${copiedCount} 个人物到目标 Session`);
  }
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

function openImportPicker() {
  if (!currentSession.value) {
    return;
  }
  importInputRef.value?.click();
}

function handleFileChange(event: Event) {
  const target = event.target as HTMLInputElement;
  const files = target.files ? Array.from(target.files) : [];
  if (files.length === 0) {
    return;
  }
  importingFile.value = files[0];
  splitFactionCharacters.value = false;
  importModalVisible.value = true;
  // Reset input value so selecting the same file triggers change again.
  target.value = "";
}

function closeImportModal() {
  importModalVisible.value = false;
  importingFile.value = null;
  splitFactionCharacters.value = false;
}

async function confirmImportLore() {
  if (!currentSession.value?.name || !importingFile.value) {
    return;
  }
  const report = await loreStore.importLore(
    currentSession.value.name,
    importingFile.value,
    splitFactionCharacters.value,
  );
  if (!report) {
    return;
  }
  closeImportModal();
  const entryCount = report.statistics.converted_entries ?? 0;
  const characterCount = report.statistics.converted_characters ?? 0;
  const warningCount = report.statistics.warnings_count ?? 0;
  message.success(
    `导入完成：${entryCount} 个条目 + ${characterCount} 个人物，${warningCount} 个警告`,
  );
  if ((report.errors?.length ?? 0) > 0) {
    message.warning(`导入包含 ${report.errors.length} 条错误，请检查转换报告。`);
  }
  importReport.value = report;
  reportOverlayVisible.value = true;
  await Promise.all([
    loreStore.loadEntries(currentSession.value.name, entryCategory.value),
    loreStore.loadCharacters(currentSession.value.name),
  ]);
}

function actionLabel(action: string): string {
  const labels: Record<string, string> = {
    generic_entry_created: "普通条目导入",
    faction_entry_created: "势力条目导入",
    faction_kept_with_embedded_characters: "势力条目保留（含内嵌人物）",
    faction_split_into_characters: "势力条目拆分人物",
    character_structured_created: "人物结构化导入",
    character_yaml_fallback_created: "人物兜底导入",
    entry_failed: "条目导入失败",
  };
  return labels[action] ?? action;
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

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.panel-title {
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hidden-file-input {
  display: none;
}

.panel-body {
  margin-top: 12px;
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.panel-body :deep(.n-spin-container) {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.panel-body :deep(.n-tabs) {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.panel-body :deep(.n-tabs-pane-wrapper) {
  flex: 1;
  min-height: 0;
}

.panel-body :deep(.n-tab-pane) {
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 10px;
}

.entries-filter-row {
  display: flex;
  justify-content: flex-start;
  gap: 8px;
  margin-bottom: 10px;
}

.entries-filter-row :deep(.n-select) {
  width: 170px;
}

.entries-panel {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  background: var(--rst-bg-topbar);
  overflow: hidden;
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.entries-actions-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 8px 10px;
  border-bottom: 1px solid var(--rst-border-color);
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--rst-bg-topbar);
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
  min-width: 30px;
  padding-inline: 8px;
}

.entries-action--danger {
  color: #dc2626;
}

.icon-trash {
  width: 16px;
  height: 16px;
  display: block;
}

.entry-list {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
}

.entry-row {
  border-bottom: 1px solid var(--rst-border-color);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 10px;
  color: var(--rst-text-primary);
  background: transparent;
}

.entry-row:hover,
.entry-row.active {
  background: rgba(59, 130, 246, 0.2);
}

.character-row {
  width: 100%;
  border: none;
  border-bottom: 1px solid var(--rst-border-color);
  text-align: left;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 10px;
  color: var(--rst-text-primary);
  background: transparent;
}

.character-row:hover,
.character-row.active {
  background: rgba(59, 130, 246, 0.2);
}

.drag-handle {
  user-select: none;
  cursor: grab;
  color: var(--rst-text-secondary);
  line-height: 1;
}

.entry-checkbox {
  display: flex;
  align-items: center;
}

.entry-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.entry-name {
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.entry-meta {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.entry-toggle {
  display: flex;
  align-items: center;
}

.entry-mode {
  font-size: 11px;
  color: var(--rst-text-secondary);
  min-width: 40px;
}

.entry-list-empty {
  flex: 1;
  min-height: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  color: var(--rst-text-secondary);
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

.copy-modal-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.copy-hint {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.copy-modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.import-modal-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.import-meta-row {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 13px;
}

.import-meta-label {
  color: var(--rst-text-secondary);
}

.import-warning {
  font-size: 12px;
  color: var(--rst-text-secondary);
  line-height: 1.45;
}

.import-modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.report-modal-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
  max-height: 70vh;
}

.report-summary {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.report-action-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  overflow-y: auto;
  padding-right: 2px;
}

.report-action-card {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  padding: 10px;
  background: var(--rst-bg-topbar);
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.report-action-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.report-action-title {
  font-size: 13px;
  font-weight: 600;
}

.report-action-meta {
  font-size: 12px;
  color: var(--rst-text-secondary);
  line-height: 1.4;
}

.report-action-section {
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 12px;
}

.report-action-label {
  font-weight: 600;
}

.report-action-line {
  color: var(--rst-text-secondary);
  line-height: 1.4;
}

.report-action-section.warning .report-action-line {
  color: #d97706;
}

.report-action-section.error .report-action-line {
  color: #dc2626;
}

.report-footer {
  display: flex;
  justify-content: flex-end;
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
