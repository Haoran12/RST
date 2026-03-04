<template>
  <aside class="status-panel" :class="{ 'is-collapsed': collapsed }" @click.stop>
    <button
      type="button"
      class="status-panel__toggle"
      :aria-label="collapsed ? t('statusPanel.action.expand') : t('statusPanel.action.collapse')"
      :title="collapsed ? t('statusPanel.action.expand') : t('statusPanel.action.collapse')"
      @click="handleToggle"
    >
      <svg class="status-panel__toggle-icon" viewBox="0 0 20 20" aria-hidden="true">
        <path
          v-if="collapsed"
          d="M12.5 4.5L7 10l5.5 5.5"
          fill="none"
          stroke="currentColor"
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.8"
        />
        <path
          v-else
          d="M7.5 4.5L13 10l-5.5 5.5"
          fill="none"
          stroke="currentColor"
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.8"
        />
      </svg>
    </button>

    <div v-if="!collapsed" class="status-panel__inner">
      <section class="status-panel__section status-panel__section--summary">
        <div class="summary-grid">
          <div class="summary-row">
            <span class="summary-label">{{ t("statusPanel.field.session") }}</span>
            <span class="summary-value">{{ sessionDisplay }}</span>
          </div>
          <div class="summary-row summary-row--content">
            <div class="summary-editor summary-editor--stacked">
              <input
                v-model="editStoryTime"
                class="summary-input"
                type="text"
                :aria-label="t('statusPanel.placeholder.story_time')"
                @keydown.enter.prevent="saveStorySnapshot"
              />
              <div class="summary-editor__row">
                <input
                  v-model="editStoryLocation"
                  class="summary-input"
                  type="text"
                  :aria-label="t('statusPanel.placeholder.story_place')"
                  @keydown.enter.prevent="saveStorySnapshot"
                />
                <button
                  type="button"
                  class="summary-save"
                  :disabled="savingStorySnapshot || !hasStorySnapshotChange || !currentSessionName"
                  @click="saveStorySnapshot"
                >
                  {{ t("statusPanel.action.save") }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="status-panel__section status-panel__section--characters">
        <div class="status-panel__section-head">
          <div class="status-panel__section-title">{{ t("statusPanel.section.characters") }}</div>
          <button
            type="button"
            class="refresh-button"
            :disabled="loading || !currentSessionName"
            @click="refreshData"
          >
            {{ t("statusPanel.action.refresh") }}
          </button>
        </div>

        <div v-if="loading" class="status-placeholder">
          {{ t("statusPanel.state.loading") }}
        </div>
        <div v-else-if="!currentSessionName" class="status-placeholder">
          {{ t("statusPanel.state.no_session") }}
        </div>
        <div v-else-if="presentCharacters.length === 0" class="status-placeholder">
          {{ t("statusPanel.state.no_character") }}
        </div>
        <div v-else class="character-layout">
          <div class="character-tabs">
            <button
              v-for="character in presentCharacters"
              :key="character.character_id"
              type="button"
              class="character-tab"
              :class="{ 'is-active': character.character_id === activeCharacter?.character_id }"
              @click="activeCharacterId = character.character_id"
            >
              {{ character.name || character.character_id }}
            </button>
          </div>

          <article v-if="activeCharacter" class="character-card">
            <header class="character-card__header">
              <div class="character-name-row">
                <div class="character-name">
                  {{ activeCharacter.name || activeCharacter.character_id }}
                </div>
                <span v-if="activeCharacterFormDisplay" class="character-form-badge">
                  {{ t("statusPanel.character.form") }}: {{ activeCharacterFormDisplay }}
                </span>
              </div>
              <div class="character-meta">
                {{ formatPair(activeCharacter.race, activeCharacter.gender) }}
              </div>
            </header>

            <div class="character-fields">
              <div class="character-field-row">
                <span class="character-field-label">{{ t("statusPanel.character.energy") }}</span>
                <div
                  class="character-energy character-click-target"
                  role="button"
                  tabindex="0"
                  @click="requestCharacterOverlay('vitality')"
                  @keydown.enter.prevent="requestCharacterOverlay('vitality')"
                  @keydown.space.prevent="requestCharacterOverlay('vitality')"
                >
                  <div class="character-energy-bar" role="progressbar" :aria-valuemin="0" :aria-valuemax="100" :aria-valuenow="activeCharacterVitalityPercent">
                    <div
                      class="character-energy-bar__fill"
                      :class="activeCharacterVitalityStateClass"
                      :style="{ width: `${activeCharacterVitalityFillPercent}%` }"
                    ></div>
                    <span class="character-energy-bar__text">{{ valueOrFallback(activeCharacterEnergyText) }}</span>
                  </div>
                </div>
              </div>
              <div class="character-field-row">
                <span class="character-field-label">{{ t("statusPanel.character.stats") }}</span>
                <table
                  class="character-stats-table character-click-target"
                  role="button"
                  tabindex="0"
                  @click="requestCharacterOverlay('stats')"
                  @keydown.enter.prevent="requestCharacterOverlay('stats')"
                  @keydown.space.prevent="requestCharacterOverlay('stats')"
                >
                  <thead>
                    <tr>
                      <th>strength</th>
                      <th>toughness</th>
                      <th>mana_potency</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td>{{ activeCharacterStats.strength }}</td>
                      <td>{{ activeCharacterStats.toughness }}</td>
                      <td>{{ activeCharacterStats.mana_potency }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div class="character-field-row">
                <span class="character-field-label">{{ t("statusPanel.character.activity") }}</span>
                <span class="character-field-value">{{ valueOrFallback(activeCharacterActivity) }}</span>
              </div>
              <div class="character-field-row">
                <span class="character-field-label">{{ t("statusPanel.character.body_state") }}</span>
                <span class="character-field-value">{{ valueOrFallback(activeCharacterBodyState) }}</span>
              </div>
              <div class="character-field-row">
                <span class="character-field-label">{{ t("statusPanel.character.mind") }}</span>
                <span class="character-field-value">{{ valueOrFallback(activeCharacterMind) }}</span>
              </div>
            </div>
          </article>
        </div>
      </section>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { storeToRefs } from "pinia";

import {
  createEntry,
  getSceneState,
  listCharacters,
  listEntries,
  updateEntry,
  updateSceneState,
} from "@/api/lores";
import { useI18n } from "@/composables/useI18n";
import { parseApiError } from "@/stores/api-error";
import { useSessionStore } from "@/stores/session";
import type { CharacterData, CharacterForm, LoreEntry, SceneState } from "@/types/lore";
import { message } from "@/utils/message";

const CURRENT_TAG_HINTS = [
  "current",
  "now",
  "active",
  "scene",
  "\u5f53\u524d",
  "\u73b0\u5728",
  "\u672c\u573a",
  "\u8fdb\u884c\u4e2d",
];
const PRESENT_TAG_HINTS = [
  "present",
  "onsite",
  "in-scene",
  "\u5728\u573a",
  "\u73b0\u573a",
  "\u5f53\u524d",
  "\u51fa\u573a",
];
const TIME_TAG_KEYS = [
  "time",
  "date",
  "timeline",
  "\u65f6\u95f4",
  "\u65e5\u671f",
  "\u65f6\u523b",
];
const PLACE_TAG_KEYS = [
  "place",
  "location",
  "scene",
  "\u5730\u70b9",
  "\u4f4d\u7f6e",
  "\u573a\u666f",
];
const REQUEST_OPEN_CHARACTER_OVERLAY_EVENT = "rst-request-open-character-overlay";
const LORE_DATA_CHANGED_EVENT = "rst-lore-data-changed";

const sessionStore = useSessionStore();
const { t } = useI18n();
const { currentSession } = storeToRefs(sessionStore);

const collapsed = ref(false);
const loading = ref(false);
const placeEntries = ref<LoreEntry[]>([]);
const plotEntries = ref<LoreEntry[]>([]);
const characters = ref<CharacterData[]>([]);
const sceneState = ref<SceneState | null>(null);
const activeCharacterId = ref<string | null>(null);
const requestToken = ref(0);
const editStoryTime = ref("");
const editStoryLocation = ref("");
const savingStorySnapshot = ref(false);

const currentSessionName = computed(() => currentSession.value?.name ?? null);
const isRstMode = computed(() => currentSession.value?.mode === "RST");
const sessionDisplay = computed(
  () => currentSessionName.value ?? t("statusPanel.value.unselected"),
);

const currentPlaceEntry = computed(() => pickCurrentEntry(placeEntries.value));
const currentPlotEntry = computed(() => pickCurrentEntry(plotEntries.value));

const storyTime = computed(() => {
  const sceneTime = sceneState.value?.current_time.trim() ?? "";
  if (sceneTime) {
    return sceneTime;
  }

  const plot = currentPlotEntry.value;
  if (!plot) {
    return t("statusPanel.value.unknown");
  }
  const fromTags = extractValueByKeys(plot.tags, [
    "time",
    "date",
    "timeline",
    "\u65f6\u95f4",
    "\u65e5\u671f",
    "\u65f6\u523b",
  ]);
  if (fromTags) {
    return fromTags;
  }
  const fromContent = extractValueFromContent(plot.content, [
    "date",
    "time",
    "timeline",
    "\u5f53\u524d\u65f6\u95f4",
    "\u6545\u4e8b\u65f6\u95f4",
    "\u65f6\u95f4",
  ]);
  if (fromContent) {
    return fromContent;
  }
  return valueOrFallback(plot.name);
});

const storyLocation = computed(() => {
  const sceneLocation = sceneState.value?.current_location.trim() ?? "";
  if (sceneLocation) {
    return sceneLocation;
  }

  const plot = currentPlotEntry.value;
  if (plot) {
    const fromTags = extractValueByKeys(plot.tags, [
      "place",
      "location",
      "scene",
      "\u5730\u70b9",
      "\u4f4d\u7f6e",
      "\u573a\u666f",
    ]);
    if (fromTags) {
      return fromTags;
    }
    const fromContent = extractValueFromContent(plot.content, [
      "location",
      "place",
      "scene",
      "\u5f53\u524d\u5730\u70b9",
      "\u6545\u4e8b\u5730\u70b9",
      "\u5730\u70b9",
    ]);
    if (fromContent) {
      return fromContent;
    }
  }
  if (currentPlaceEntry.value?.name) {
    return currentPlaceEntry.value.name;
  }
  return t("statusPanel.value.unknown");
});

const normalizedStoryTime = computed(() => normalizeStoryFieldValue(storyTime.value));
const normalizedStoryLocation = computed(() => normalizeStoryFieldValue(storyLocation.value));
const hasStorySnapshotChange = computed(() => {
  return (
    editStoryTime.value.trim() !== normalizedStoryTime.value ||
    editStoryLocation.value.trim() !== normalizedStoryLocation.value
  );
});

const presentCharacters = computed(() => {
  const enabled = [...characters.value]
    .filter((item) => !item.disabled)
    .sort((left, right) => left.sort_order - right.sort_order);
  if (enabled.length === 0) {
    return [];
  }

  if (isRstMode.value && sceneState.value?.characters.length) {
    const sceneNames = new Set(
      sceneState.value.characters.map((name) => name.trim().toLowerCase()).filter(Boolean),
    );
    const matched = enabled.filter((item) => sceneNames.has(item.name.trim().toLowerCase()));
    if (matched.length > 0) {
      return matched;
    }
  }

  const tagged = enabled.filter((item) => hasAnyTag(item.tags, PRESENT_TAG_HINTS));
  if (tagged.length > 0) {
    return tagged;
  }

  const location = storyLocation.value;
  if (location && location !== t("statusPanel.value.unknown")) {
    const byActivity = enabled.filter((item) =>
      containsText(getActiveForm(item)?.activity ?? "", location),
    );
    if (byActivity.length > 0) {
      return byActivity;
    }
  }

  return enabled;
});

const activeCharacter = computed(
  () =>
    presentCharacters.value.find((item) => item.character_id === activeCharacterId.value) ??
    presentCharacters.value[0] ??
    null,
);

const activeCharacterForm = computed<CharacterForm | null>(() => {
  if (!activeCharacter.value) {
    return null;
  }
  return getActiveForm(activeCharacter.value);
});

const activeCharacterEnergyText = computed(() => {
  const form = activeCharacterForm.value;
  if (!form) {
    return "";
  }
  return `${form.vitality_cur} / ${form.vitality_max}`;
});

const activeCharacterVitalityPercent = computed(() => {
  const form = activeCharacterForm.value;
  if (!form) {
    return 0;
  }
  if (form.vitality_max <= 0) {
    return 0;
  }
  const ratio = form.vitality_cur / form.vitality_max;
  return Math.max(0, Math.min(100, Math.round(ratio * 100)));
});

const activeCharacterVitalityFillPercent = computed(() => {
  const percent = activeCharacterVitalityPercent.value;
  if (percent <= 0) {
    return 0;
  }
  return Math.max(percent, 2);
});

const activeCharacterVitalityStateClass = computed(() => {
  const percent = activeCharacterVitalityPercent.value;
  if (percent < 25) {
    return "is-danger";
  }
  if (percent < 50) {
    return "is-warning";
  }
  return "is-healthy";
});

const activeCharacterStats = computed(() => {
  const form = activeCharacterForm.value;
  if (!form) {
    return {
      strength: "-",
      toughness: "-",
      mana_potency: "-",
    };
  }
  return {
    strength: String(form.strength),
    toughness: String(form.toughness),
    mana_potency: String(form.mana_potency),
  };
});

const activeCharacterBodyState = computed(() => {
  const form = activeCharacterForm.value;
  if (!form) {
    return "";
  }
  return form.body.trim();
});

const activeCharacterActivity = computed(() => activeCharacterForm.value?.activity ?? "");
const activeCharacterMind = computed(() => activeCharacterForm.value?.mind ?? "");
const activeCharacterFormDisplay = computed(() => {
  const character = activeCharacter.value;
  if (!character || character.forms.length <= 1) {
    return "";
  }
  const form = getActiveForm(character);
  if (!form) {
    return "";
  }
  const formName = form.form_name.trim();
  if (formName.length > 0) {
    return formName;
  }
  return form.form_id;
});

watch(
  () => currentSessionName.value,
  (sessionName) => {
    if (!sessionName) {
      placeEntries.value = [];
      plotEntries.value = [];
      characters.value = [];
      sceneState.value = null;
      activeCharacterId.value = null;
      loading.value = false;
      requestToken.value += 1;
      return;
    }
    void loadStatusPanelData(sessionName);
  },
  { immediate: true },
);

watch(
  () => presentCharacters.value.map((item) => item.character_id),
  (characterIds) => {
    if (characterIds.length === 0) {
      activeCharacterId.value = null;
      return;
    }
    if (!activeCharacterId.value || !characterIds.includes(activeCharacterId.value)) {
      activeCharacterId.value = characterIds[0];
    }
  },
  { immediate: true },
);

watch(
  () => [normalizedStoryTime.value, normalizedStoryLocation.value] as const,
  ([timeValue, locationValue]) => {
    if (savingStorySnapshot.value) {
      return;
    }
    editStoryTime.value = timeValue;
    editStoryLocation.value = locationValue;
  },
  { immediate: true },
);

onMounted(() => {
  if (typeof window === "undefined") {
    return;
  }
  collapsed.value = window.innerWidth <= 1024;
  window.addEventListener(LORE_DATA_CHANGED_EVENT, handleExternalRefresh as EventListener);
});

onBeforeUnmount(() => {
  if (typeof window === "undefined") {
    return;
  }
  window.removeEventListener(LORE_DATA_CHANGED_EVENT, handleExternalRefresh as EventListener);
});

async function loadStatusPanelData(sessionName: string): Promise<void> {
  const currentToken = requestToken.value + 1;
  requestToken.value = currentToken;
  loading.value = true;
  try {
    const sceneRequest = isRstMode.value
      ? getSceneState(sessionName).catch(() => null)
      : Promise.resolve(null);
    const [placeResponse, plotResponse, characterResponse, fetchedSceneState] = await Promise.all([
      listEntries(sessionName, "place"),
      listEntries(sessionName, "plot"),
      listCharacters(sessionName),
      sceneRequest,
    ]);
    if (requestToken.value !== currentToken) {
      return;
    }
    placeEntries.value = placeResponse.entries.filter((item) => !item.disabled);
    plotEntries.value = plotResponse.entries.filter((item) => !item.disabled);
    characters.value = characterResponse.characters;
    sceneState.value = fetchedSceneState;
  } catch (error) {
    if (requestToken.value !== currentToken) {
      return;
    }
    sceneState.value = null;
    message.error(parseApiError(error));
  } finally {
    if (requestToken.value === currentToken) {
      loading.value = false;
    }
  }
}

function handleToggle() {
  collapsed.value = !collapsed.value;
}

function refreshData() {
  if (!currentSessionName.value) {
    return;
  }
  void loadStatusPanelData(currentSessionName.value);
}

function handleExternalRefresh(event: Event) {
  const sessionName = currentSessionName.value;
  if (!sessionName) {
    return;
  }
  const customEvent = event as CustomEvent<Record<string, unknown> | undefined>;
  const source = String(customEvent.detail?.source ?? "").trim();
  if (source === "status-panel") {
    return;
  }
  const targetSessionName = String(customEvent.detail?.sessionName ?? "").trim();
  if (targetSessionName && targetSessionName !== sessionName) {
    return;
  }
  void loadStatusPanelData(sessionName);
}

function emitLoreDataChanged(sessionName: string, source: "status-panel" | "rst-lore-panel") {
  if (typeof window === "undefined") {
    return;
  }
  window.dispatchEvent(
    new CustomEvent(LORE_DATA_CHANGED_EVENT, {
      detail: {
        sessionName,
        source,
      },
    }),
  );
}

function requestCharacterOverlay(focus: "vitality" | "stats") {
  if (typeof window === "undefined" || !activeCharacter.value) {
    return;
  }
  window.dispatchEvent(
    new CustomEvent(REQUEST_OPEN_CHARACTER_OVERLAY_EVENT, {
      detail: {
        characterId: activeCharacter.value.character_id,
        preferredFormId: activeCharacterForm.value?.form_id ?? null,
        focus,
      },
    }),
  );
}

async function saveStorySnapshot() {
  if (!currentSessionName.value || savingStorySnapshot.value || !hasStorySnapshotChange.value) {
    return;
  }
  const nextTime = editStoryTime.value.trim();
  const nextLocation = editStoryLocation.value.trim();
  if (!nextTime && !nextLocation) {
    message.warning(t("statusPanel.state.story_required"));
    return;
  }

  savingStorySnapshot.value = true;
  try {
    if (isRstMode.value) {
      await updateSceneState(currentSessionName.value, {
        current_time: nextTime,
        current_location: nextLocation,
      });
    } else if (currentPlotEntry.value) {
      const nextTags = upsertTagGroup(
        upsertTagGroup(currentPlotEntry.value.tags, TIME_TAG_KEYS, "time", nextTime),
        PLACE_TAG_KEYS,
        "place",
        nextLocation,
      );
      await updateEntry(currentSessionName.value, currentPlotEntry.value.id, { tags: nextTags });
    } else {
      await createEntry(currentSessionName.value, {
        name: t("statusPanel.value.default_plot_name"),
        category: "plot",
        content: "",
        tags: buildStoryTags(nextTime, nextLocation),
      });
    }

    await loadStatusPanelData(currentSessionName.value);
    emitLoreDataChanged(currentSessionName.value, "status-panel");
    message.success(t("statusPanel.state.story_saved"));
  } catch (error) {
    message.error(parseApiError(error));
  } finally {
    savingStorySnapshot.value = false;
  }
}

function pickCurrentEntry(entries: LoreEntry[]): LoreEntry | null {
  if (entries.length === 0) {
    return null;
  }
  const tagged = entries.find((entry) => hasAnyTag(entry.tags, CURRENT_TAG_HINTS));
  if (tagged) {
    return tagged;
  }
  return [...entries].sort((left, right) => {
    const leftTime = Date.parse(left.updated_at);
    const rightTime = Date.parse(right.updated_at);
    return rightTime - leftTime;
  })[0];
}

function extractValueByKeys(tags: string[], keys: string[]): string {
  for (const tag of tags) {
    const trimmed = tag.trim();
    if (!trimmed) {
      continue;
    }
    const matched = trimmed.match(/^([^:=]+)\s*[:=]\s*(.+)$/);
    if (!matched) {
      continue;
    }
    const key = matched[1].trim().toLowerCase();
    const value = matched[2].trim();
    if (!value) {
      continue;
    }
    if (keys.some((candidate) => key.includes(candidate.toLowerCase()))) {
      return value;
    }
  }
  return "";
}

function isTagMatchedByKeys(tag: string, keys: string[]): boolean {
  const matched = tag.trim().match(/^([^:=]+)\s*[:=]\s*(.+)$/);
  if (!matched) {
    return false;
  }
  const key = matched[1].trim().toLowerCase();
  return keys.some((candidate) => key.includes(candidate.toLowerCase()));
}

function upsertTagGroup(tags: string[], keys: string[], canonicalKey: string, value: string): string[] {
  const filtered = tags.filter((tag) => !isTagMatchedByKeys(tag, keys));
  if (!value) {
    return filtered;
  }
  return [...filtered, `${canonicalKey}:${value}`];
}

function buildStoryTags(time: string, place: string): string[] {
  const tags: string[] = [];
  if (time) {
    tags.push(`time:${time}`);
  }
  if (place) {
    tags.push(`place:${place}`);
  }
  return tags;
}

function extractValueFromContent(content: string, keys: string[]): string {
  if (!content.trim()) {
    return "";
  }
  const escapedKeys = keys.map((key) => escapeRegExp(key));
  const pattern = new RegExp(`(?:${escapedKeys.join("|")})\\s*[:\\uFF1A]\\s*(.+)$`, "im");
  const matched = content.match(pattern);
  return matched?.[1]?.trim() ?? "";
}

function getActiveForm(character: CharacterData): CharacterForm | null {
  if (character.forms.length === 0) {
    return null;
  }
  const byActiveId = character.forms.find((form) => form.form_id === character.active_form_id);
  if (byActiveId) {
    return byActiveId;
  }
  const byDefault = character.forms.find((form) => form.is_default);
  return byDefault ?? character.forms[0];
}

function hasAnyTag(tags: string[], hints: string[]): boolean {
  return tags.some((tag) => {
    const normalized = tag.trim().toLowerCase();
    if (!normalized) {
      return false;
    }
    return hints.some((hint) => normalized.includes(hint.toLowerCase()));
  });
}

function containsText(source: string, target: string): boolean {
  if (!source.trim() || !target.trim()) {
    return false;
  }
  return source.toLowerCase().includes(target.trim().toLowerCase());
}

function valueOrFallback(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length > 0) {
    return trimmed;
  }
  return t("statusPanel.value.unknown");
}

function normalizeStoryFieldValue(value: string): string {
  const unknown = t("statusPanel.value.unknown");
  return value === unknown ? "" : value.trim();
}

function formatPair(left: string, right: string): string {
  const values = [left.trim(), right.trim()].filter(Boolean);
  if (values.length === 0) {
    return t("statusPanel.value.unknown");
  }
  return values.join(" / ");
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
</script>

<style scoped lang="scss">
.status-panel {
  position: relative;
  height: 100%;
  width: 312px;
  border: 1px solid var(--rst-border-color);
  border-radius: 12px;
  background: var(--rst-bg-panel);
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.25);
  overflow: visible;
  transition: width 0.2s ease;
}

.status-panel.is-collapsed {
  width: 0;
  border-color: transparent;
  background: transparent;
  box-shadow: none;
}

.status-panel__toggle {
  position: absolute;
  left: 0;
  top: 50%;
  width: 30px;
  height: 34px;
  border: 1px solid var(--rst-border-color);
  border-right: 0;
  border-radius: 10px 0 0 10px;
  background: var(--rst-bg-panel);
  color: var(--rst-text-primary);
  opacity: 0.7;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transform: translate(-100%, -50%);
  z-index: 3;
  padding: 0;
  box-shadow: 0 10px 18px rgba(0, 0, 0, 0.28);
  transition:
    opacity 0.2s ease,
    background 0.2s ease,
    transform 0.2s ease;
}

.status-panel__toggle:hover {
  opacity: 1;
  background: var(--rst-accent);
  color: #ffffff;
  transform: translate(-100%, -50%);
}

.status-panel__toggle:active {
  transform: translate(-100%, -50%);
}

.status-panel__toggle-icon {
  width: 15px;
  height: 15px;
}

:global(:root[data-theme="light"]) .status-panel__toggle {
  background: rgba(255, 255, 255, 0.92);
  border-color: rgba(148, 163, 184, 0.72);
  color: #334155;
  opacity: 0.82;
  box-shadow: 0 8px 14px rgba(15, 23, 42, 0.12);
}

:global(:root[data-theme="light"]) .status-panel__toggle:hover {
  background: rgba(219, 234, 254, 0.92);
  color: #1d4ed8;
  opacity: 1;
}

.status-panel__inner {
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
  padding: 8px;
  gap: 8px;
  overflow: hidden;
}

.status-panel__section {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  background: var(--rst-bg-topbar);
}

.status-panel__section--summary {
  padding: 8px;
}

.status-panel__section--characters {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  padding: 8px;
}

.status-panel__section-title {
  font-size: 11px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--rst-text-secondary);
}

.status-panel__section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 6px;
}

.refresh-button {
  border: 1px solid var(--rst-border-color);
  border-radius: 8px;
  background: transparent;
  color: var(--rst-text-secondary);
  padding: 2px 8px;
  font-size: 11px;
  cursor: pointer;
}

.refresh-button:hover:not(:disabled) {
  border-color: var(--rst-accent);
  color: var(--rst-text-primary);
}

.refresh-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.summary-grid {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.summary-row {
  display: flex;
  align-items: baseline;
  gap: 6px;
}

.summary-row--content {
  align-items: center;
}

.summary-label {
  font-size: 11px;
  color: var(--rst-text-secondary);
  white-space: nowrap;
}

.summary-value {
  font-size: 12px;
  color: var(--rst-text-primary);
  word-break: break-word;
  min-width: 0;
}

.summary-editor {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 6px;
}

.summary-editor--stacked {
  flex-direction: column;
  align-items: stretch;
}

.summary-editor__row {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 6px;
}

.summary-input {
  min-width: 0;
  flex: 1;
  height: 24px;
  border-radius: 6px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  color: var(--rst-text-primary);
  padding: 0 8px;
  font-size: 12px;
  line-height: 1;
}

.summary-input:focus {
  outline: none;
  border-color: var(--rst-accent);
}

.summary-save {
  height: 24px;
  border-radius: 6px;
  border: 1px solid var(--rst-border-color);
  background: transparent;
  color: var(--rst-text-secondary);
  padding: 0 8px;
  font-size: 11px;
  white-space: nowrap;
  cursor: pointer;
}

.summary-save:hover:not(:disabled) {
  border-color: var(--rst-accent);
  color: var(--rst-text-primary);
}

.summary-save:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.status-placeholder {
  flex: 1;
  min-height: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  color: var(--rst-text-secondary);
  font-size: 12px;
  padding: 12px;
}

.character-layout {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.character-tabs {
  display: flex;
  gap: 6px;
  flex-wrap: nowrap;
  overflow-x: auto;
  padding-bottom: 2px;
}

.character-tab {
  border: 1px solid var(--rst-border-color);
  border-radius: 999px;
  background: transparent;
  color: var(--rst-text-secondary);
  padding: 2px 10px;
  font-size: 11px;
  white-space: nowrap;
  cursor: pointer;
  transition: all 0.2s ease;
}

.character-tab:hover {
  border-color: var(--rst-accent);
  color: var(--rst-text-primary);
}

.character-tab.is-active {
  border-color: var(--rst-accent);
  background: rgba(37, 99, 235, 0.2);
  color: var(--rst-text-primary);
}

.character-card {
  flex: 1;
  min-height: 0;
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  background: var(--rst-bg-secondary);
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  overflow-y: auto;
}

.character-card__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.character-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--rst-text-primary);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.character-name-row {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 6px;
}

.character-form-badge {
  border: 1px solid var(--rst-border-color);
  border-radius: 999px;
  padding: 1px 7px;
  font-size: 10px;
  color: var(--rst-text-secondary);
  white-space: nowrap;
  flex-shrink: 0;
}

.character-meta {
  font-size: 11px;
  color: var(--rst-text-secondary);
  white-space: nowrap;
  text-align: right;
  flex-shrink: 0;
}

.character-fields {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.character-field-row {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.character-field-label {
  font-size: 11px;
  color: var(--rst-text-secondary);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.character-field-value {
  font-size: 12px;
  color: var(--rst-text-primary);
  word-break: break-word;
}

.character-energy {
  display: flex;
  flex-direction: column;
}

.character-click-target {
  cursor: pointer;
  border-radius: 8px;
  outline: 1px solid transparent;
  transition: background 0.2s ease, outline-color 0.2s ease;
}

.character-click-target:hover {
  background: rgba(37, 99, 235, 0.1);
  outline-color: rgba(37, 99, 235, 0.24);
}

.character-click-target:focus-visible {
  background: rgba(37, 99, 235, 0.14);
  outline-color: var(--rst-accent);
}

.character-energy-bar {
  width: 100%;
  height: 18px;
  border-radius: 999px;
  background: #1f2937;
  border: 1px solid rgba(255, 255, 255, 0.08);
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.45);
  overflow: hidden;
  position: relative;
}

.character-energy-bar__fill {
  height: 100%;
  border-radius: inherit;
  transition: width 0.25s ease, background 0.2s ease, box-shadow 0.2s ease;
  position: relative;
}

.character-energy-bar__fill::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 46%;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.28), rgba(255, 255, 255, 0));
  pointer-events: none;
}

.character-energy-bar__fill.is-healthy {
  background: linear-gradient(90deg, #22c55e 0%, #16a34a 100%);
}

.character-energy-bar__fill.is-warning {
  background: linear-gradient(90deg, #fb923c 0%, #ea580c 100%);
}

.character-energy-bar__fill.is-danger {
  background: linear-gradient(90deg, #dc2626 0%, #7f1d1d 100%);
}

.character-energy-bar__text {
  position: absolute;
  left: 0;
  right: 0;
  top: 50%;
  transform: translateY(-50%);
  text-align: center;
  font-size: 10px;
  line-height: 1;
  font-weight: 600;
  letter-spacing: 0.02em;
  color: #f8fafc;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.65);
  pointer-events: none;
}

.character-stats-table {
  width: 100%;
  border-collapse: collapse;
  border: 1px solid var(--rst-border-color);
  border-radius: 6px;
  overflow: hidden;
}

.character-stats-table th,
.character-stats-table td {
  border: 1px solid var(--rst-border-color);
  padding: 4px 6px;
  text-align: center;
  font-size: 11px;
  line-height: 1.2;
}

.character-stats-table th {
  background: var(--rst-bg-topbar);
  color: var(--rst-text-secondary);
  font-weight: 600;
}

.character-stats-table td {
  background: transparent;
  color: var(--rst-text-primary);
}

@media (max-width: 1200px) {
  .status-panel {
    width: 284px;
  }
}

@media (max-width: 768px) {
  .status-panel {
    width: min(84vw, 284px);
  }
}
</style>
