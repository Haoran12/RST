<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">{{ t("rstPanel.title") }}</div>
      <div class="header-actions">
        <n-button
          size="small"
          secondary
          :disabled="!currentSession || loreStore.loading"
          @click="openImportPicker"
        >
          {{ t("rstPanel.import.open") }}
        </n-button>
        <n-tag size="small" :bordered="false" type="info">
          {{ currentSession?.name ?? t("rstPanel.session.unselected") }}
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
      <div class="empty-icon">{{ t("rstPanel.session.unselected") }}</div>
      <div>{{ t("rstPanel.empty.hint") }}</div>
    </div>

    <n-spin v-else :show="loreStore.loading" class="panel-body">
      <n-tabs v-model:value="activeTab" type="line" animated>
        <n-tab-pane name="entries" :tab="t('rstPanel.tabs.entries')">
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
              <div class="entries-title">{{ t("rstPanel.entries.title") }}</div>
              <div class="entries-actions">
                <n-button size="small" type="primary" @click="openNewEntryOverlay">
                  {{ t("rstPanel.entries.new") }}
                </n-button>
                <n-popconfirm
                  :show-icon="false"
                  :positive-text="t('common.confirm')"
                  :positive-button-props="{ type: 'error' }"
                  @positive-click="handleBulkDeleteEntries"
                >
                  <template #trigger>
                    <n-button
                      size="small"
                      secondary
                      class="entries-action entries-action--danger"
                      :disabled="!hasSelection"
                      :aria-label="t('rstPanel.entries.delete_selected_aria')"
                      :title="t('rstPanel.actions.delete')"
                    >
                      <svg class="icon-trash" viewBox="0 0 24 24" aria-hidden="true">
                        <path
                          d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v9h-2V9zm4 0h2v9h-2V9zM7 9h2v9H7V9z"
                          fill="currentColor"
                        />
                      </svg>
                    </n-button>
                  </template>
                  {{ t("rstPanel.entries.delete_selected_confirm") }}
                </n-popconfirm>
                <n-button
                  size="small"
                  secondary
                  class="entries-action"
                  :disabled="copyDisabled"
                  :aria-label="t('rstPanel.entries.copy_selected_aria')"
                  :title="t('rstPanel.actions.copy')"
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

            <div v-else class="entry-list-empty">{{ t("rstPanel.entries.empty") }}</div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="characters" :tab="t('rstPanel.tabs.characters')">
          <div class="entries-panel">
            <div class="entries-actions-row">
              <div class="entries-title">{{ t("rstPanel.characters.title") }}</div>
              <div class="entries-actions">
                <n-button size="small" type="primary" @click="openNewCharacterOverlay">
                  {{ t("rstPanel.characters.new") }}
                </n-button>
                <n-popconfirm
                  :show-icon="false"
                  :positive-text="t('common.confirm')"
                  :positive-button-props="{ type: 'error' }"
                  @positive-click="handleBulkDeleteCharacters"
                >
                  <template #trigger>
                    <n-button
                      size="small"
                      secondary
                      class="entries-action entries-action--danger"
                      :disabled="!hasCharacterSelection"
                      :aria-label="t('rstPanel.characters.delete_selected_aria')"
                      :title="t('rstPanel.actions.delete')"
                    >
                      <svg class="icon-trash" viewBox="0 0 24 24" aria-hidden="true">
                        <path
                          d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v9h-2V9zm4 0h2v9h-2V9zM7 9h2v9H7V9z"
                          fill="currentColor"
                        />
                      </svg>
                    </n-button>
                  </template>
                  {{ t("rstPanel.characters.delete_selected_confirm") }}
                </n-popconfirm>
                <n-button
                  size="small"
                  secondary
                  class="entries-action"
                  :disabled="!hasCharacterSelection"
                  :aria-label="t('rstPanel.characters.copy_selected_aria')"
                  :title="t('rstPanel.actions.copy')"
                  @click="openCharacterCopyModal"
                >
                  ⧉
                </n-button>
              </div>
            </div>

            <Draggable
              v-if="characterRows.length > 0"
              v-model="characterRows"
              item-key="character_id"
              handle=".drag-handle"
              class="entry-list"
              @end="handleCharacterReorder"
            >
              <template #item="{ element }">
                <div
                  class="character-row"
                  :class="{ active: element.character_id === activeCharacterId }"
                  @click="openCharacterOverlay(element.character_id)"
                >
                  <div class="drag-handle" @click.stop>⋮⋮</div>
                  <div class="entry-checkbox" @click.stop>
                    <n-checkbox
                      size="small"
                      :checked="selectedCharacterIds.includes(element.character_id)"
                      @update:checked="(checked) => toggleCharacterSelected(element.character_id, checked)"
                    />
                  </div>
                  <div class="entry-main">
                    <span class="entry-name">{{ element.name }}</span>
                  </div>
                  <div class="entry-mode">{{ characterModeLabel(element) }}</div>
                  <div class="entry-toggle" @click.stop>
                    <n-switch
                      :value="!element.disabled"
                      @update:value="(enabled) => handleCharacterToggle(element.character_id, enabled)"
                    />
                  </div>
                </div>
              </template>
            </Draggable>

            <div v-else class="entry-list-empty">{{ t("rstPanel.characters.empty") }}</div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="scheduler" :tab="t('rstPanel.tabs.scheduler')">
          <div class="scheduler-card">
            <div class="status-grid">
              <div>
                <div class="status-label">{{ t("rstPanel.scheduler.schedule") }}</div>
                <div class="status-value">
                  {{ runtimeStateLabel(Boolean(loreStore.scheduleStatus?.running)) }}
                </div>
                <div class="status-meta">
                  {{ t("rstPanel.scheduler.match_count") }}:
                  {{ loreStore.scheduleStatus?.last_matched_count ?? 0 }}
                </div>
              </div>
              <div>
                <div class="status-label">{{ t("rstPanel.scheduler.sync") }}</div>
                <div class="status-value">
                  {{ runtimeStateLabel(Boolean(loreStore.syncStatus?.running)) }}
                </div>
                <div class="status-meta">
                  {{ t("rstPanel.scheduler.round") }}:
                  {{ loreStore.syncStatus?.rounds_since_last_sync ?? 0 }} /
                  {{ loreStore.syncStatus?.sync_interval ?? 0 }}
                </div>
              </div>
            </div>

            <n-space>
              <n-button size="small" @click="refreshSchedulerState">
                {{ t("rstPanel.scheduler.refresh") }}
              </n-button>
              <n-button size="small" type="primary" @click="triggerScheduleNow">
                {{ t("rstPanel.scheduler.run_schedule") }}
              </n-button>
              <n-button size="small" type="warning" @click="triggerSyncNow">
                {{ t("rstPanel.scheduler.run_sync") }}
              </n-button>
            </n-space>

            <n-input
              v-model:value="templateForm.confirm_prompt"
              type="textarea"
              :autosize="{ minRows: 5 }"
              :placeholder="t('rstPanel.scheduler.placeholder.confirm_prompt')"
            />
            <n-input
              v-model:value="templateForm.extract_prompt"
              type="textarea"
              :autosize="{ minRows: 5 }"
              :placeholder="t('rstPanel.scheduler.placeholder.extract_prompt')"
            />
            <n-input
              v-model:value="templateForm.consolidate_prompt"
              type="textarea"
              :autosize="{ minRows: 5 }"
              :placeholder="t('rstPanel.scheduler.placeholder.consolidate_prompt')"
            />
            <n-button size="small" type="primary" @click="saveTemplate">
              {{ t("rstPanel.scheduler.save_template") }}
            </n-button>
          </div>
        </n-tab-pane>
      </n-tabs>
    </n-spin>

    <ContentOverlay
      :visible="entryOverlayVisible"
      :title="entryOverlayTitle"
      :fields="entryOverlayFields"
      :bottom-field-keys="['tags']"
      :content-value="entryOverlayContent"
      :content-label="t('rstPanel.overlay.entry.content_label')"
      @save="handleEntryOverlaySave"
      @discard="closeEntryOverlay"
    />

    <ContentOverlay
      :visible="characterOverlayVisible"
      :title="characterOverlayTitle"
      :fields="characterOverlayFields"
      :sections="characterOverlaySections"
      :section-collapsible="true"
      :section-filterable="true"
      :section-filter-placeholder="t('rstPanel.overlay.character.filter_placeholder')"
      :content-value="characterOverlayContent"
      :content-label="t('rstPanel.overlay.character.content_label')"
      @save="handleCharacterOverlaySave"
      @discard="closeCharacterOverlay"
    />

    <n-modal
      v-model:show="copyModalVisible"
      preset="card"
      :title="t('rstPanel.copy.modal_title_entry')"
      size="small"
    >
      <div class="copy-modal-body">
        <n-select
          v-model:value="copyTargetSession"
          :options="targetSessionOptions"
          :placeholder="t('rstPanel.copy.target_placeholder')"
          :disabled="targetSessionOptions.length === 0"
        />
        <div v-if="targetSessionOptions.length === 0" class="copy-hint">
          {{ t("rstPanel.copy.no_target") }}
        </div>
      </div>
      <template #footer>
        <div class="copy-modal-actions">
          <n-button secondary @click="closeCopyModal">{{ t("common.cancel") }}</n-button>
          <n-button type="primary" :disabled="copyConfirmDisabled" @click="confirmCopy">
            {{ t("rstPanel.copy.confirm") }}
          </n-button>
        </div>
      </template>
    </n-modal>

    <n-modal
      v-model:show="characterCopyModalVisible"
      preset="card"
      :title="t('rstPanel.copy.modal_title_character')"
      size="small"
    >
      <div class="copy-modal-body">
        <n-select
          v-model:value="characterCopyTarget"
          :options="targetSessionOptions"
          :placeholder="t('rstPanel.copy.target_placeholder')"
          :disabled="targetSessionOptions.length === 0"
        />
        <div v-if="targetSessionOptions.length === 0" class="copy-hint">
          {{ t("rstPanel.copy.no_target") }}
        </div>
      </div>
      <template #footer>
        <div class="copy-modal-actions">
          <n-button secondary @click="closeCharacterCopyModal">{{ t("common.cancel") }}</n-button>
          <n-button
            type="primary"
            :disabled="characterCopyConfirmDisabled"
            @click="confirmCharacterCopy"
          >
            {{ t("rstPanel.copy.confirm") }}
          </n-button>
        </div>
      </template>
    </n-modal>

    <n-modal
      v-model:show="importModalVisible"
      preset="card"
      :title="t('rstPanel.import.modal_title')"
      size="small"
    >
      <div class="import-modal-body">
        <div class="import-meta-row">
          <span class="import-meta-label">{{ t("rstPanel.import.file_label") }}</span>
          <span>{{ importingFile?.name ?? "-" }}</span>
        </div>
        <div class="import-meta-row">
          <span class="import-meta-label">{{ t("rstPanel.import.target_session_label") }}</span>
          <span>{{ currentSession?.name ?? "-" }}</span>
        </div>
        <div class="import-warning">{{ t("rstPanel.import.warning_append") }}</div>
        <n-checkbox v-model:checked="splitFactionCharacters">
          {{ t("rstPanel.import.split_faction_characters") }}
        </n-checkbox>
      </div>
      <template #footer>
        <div class="import-modal-actions">
          <n-button secondary @click="closeImportModal">{{ t("common.cancel") }}</n-button>
          <n-button
            type="primary"
            :disabled="!importingFile"
            :loading="loreStore.loading"
            @click="confirmImportLore"
          >
            {{ t("rstPanel.import.confirm") }}
          </n-button>
        </div>
      </template>
    </n-modal>

    <n-modal
      v-model:show="reportOverlayVisible"
      preset="card"
      :title="t('rstPanel.report.title')"
      size="large"
    >
      <div v-if="importReport" class="report-modal-body">
        <div class="report-summary">
          <div>{{ t("rstPanel.report.summary.source_file") }}: {{ importReport.source_file }}</div>
          <div>{{ t("rstPanel.report.summary.session") }}: {{ importReport.session_name }}</div>
          <div>
            {{ t("rstPanel.report.summary.total_source_entries") }}:
            {{ importReport.statistics.total_source_entries ?? 0 }}
          </div>
          <div>
            {{ t("rstPanel.report.summary.converted_entries") }}:
            {{ importReport.statistics.converted_entries ?? 0 }}
          </div>
          <div>
            {{ t("rstPanel.report.summary.converted_characters") }}:
            {{ importReport.statistics.converted_characters ?? 0 }}
          </div>
          <div>
            {{ t("rstPanel.report.summary.warnings_count") }}:
            {{ importReport.statistics.warnings_count ?? 0 }}
          </div>
          <div>
            {{ t("rstPanel.report.summary.errors_count") }}:
            {{ importReport.statistics.errors_count ?? 0 }}
          </div>
        </div>

        <div class="report-action-list">
          <div
            v-for="(actionItem, index) in importReport.actions"
            :key="`${actionItem.source_id}-${index}`"
            class="report-action-card"
          >
            <div class="report-action-header">
              <div class="report-action-title">
                {{ index + 1 }}. {{ actionItem.name || t("rstPanel.report.unnamed_entry") }}
              </div>
              <n-tag size="small" :bordered="false" type="info">
                {{ actionLabel(actionItem.action) }}
              </n-tag>
            </div>
            <div class="report-action-meta">
              {{ t("rstPanel.report.action.source_id") }}: {{ actionItem.source_id || "-" }}
            </div>
            <div class="report-action-meta">
              {{ t("rstPanel.report.action.category") }}: {{ actionItem.source_category || "-" }} ->
              {{ actionItem.target_category || "-" }}
            </div>
            <div v-if="actionItem.created_ids.length > 0" class="report-action-meta">
              {{ t("rstPanel.report.action.created_ids") }}: {{ actionItem.created_ids.join(", ") }}
            </div>
            <div v-if="actionItem.notes.length > 0" class="report-action-section">
              <div class="report-action-label">{{ t("rstPanel.report.action.notes") }}</div>
              <div
                v-for="(note, noteIndex) in actionItem.notes"
                :key="`${actionItem.source_id}-note-${noteIndex}`"
                class="report-action-line"
              >
                - {{ note }}
              </div>
            </div>
            <div v-if="actionItem.warnings.length > 0" class="report-action-section warning">
              <div class="report-action-label">{{ t("rstPanel.report.action.warnings") }}</div>
              <div
                v-for="(warn, warnIndex) in actionItem.warnings"
                :key="`${actionItem.source_id}-warn-${warnIndex}`"
                class="report-action-line"
              >
                - {{ warn }}
              </div>
            </div>
            <div v-if="actionItem.errors.length > 0" class="report-action-section error">
              <div class="report-action-label">{{ t("rstPanel.report.action.errors") }}</div>
              <div
                v-for="(err, errIndex) in actionItem.errors"
                :key="`${actionItem.source_id}-err-${errIndex}`"
                class="report-action-line"
              >
                - {{ err }}
              </div>
            </div>
          </div>
        </div>
      </div>
      <template #footer>
        <div class="report-footer">
          <n-button secondary @click="reportOverlayVisible = false">
            {{ t("rstPanel.report.close") }}
          </n-button>
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
import { useI18n } from "@/composables/useI18n";
import { useLoreStore } from "@/stores/lore";
import { useSessionStore } from "@/stores/session";
import { message } from "@/utils/message";

import type {
  CharacterData,
  CharacterForm,
  ConversionReport,
  LoreCategory,
  LoreEntry,
  Relationship,
} from "@/types/lore";

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "textarea" | "number" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: Array<{ label: string; value: string | number }>;
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

const sessionStore = useSessionStore();
const loreStore = useLoreStore();
const { t } = useI18n();
const { currentSession, sessions } = storeToRefs(sessionStore);

type EntryCategory = Exclude<LoreCategory, "character" | "memory">;

const activeTab = ref<"entries" | "characters" | "scheduler">("entries");
const entryCategory = ref<EntryCategory>("world_base");
const entryFilter = ref<EntryCategory>("world_base");

const entryCategoryOptions = computed<Array<{ label: string; value: EntryCategory }>>(() => [
  { label: t("rstPanel.category.world_base"), value: "world_base" },
  { label: t("rstPanel.category.society"), value: "society" },
  { label: t("rstPanel.category.place"), value: "place" },
  { label: t("rstPanel.category.faction"), value: "faction" },
  { label: t("rstPanel.category.skills"), value: "skills" },
  { label: t("rstPanel.category.others"), value: "others" },
  { label: t("rstPanel.category.plot"), value: "plot" },
]);

const entryFilterOptions = computed(() => entryCategoryOptions.value);

const triggerModeOptions = computed(() => [
  { label: t("rstPanel.mode.rst"), value: "rst" },
  { label: t("rstPanel.mode.const"), value: "const" },
]);

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
const characterOverlaySections = ref<OverlaySection[]>([]);
const characterOverlayContent = ref("");
const characterRows = ref<CharacterData[]>([]);
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
  return characterRows.value.filter((character) => wanted.has(character.character_id));
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
    characterRows.value = [...characters];
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
    characterRows.value = [];
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

function formatText(key: string, params: Record<string, string | number>): string {
  let text = t(key);
  Object.entries(params).forEach(([paramKey, paramValue]) => {
    text = text.replaceAll(`{${paramKey}}`, String(paramValue));
  });
  return text;
}

function runtimeStateLabel(running: boolean): string {
  return running ? t("rstPanel.scheduler.running") : t("rstPanel.scheduler.idle");
}

function parseTags(text: string): string[] {
  return text
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseDelimitedText(text: string): string[] {
  return text
    .split(/[\n,，]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function formatRelationships(relationship: Relationship[]): string {
  return relationship
    .map((item) => {
      const target = item.target.trim();
      const relation = item.relation.trim();
      if (!target && !relation) {
        return "";
      }
      if (!relation) {
        return target;
      }
      if (!target) {
        return `: ${relation}`;
      }
      return `${target}: ${relation}`;
    })
    .filter(Boolean)
    .join("\n");
}

function parseRelationships(text: string): Relationship[] {
  const rows = text
    .split("\n")
    .map((row) => row.trim())
    .filter(Boolean);
  return rows
    .map((row) => {
      const separator = row.includes("：") ? "：" : ":";
      if (!row.includes(separator)) {
        return { target: row, relation: "" };
      }
      const [targetRaw, ...relationChunks] = row.split(separator);
      const target = targetRaw.trim();
      const relation = relationChunks.join(separator).trim();
      return { target, relation };
    })
    .filter((item) => item.target || item.relation);
}

function parseNonNegativeInt(value: unknown, fallback: number): number {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  const integer = Math.floor(numeric);
  return integer >= 0 ? integer : fallback;
}

function parseStrength(value: unknown): number {
  return parseNonNegativeInt(value, 10);
}

function resolveCharacterActiveForm(character: {
  forms: CharacterForm[];
  active_form_id: string;
}): CharacterForm | null {
  if (character.forms.length === 0) {
    return null;
  }
  return (
    character.forms.find((form) => form.form_id === character.active_form_id) ??
    character.forms[0] ??
    null
  );
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
  return entry.constant ? t("rstPanel.mode.const_short") : t("rstPanel.mode.rst_short");
}

function buildEntryOverlayFields(entry: {
  name: string;
  category: EntryCategory;
  constant: boolean;
  tags: string[];
  disabled: boolean;
}): OverlayField[] {
  return [
    {
      key: "name",
      label: t("rstPanel.overlay.field.name"),
      type: "text",
      value: entry.name,
    },
    {
      key: "category",
      label: t("rstPanel.overlay.field.category"),
      type: "select",
      value: entry.category,
      options: entryCategoryOptions.value,
    },
    {
      key: "trigger_mode",
      label: t("rstPanel.overlay.field.trigger_mode"),
      type: "select",
      value: entry.constant ? "const" : "rst",
      options: triggerModeOptions.value,
    },
    {
      key: "tags",
      label: t("rstPanel.overlay.field.keywords"),
      type: "text",
      value: entry.tags.join(", "),
    },
    {
      key: "disabled",
      label: t("rstPanel.overlay.field.disabled"),
      type: "toggle",
      value: entry.disabled,
    },
  ];
}

function openNewEntryOverlay() {
  editingEntryId.value = null;
  activeEntryId.value = null;
  entryOverlayTitle.value = t("rstPanel.overlay.entry.create_title");
  entryOverlayFields.value = buildEntryOverlayFields({
    name: "",
    category: entryCategory.value,
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
  entryOverlayTitle.value = formatText("rstPanel.overlay.entry.edit_title", {
    name: target.name,
  });
  entryOverlayFields.value = buildEntryOverlayFields({
    ...target,
    category: parseEntryCategory(target.category),
  });
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

function parseEntryCategory(value: unknown): EntryCategory {
  const selected = String(value ?? "").trim();
  const matched = entryCategoryOptions.value.find((item) => item.value === selected);
  return matched ? matched.value : entryCategory.value;
}

async function handleEntryOverlaySave(data: { fields: Record<string, unknown>; content: string }) {
  if (!currentSession.value?.name) {
    return;
  }
  const name = String(data.fields.name ?? "").trim();
  if (!name) {
    message.error(t("rstPanel.messages.entry_name_required"));
    return;
  }
  const category = parseEntryCategory(data.fields.category);
  const triggerMode = String(data.fields.trigger_mode ?? "rst");
  const payload = {
    name,
    category,
    content: data.content,
    tags: parseTags(String(data.fields.tags ?? "")),
    disabled: Boolean(data.fields.disabled),
    constant: triggerMode === "const",
  };

  const result = editingEntryId.value
    ? await loreStore.updateEntry(currentSession.value.name, editingEntryId.value, payload)
    : await loreStore.createEntry(currentSession.value.name, payload);

  if (!result) {
    return;
  }
  activeEntryId.value = result.category === entryCategory.value ? result.id : null;
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
    message.success(
      formatText("rstPanel.messages.copy_entries_done", {
        count: copiedCount,
      }),
    );
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
  characterOverlaySections.value = [];
  characterOverlayContent.value = "";
}

function resetCharacterListState() {
  selectedCharacterIds.value = [];
  closeCharacterCopyModal();
  resetCharacterOverlay();
}

function characterModeLabel(character: CharacterData): string {
  return character.constant ? t("rstPanel.mode.const_short") : t("rstPanel.mode.rst_short");
}

interface CharacterOverlayValues {
  name: string;
  race: string;
  strength: number;
  form_name: string;
  is_default: boolean;
  physique: string;
  features: string;
  vitality_max: number;
  mana_potency: number;
  toughness: number;
  weak: string[];
  resist: string[];
  element: string[];
  skills: string[];
  penetration: string[];
  clothing: string;
  body: string;
  mind: string;
  vitality_cur: number;
  activity: string;
  birth: string;
  homeland: string;
  aliases: string[];
  role: string;
  faction: string;
  objective: string;
  relationship: Relationship[];
  tags: string[];
  constant: boolean;
  disabled: boolean;
}

function buildCharacterOverlayConfig(character: CharacterOverlayValues): {
  fields: OverlayField[];
  sections: OverlaySection[];
} {
  const fields: OverlayField[] = [
    {
      key: "name",
      label: t("rstPanel.overlay.field.name"),
      type: "text",
      value: character.name,
      placeholder: t("rstPanel.overlay.character.placeholder.name"),
    },
    {
      key: "race",
      label: t("rstPanel.overlay.character.field.race"),
      type: "text",
      value: character.race,
      placeholder: t("rstPanel.overlay.character.placeholder.race"),
    },
    {
      key: "strength",
      label: t("rstPanel.overlay.character.field.strength"),
      type: "number",
      value: character.strength,
      min: 0,
      step: 1,
      description: t("rstPanel.overlay.character.description.strength"),
    },
    {
      key: "form_name",
      label: t("rstPanel.overlay.character.field.form_name"),
      type: "text",
      value: character.form_name,
      placeholder: t("rstPanel.overlay.character.placeholder.form_name"),
      description: t("rstPanel.overlay.character.description.form_name"),
    },
    {
      key: "is_default",
      label: t("rstPanel.overlay.character.field.is_default"),
      type: "toggle",
      value: character.is_default,
    },
    {
      key: "physique",
      label: t("rstPanel.overlay.character.field.physique"),
      type: "textarea",
      value: character.physique,
      placeholder: t("rstPanel.overlay.character.placeholder.physique"),
      wide: true,
    },
    {
      key: "features",
      label: t("rstPanel.overlay.character.field.features"),
      type: "textarea",
      value: character.features,
      placeholder: t("rstPanel.overlay.character.placeholder.features"),
      wide: true,
    },
    {
      key: "vitality_max",
      label: t("rstPanel.overlay.character.field.vitality_max"),
      type: "number",
      value: character.vitality_max,
      min: 0,
      step: 1,
      description: t("rstPanel.overlay.character.description.vitality_max"),
    },
    {
      key: "mana_potency",
      label: t("rstPanel.overlay.character.field.mana_potency"),
      type: "number",
      value: character.mana_potency,
      min: 0,
      step: 1,
      description: t("rstPanel.overlay.character.description.mana_potency"),
    },
    {
      key: "toughness",
      label: t("rstPanel.overlay.character.field.toughness"),
      type: "number",
      value: character.toughness,
      min: 0,
      step: 1,
      description: t("rstPanel.overlay.character.description.toughness"),
    },
    {
      key: "vitality_cur",
      label: t("rstPanel.overlay.character.field.vitality_cur"),
      type: "number",
      value: character.vitality_cur,
      min: 0,
      step: 1,
      description: t("rstPanel.overlay.character.description.vitality_cur"),
    },
    {
      key: "weak",
      label: t("rstPanel.overlay.character.field.weak"),
      type: "textarea",
      value: character.weak.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.weak"),
      wide: true,
    },
    {
      key: "resist",
      label: t("rstPanel.overlay.character.field.resist"),
      type: "textarea",
      value: character.resist.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.resist"),
      wide: true,
    },
    {
      key: "element",
      label: t("rstPanel.overlay.character.field.element"),
      type: "textarea",
      value: character.element.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.element"),
      wide: true,
      description: t("rstPanel.overlay.character.description.element"),
    },
    {
      key: "skills",
      label: t("rstPanel.overlay.character.field.skills"),
      type: "textarea",
      value: character.skills.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.skills"),
      wide: true,
      description: t("rstPanel.overlay.character.description.skills"),
    },
    {
      key: "penetration",
      label: t("rstPanel.overlay.character.field.penetration"),
      type: "textarea",
      value: character.penetration.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.penetration"),
      wide: true,
      description: t("rstPanel.overlay.character.description.penetration"),
    },
    {
      key: "clothing",
      label: t("rstPanel.overlay.character.field.clothing"),
      type: "textarea",
      value: character.clothing,
      placeholder: t("rstPanel.overlay.character.placeholder.clothing"),
      wide: true,
    },
    {
      key: "body",
      label: t("rstPanel.overlay.character.field.body"),
      type: "textarea",
      value: character.body,
      placeholder: t("rstPanel.overlay.character.placeholder.body"),
      wide: true,
    },
    {
      key: "mind",
      label: t("rstPanel.overlay.character.field.mind"),
      type: "textarea",
      value: character.mind,
      placeholder: t("rstPanel.overlay.character.placeholder.mind"),
      wide: true,
    },
    {
      key: "activity",
      label: t("rstPanel.overlay.character.field.activity"),
      type: "text",
      value: character.activity,
      placeholder: t("rstPanel.overlay.character.placeholder.activity"),
    },
    {
      key: "birth",
      label: t("rstPanel.overlay.character.field.birth"),
      type: "text",
      value: character.birth,
      placeholder: t("rstPanel.overlay.character.placeholder.birth"),
    },
    {
      key: "homeland",
      label: t("rstPanel.overlay.character.field.homeland"),
      type: "text",
      value: character.homeland,
      placeholder: t("rstPanel.overlay.character.placeholder.homeland"),
    },
    {
      key: "role",
      label: t("rstPanel.overlay.character.field.role"),
      type: "text",
      value: character.role,
      placeholder: t("rstPanel.overlay.character.placeholder.role"),
    },
    {
      key: "faction",
      label: t("rstPanel.overlay.character.field.faction"),
      type: "text",
      value: character.faction,
      placeholder: t("rstPanel.overlay.character.placeholder.faction"),
    },
    {
      key: "objective",
      label: t("rstPanel.overlay.character.field.objective"),
      type: "text",
      value: character.objective,
      placeholder: t("rstPanel.overlay.character.placeholder.objective"),
    },
    {
      key: "aliases",
      label: t("rstPanel.overlay.character.field.aliases"),
      type: "text",
      value: character.aliases.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.aliases"),
    },
    {
      key: "tags",
      label: t("rstPanel.overlay.character.field.tags"),
      type: "text",
      value: character.tags.join(", "),
      placeholder: t("rstPanel.overlay.character.placeholder.tags"),
    },
    {
      key: "relationship",
      label: t("rstPanel.overlay.character.field.relationship"),
      type: "textarea",
      value: formatRelationships(character.relationship),
      placeholder: t("rstPanel.overlay.character.placeholder.relationship"),
      wide: true,
      description: t("rstPanel.overlay.character.description.relationship"),
    },
    {
      key: "mode",
      label: t("rstPanel.overlay.field.trigger_mode"),
      type: "select",
      value: character.constant ? "const" : "rst",
      options: triggerModeOptions.value,
    },
    {
      key: "disabled",
      label: t("rstPanel.overlay.field.disabled"),
      type: "toggle",
      value: character.disabled,
    },
  ];

  const fieldByKey = new Map(fields.map((field) => [field.key, field]));
  const sections: OverlaySection[] = [
    {
      key: "identity",
      title: t("rstPanel.overlay.character.section.identity.title"),
      description: t("rstPanel.overlay.character.section.identity.description"),
      columns: 3,
      fields: [
        fieldByKey.get("name")!,
        fieldByKey.get("race")!,
        fieldByKey.get("birth")!,
        fieldByKey.get("homeland")!,
      ],
    },
    {
      key: "profile",
      title: t("rstPanel.overlay.character.section.profile.title"),
      description: t("rstPanel.overlay.character.section.profile.description"),
      columns: 2,
      fields: [
        fieldByKey.get("role")!,
        fieldByKey.get("faction")!,
        fieldByKey.get("objective")!,
        fieldByKey.get("aliases")!,
        fieldByKey.get("tags")!,
        fieldByKey.get("relationship")!,
      ],
    },
    {
      key: "status",
      title: t("rstPanel.overlay.character.section.status.title"),
      description: t("rstPanel.overlay.character.section.status.description"),
      columns: 3,
      fields: [
        fieldByKey.get("vitality_max")!,
        fieldByKey.get("form_name")!,
        fieldByKey.get("is_default")!,
        fieldByKey.get("strength")!,
        fieldByKey.get("mana_potency")!,
        fieldByKey.get("toughness")!,
        fieldByKey.get("vitality_cur")!,
        fieldByKey.get("activity")!,
        fieldByKey.get("physique")!,
        fieldByKey.get("features")!,
        fieldByKey.get("weak")!,
        fieldByKey.get("resist")!,
        fieldByKey.get("element")!,
        fieldByKey.get("skills")!,
        fieldByKey.get("penetration")!,
        fieldByKey.get("clothing")!,
        fieldByKey.get("body")!,
        fieldByKey.get("mind")!,
      ],
    },
    {
      key: "runtime",
      title: t("rstPanel.overlay.character.section.runtime.title"),
      description: t("rstPanel.overlay.character.section.runtime.description"),
      columns: 2,
      fields: [fieldByKey.get("mode")!],
    },
  ];

  return { fields, sections };
}

function openNewCharacterOverlay() {
  editingCharacterId.value = null;
  activeCharacterId.value = null;
  characterOverlayTitle.value = t("rstPanel.overlay.character.create_title");
  const config = buildCharacterOverlayConfig({
    name: "",
    race: "",
    strength: 10,
    form_name: "默认形态",
    is_default: true,
    physique: "",
    features: "",
    vitality_max: 100,
    mana_potency: 100,
    toughness: 10,
    weak: [],
    resist: [],
    element: [],
    skills: [],
    penetration: [],
    clothing: "",
    body: "",
    mind: "",
    vitality_cur: 50,
    activity: "",
    birth: "",
    homeland: "",
    aliases: [],
    role: "",
    faction: "",
    objective: "",
    relationship: [],
    tags: [],
    constant: false,
    disabled: false,
  });
  characterOverlayFields.value = config.fields;
  characterOverlaySections.value = config.sections;
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
  characterOverlayTitle.value = formatText("rstPanel.overlay.character.edit_title", {
    name: target.name,
  });
  const activeForm = resolveCharacterActiveForm(target);
  const config = buildCharacterOverlayConfig({
    name: target.name,
    race: target.race,
    strength: target.strength,
    form_name: activeForm?.form_name ?? "默认形态",
    is_default: activeForm?.is_default ?? true,
    physique: activeForm?.physique ?? "",
    features: activeForm?.features ?? "",
    vitality_max: activeForm?.vitality_max ?? 100,
    mana_potency: activeForm?.mana_potency ?? 100,
    toughness: activeForm?.toughness ?? 10,
    weak: [...(activeForm?.weak ?? [])],
    resist: [...(activeForm?.resist ?? [])],
    element: [...(activeForm?.element ?? [])],
    skills: [...(activeForm?.skills ?? [])],
    penetration: [...(activeForm?.penetration ?? [])],
    clothing: activeForm?.clothing ?? "",
    body: activeForm?.body ?? "",
    mind: activeForm?.mind ?? "",
    vitality_cur: activeForm?.vitality_cur ?? 50,
    activity: activeForm?.activity ?? "",
    birth: target.birth,
    homeland: target.homeland,
    aliases: target.aliases,
    role: target.role,
    faction: target.faction,
    objective: target.objective,
    relationship: target.relationship,
    tags: target.tags,
    constant: target.constant,
    disabled: target.disabled,
  });
  characterOverlayFields.value = config.fields;
  characterOverlaySections.value = config.sections;
  characterOverlayContent.value = target.personality;
  characterOverlayVisible.value = true;
}

function closeCharacterOverlay() {
  characterOverlayVisible.value = false;
  editingCharacterId.value = null;
  characterOverlayTitle.value = "";
  characterOverlayFields.value = [];
  characterOverlaySections.value = [];
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
    message.error(t("rstPanel.messages.character_required_fields"));
    return;
  }
  const payload = {
    name,
    race,
    strength: parseStrength(data.fields.strength),
    birth: String(data.fields.birth ?? "").trim(),
    homeland: String(data.fields.homeland ?? "").trim(),
    aliases: parseDelimitedText(String(data.fields.aliases ?? "")),
    role: String(data.fields.role ?? ""),
    faction: String(data.fields.faction ?? ""),
    objective: String(data.fields.objective ?? ""),
    personality: data.content,
    relationship: parseRelationships(String(data.fields.relationship ?? "")),
    tags: parseTags(String(data.fields.tags ?? "")),
    disabled: Boolean(data.fields.disabled),
    constant: String(data.fields.mode ?? "rst") === "const",
  };
  const formPayload = {
    form_name: String(data.fields.form_name ?? "").trim() || undefined,
    is_default: Boolean(data.fields.is_default),
    physique: String(data.fields.physique ?? "").trim(),
    features: String(data.fields.features ?? "").trim(),
    vitality_max: parseNonNegativeInt(data.fields.vitality_max, 100),
    mana_potency: parseNonNegativeInt(data.fields.mana_potency, 100),
    toughness: parseNonNegativeInt(data.fields.toughness, 10),
    weak: parseDelimitedText(String(data.fields.weak ?? "")),
    resist: parseDelimitedText(String(data.fields.resist ?? "")),
    element: parseDelimitedText(String(data.fields.element ?? "")),
    skills: parseDelimitedText(String(data.fields.skills ?? "")),
    penetration: parseDelimitedText(String(data.fields.penetration ?? "")),
    clothing: String(data.fields.clothing ?? "").trim(),
    body: String(data.fields.body ?? "").trim(),
    mind: String(data.fields.mind ?? "").trim(),
    vitality_cur: parseNonNegativeInt(data.fields.vitality_cur, 50),
    activity: String(data.fields.activity ?? "").trim(),
  };

  const result = editingCharacterId.value
    ? await loreStore.updateCharacter(currentSession.value.name, editingCharacterId.value, payload)
    : await loreStore.createCharacter(currentSession.value.name, payload);

  if (!result) {
    return;
  }
  const activeForm = resolveCharacterActiveForm(result);
  if (activeForm) {
    await loreStore.updateCharacterForm(
      currentSession.value.name,
      result.character_id,
      activeForm.form_id,
      formPayload,
    );
  }
  activeCharacterId.value = result.character_id;
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

async function handleCharacterReorder() {
  if (!currentSession.value?.name || characterRows.value.length === 0) {
    return;
  }
  const reordered = await loreStore.reorderCharacters(currentSession.value.name, {
    character_ids: characterRows.value.map((character) => character.character_id),
  });
  if (!reordered) {
    characterRows.value = [...loreStore.characters];
  }
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
      strength: character.strength,
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
    message.success(
      formatText("rstPanel.messages.copy_characters_done", {
        count: copiedCount,
      }),
    );
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
    formatText("rstPanel.messages.import_done", {
      entries: entryCount,
      characters: characterCount,
      warnings: warningCount,
    }),
  );
  if ((report.errors?.length ?? 0) > 0) {
    message.warning(
      formatText("rstPanel.messages.import_has_errors", {
        count: report.errors.length,
      }),
    );
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
    generic_entry_created: t("rstPanel.report.action_type.generic_entry_created"),
    faction_entry_created: t("rstPanel.report.action_type.faction_entry_created"),
    faction_kept_with_embedded_characters: t(
      "rstPanel.report.action_type.faction_kept_with_embedded_characters",
    ),
    faction_split_into_characters: t("rstPanel.report.action_type.faction_split_into_characters"),
    character_structured_created: t("rstPanel.report.action_type.character_structured_created"),
    character_yaml_fallback_created: t("rstPanel.report.action_type.character_yaml_fallback_created"),
    entry_failed: t("rstPanel.report.action_type.entry_failed"),
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

