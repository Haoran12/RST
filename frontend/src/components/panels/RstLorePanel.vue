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
          <div class="tab-content-wrapper">
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
                  &#x29C9;
                </n-button>
              </div>
            </div>
            <div class="entries-scroll-area">
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
                    <div class="drag-handle" @click.stop>&#8942;&#8942;</div>
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
          </div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="characters" :tab="t('rstPanel.tabs.characters')">
          <div class="tab-content-wrapper">
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
                  &#x29C9;
                </n-button>
              </div>
            </div>
            <div class="entries-scroll-area">
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
                    <div class="drag-handle" @click.stop>&#8942;&#8942;</div>
                    <div class="entry-checkbox" @click.stop>
                      <n-checkbox
                        size="small"
                        :checked="selectedCharacterIds.includes(element.character_id)"
                        @update:checked="(checked) => toggleCharacterSelected(element.character_id, checked)"
                      />
                    </div>
                    <div class="entry-main">
                      <span class="entry-name">{{ element.name }}</span>
                      <span class="character-form-meta">{{ characterFormMeta(element) }}</span>
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
          </div>
          </div>
        </n-tab-pane>

        <n-tab-pane name="scheduler" :tab="t('rstPanel.tabs.scheduler')">
          <div class="tab-content-wrapper">
          <div class="scheduler-card">
            <div class="status-grid">
              <div>
                <div class="status-label">{{ t("rstPanel.scheduler.schedule") }}</div>
                <div class="status-value">
                  {{ runtimeStateLabel(Boolean(loreStore.scheduleStatus?.running)) }}
                </div>
                <button class="status-meta status-meta--interactive" type="button" @click="openSchedulerHitsOverlay">
                  <span>
                    {{ t("rstPanel.scheduler.match_count") }}:
                    {{ loreStore.scheduleStatus?.last_matched_count ?? 0 }}
                  </span>
                  <span class="status-meta-hint">{{ t("rstPanel.scheduler.view_hits") }}</span>
                </button>
              </div>
              <div>
                <div class="status-label">{{ t("rstPanel.scheduler.sync") }}</div>
                <div class="status-value">
                  {{ runtimeStateLabel(Boolean(loreStore.syncStatus?.running)) }}
                </div>
                <button class="status-meta status-meta--interactive" type="button" @click="openSyncChangesOverlay">
                  <span>
                    {{ t("rstPanel.scheduler.round") }}:
                    {{ loreStore.syncStatus?.rounds_since_last_sync ?? 0 }} /
                    {{ loreStore.syncStatus?.sync_interval ?? 0 }}
                  </span>
                  <span class="status-meta-hint">{{ t("rstPanel.scheduler.view_sync_changes") }}</span>
                </button>
              </div>
            </div>

            <div class="scheduler-actions-row">
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
              <n-button size="small" type="primary" @click="saveTemplate">
                {{ t("rstPanel.scheduler.save_template") }}
              </n-button>
            </div>

            <div class="scheduler-prompts-panel">
              <div class="scheduler-prompts-header">
                <div class="scheduler-prompts-title">{{ t("rstPanel.scheduler.prompt_templates") }}</div>
                <n-button text size="tiny" @click="toggleAllSchedulerPrompts">
                  {{
                    allSchedulerPromptsCollapsed
                      ? t("rstPanel.scheduler.expand_all")
                      : t("rstPanel.scheduler.collapse_all")
                  }}
                </n-button>
              </div>
              <div class="scheduler-prompts-scroll">
                <section
                  v-for="prompt in schedulerPromptConfigs"
                  :key="prompt.key"
                  class="scheduler-prompt-section"
                >
                  <button
                    type="button"
                    class="scheduler-prompt-toggle"
                    @click="toggleSchedulerPrompt(prompt.key)"
                  >
                    <span class="scheduler-prompt-label">{{ prompt.label }}</span>
                    <span
                      class="scheduler-prompt-arrow"
                      :class="{ collapsed: collapsedSchedulerPrompts[prompt.key] }"
                    >
                      &#x2304;
                    </span>
                  </button>
                  <div v-show="!collapsedSchedulerPrompts[prompt.key]" class="scheduler-prompt-input">
                    <n-input
                      v-model:value="templateForm[prompt.key]"
                      class="scheduler-prompt-editor"
                      type="textarea"
                      :rows="10"
                      :placeholder="prompt.placeholder"
                    />
                    <div class="scheduler-prompt-hint">{{ prompt.hint }}</div>
                  </div>
                </section>
              </div>
            </div>
          </div>
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
    >
      <template #body-prefix>
        <div v-if="showCharacterFormToolbar" class="character-form-toolbar">
          <div class="character-form-toolbar-summary">
            {{
              formatText("rstPanel.overlay.character.form.summary", {
                count: characterFormOptions.length,
                active: activeFormDisplayName,
              })
            }}
          </div>
          <div class="character-form-toolbar-actions">
            <n-select
              v-model:value="selectedCharacterFormId"
              size="small"
              :options="characterFormOptions"
              :placeholder="t('rstPanel.overlay.character.form.select_placeholder')"
            />
            <n-popconfirm
              :show-icon="false"
              :positive-text="t('common.confirm')"
              @positive-click="switchCharacterForm"
            >
              <template #trigger>
                <n-button
                  size="small"
                  secondary
                  :disabled="!canSwitchCharacterForm"
                >
                  {{ t("rstPanel.overlay.character.form.switch") }}
                </n-button>
              </template>
              {{ t("rstPanel.overlay.character.form.switch_confirm") }}
            </n-popconfirm>
            <n-button
              size="small"
              tertiary
              @click="createCharacterForm"
            >
              {{ t("rstPanel.overlay.character.form.add") }}
            </n-button>
            <n-popconfirm
              :show-icon="false"
              :positive-text="t('common.confirm')"
              :positive-button-props="{ type: 'error' }"
              @positive-click="deleteCharacterForm"
            >
              <template #trigger>
                <n-button
                  size="small"
                  tertiary
                  type="error"
                  :disabled="!canDeleteCharacterForm"
                >
                  {{ t("rstPanel.overlay.character.form.delete") }}
                </n-button>
              </template>
              {{ t("rstPanel.overlay.character.form.delete_confirm") }}
            </n-popconfirm>
          </div>
        </div>
      </template>
      <template #body-suffix>
        <div v-if="showCharacterMemoryPanel" class="character-memory-panel">
          <button type="button" class="character-memory-toggle" @click="toggleMemoryPanelCollapsed">
            <span class="character-memory-title">{{ t("rstPanel.overlay.character.memory.title") }}</span>
            <span class="character-memory-toggle-meta">
              <span class="character-memory-count">
                {{
                  formatText("rstPanel.overlay.character.memory.summary", {
                    count: characterMemoryItems.length,
                  })
                }}
              </span>
              <span class="character-memory-arrow" :class="{ collapsed: characterMemoryCollapsed }">
                &#x2304;
              </span>
            </span>
          </button>
          <div v-show="!characterMemoryCollapsed" class="character-memory-body">
            <div v-if="characterMemoryItems.length === 0" class="character-memory-empty">
              {{ t("rstPanel.overlay.character.memory.empty") }}
            </div>
            <div v-else class="character-memory-list">
              <div
                v-for="memory in characterMemoryItems"
                :key="memory.memory_id"
                class="character-memory-item"
              >
                <div class="character-memory-item-header">
                  <div class="character-memory-event">
                    {{ memory.event || memory.memory_id }}
                  </div>
                  <div class="character-memory-item-actions">
                    <n-button
                      size="tiny"
                      secondary
                      :disabled="memoryActionLoading"
                      @click="startMemoryEdit(memory)"
                    >
                      {{ t("rstPanel.overlay.character.memory.edit") }}
                    </n-button>
                    <n-popconfirm
                      :show-icon="false"
                      :positive-text="t('common.confirm')"
                      :positive-button-props="{ type: 'error' }"
                      @positive-click="deleteMemoryEntry(memory.memory_id)"
                    >
                      <template #trigger>
                        <n-button size="tiny" tertiary type="error" :disabled="memoryActionLoading">
                          {{ t("rstPanel.overlay.character.memory.delete") }}
                        </n-button>
                      </template>
                      {{ t("rstPanel.overlay.character.memory.delete_confirm") }}
                    </n-popconfirm>
                  </div>
                </div>
                <template v-if="editingMemoryId === memory.memory_id">
                  <div class="memory-edit-grid">
                    <div class="memory-edit-item memory-edit-item--full">
                      <label class="memory-edit-label">{{ t("rstPanel.overlay.character.memory.field.event") }}</label>
                      <n-input
                        v-model:value="memoryEditDraft.event"
                        type="textarea"
                        size="small"
                        :autosize="{ minRows: 2, maxRows: 6 }"
                        :placeholder="t('rstPanel.overlay.character.memory.placeholder.event')"
                      />
                    </div>
                    <div class="memory-edit-item">
                      <label class="memory-edit-label">{{ t("rstPanel.overlay.character.memory.field.importance") }}</label>
                      <n-input-number
                        v-model:value="memoryEditDraft.importance"
                        size="small"
                        :min="1"
                        :max="10"
                        :step="1"
                      />
                    </div>
                    <div class="memory-edit-item memory-edit-item--full">
                      <label class="memory-edit-label">{{ t("rstPanel.overlay.character.memory.field.tags") }}</label>
                      <n-input
                        v-model:value="memoryEditDraft.tags"
                        size="small"
                        :placeholder="t('rstPanel.overlay.character.memory.placeholder.tags')"
                      />
                    </div>
                    <div class="memory-edit-item memory-edit-item--full">
                      <label class="memory-edit-label">{{ t("rstPanel.overlay.character.memory.field.known_by") }}</label>
                      <n-input
                        v-model:value="memoryEditDraft.known_by"
                        size="small"
                        :placeholder="t('rstPanel.overlay.character.memory.placeholder.known_by')"
                      />
                    </div>
                  </div>
                  <div class="memory-edit-actions">
                    <n-button
                      size="tiny"
                      type="primary"
                      :loading="memoryActionLoading"
                      @click="saveMemoryEdit(memory.memory_id)"
                    >
                      {{ t("rstPanel.overlay.character.memory.save") }}
                    </n-button>
                    <n-button
                      size="tiny"
                      secondary
                      :disabled="memoryActionLoading"
                      @click="cancelMemoryEdit"
                    >
                      {{ t("rstPanel.overlay.character.memory.cancel") }}
                    </n-button>
                  </div>
                </template>
                <template v-else>
                  <div class="character-memory-meta">
                    <span>
                      {{ t("rstPanel.overlay.character.memory.importance") }}: {{ memory.importance }}
                    </span>
                    <span v-if="memory.plot_event_id">
                      {{ t("rstPanel.overlay.character.memory.plot_event") }}: {{ memory.plot_event_id }}
                    </span>
                    <span>
                      {{ t("rstPanel.overlay.character.memory.created_at") }}:
                      {{ formatMemoryCreatedAt(memory.created_at) }}
                    </span>
                    <span v-if="memory.is_consolidated">
                      {{ t("rstPanel.overlay.character.memory.consolidated") }}
                    </span>
                  </div>
                  <div v-if="memory.tags.length > 0" class="character-memory-extra">
                    {{ t("rstPanel.overlay.character.memory.tags") }}: {{ memory.tags.join(", ") }}
                  </div>
                  <div v-if="memory.known_by.length > 0" class="character-memory-extra">
                    {{ t("rstPanel.overlay.character.memory.known_by") }}: {{ memory.known_by.join(", ") }}
                  </div>
                </template>
              </div>
            </div>
          </div>
        </div>
      </template>
    </ContentOverlay>

    <n-modal
      v-model:show="schedulerHitsOverlayVisible"
      preset="card"
      :title="t('rstPanel.scheduler.hit_overlay_title')"
      size="medium"
    >
      <div class="scheduler-hit-overlay-body">
        <div class="scheduler-hit-summary">
          {{
            formatText("rstPanel.scheduler.hit_overlay_summary", {
              count: schedulerHitItems.length,
            })
          }}
        </div>
        <div v-if="schedulerHitLoading" class="scheduler-hit-empty">
          {{ t("rstPanel.scheduler.hit_overlay_loading") }}
        </div>
        <div v-else-if="schedulerHitItems.length === 0" class="scheduler-hit-empty">
          {{ t("rstPanel.scheduler.hit_overlay_empty") }}
        </div>
        <div v-else class="scheduler-hit-list">
          <div v-for="item in schedulerHitItems" :key="item.id" class="scheduler-hit-item">
            <div class="scheduler-hit-item-main">
              <div class="scheduler-hit-name">{{ item.name }}</div>
              <div class="scheduler-hit-id">{{ item.id }}</div>
            </div>
            <n-tag size="small" :bordered="false">{{ item.typeLabel }}</n-tag>
          </div>
        </div>
      </div>
      <template #footer>
        <div class="copy-modal-actions">
          <n-button secondary @click="schedulerHitsOverlayVisible = false">
            {{ t("rstPanel.scheduler.hit_overlay_close") }}
          </n-button>
        </div>
      </template>
    </n-modal>

    <n-modal
      v-model:show="syncChangesOverlayVisible"
      preset="card"
      :title="t('rstPanel.scheduler.sync_overlay_title')"
      size="large"
    >
      <div class="sync-change-overlay-body">
        <div class="sync-change-summary">
          {{
            formatText("rstPanel.scheduler.sync_overlay_summary", {
              created: syncOverlayCreatedCount,
              updated: syncOverlayUpdatedCount,
              memories: syncOverlayMemoryCount,
              events: syncOverlayPlotCount,
              changes: syncOverlayItems.length,
            })
          }}
        </div>
        <div v-if="syncOverlayItems.length === 0" class="sync-change-empty">
          {{ t("rstPanel.scheduler.sync_overlay_empty") }}
        </div>
        <div v-else class="sync-change-list">
          <div v-for="(item, index) in syncOverlayItems" :key="`${item.entry_id}-${item.action}-${index}`" class="sync-change-card">
            <div class="sync-change-header">
              <div class="sync-change-title">{{ item.name || item.entry_id }}</div>
              <n-tag size="small" :bordered="false">{{ syncActionLabel(item.action) }}</n-tag>
            </div>
            <div class="sync-change-meta">
              {{ syncCategoryLabel(item.category) }} &middot; {{ item.entry_id }}
            </div>
            <div v-if="item.summary" class="sync-change-section">
              <div class="sync-change-label">{{ t("rstPanel.scheduler.sync_change.section.summary") }}</div>
              <div class="sync-change-line">{{ item.summary }}</div>
            </div>
            <div v-if="item.field_changes.length > 0" class="sync-change-section">
              <div class="sync-change-label">{{ t("rstPanel.scheduler.sync_change.section.fields") }}</div>
              <div
                v-for="(fieldItem, fieldIndex) in item.field_changes"
                :key="`${item.entry_id}-${fieldItem.field}-${fieldIndex}`"
                class="sync-change-line"
              >
                {{ fieldItem.field }}: {{ fieldItem.before || "(empty)" }} -> {{ fieldItem.after || "(empty)" }}
              </div>
            </div>
            <div v-if="item.memory_event" class="sync-change-section">
              <div class="sync-change-label">{{ t("rstPanel.scheduler.sync_change.section.memory_event") }}</div>
              <div class="sync-change-line">{{ item.memory_event }}</div>
            </div>
            <div v-if="item.content_append" class="sync-change-section">
              <div class="sync-change-label">{{ t("rstPanel.scheduler.sync_change.section.appended") }}</div>
              <div class="sync-change-block">{{ item.content_append }}</div>
            </div>
            <div v-if="item.before_content || item.after_content" class="sync-change-section">
              <div class="sync-change-label">{{ t("rstPanel.scheduler.sync_change.section.content") }}</div>
              <div v-if="item.before_content" class="sync-change-line">
                {{ t("rstPanel.scheduler.sync_change.before") }}: {{ item.before_content }}
              </div>
              <div v-if="item.after_content" class="sync-change-line">
                {{ t("rstPanel.scheduler.sync_change.after") }}: {{ item.after_content }}
              </div>
            </div>
            <div v-if="item.tags_added.length > 0" class="sync-change-section">
              <div class="sync-change-label">{{ t("rstPanel.scheduler.sync_change.section.tags") }}</div>
              <div class="sync-change-line">{{ item.tags_added.join(", ") }}</div>
            </div>
          </div>
        </div>
      </div>
      <template #footer>
        <div class="copy-modal-actions">
          <n-button secondary @click="syncChangesOverlayVisible = false">
            {{ t("rstPanel.scheduler.sync_overlay_close") }}
          </n-button>
        </div>
      </template>
    </n-modal>

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
        <n-checkbox v-model:checked="importLlmFallback">
          {{ t("rstPanel.import.llm_fallback") }}
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
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
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

import {
  addForm,
  addMemory,
  createCharacter,
  createEntry,
  deleteCharacter,
  deleteMemory,
  getEntry,
  listCharacters,
  listEntries,
  setActiveForm,
  updateMemory,
  updateForm,
} from "@/api/lores";
import ContentOverlay from "@/components/panels/ContentOverlay.vue";
import { useI18n } from "@/composables/useI18n";
import { parseApiError } from "@/stores/api-error";
import { useLoreStore } from "@/stores/lore";
import { useSessionStore } from "@/stores/session";
import { message } from "@/utils/message";
import { formatTimestampLocal, timestampToEpochMs } from "@/utils/time";

import type {
  CharacterData,
  CharacterForm,
  CharacterMemory,
  ConversionReport,
  LoreCategory,
  LoreEntry,
  Relationship,
  SyncChange,
} from "@/types/lore";

interface OverlayField {
  key: string;
  label: string;
  type: "text" | "textarea" | "number" | "select" | "toggle";
  value: unknown;
  readonly?: boolean;
  options?: Array<{ label: string; value: string | number }>;
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

interface LoreTotals {
  entries: number;
  characters: number;
}

type SchedulerPromptKey = "confirm_prompt" | "extract_prompt" | "consolidate_prompt";

interface SchedulerHitItem {
  id: string;
  name: string;
  typeLabel: string;
}

interface SyncOverlayItem {
  entry_id: string;
  name: string;
  category: string;
  action: string;
  summary: string;
  before_content: string | null;
  after_content: string | null;
  content_append: string | null;
  tags_added: string[];
  field_changes: Array<{ field: string; before: string; after: string }>;
  memory_event: string | null;
}

interface OpenCharacterOverlayRequest {
  characterId: string;
  preferredFormId?: string | null;
}

interface MemoryEditDraft {
  event: string;
  importance: number | null;
  tags: string;
  known_by: string;
}

const OPEN_CHARACTER_OVERLAY_EVENT = "rst-open-character-overlay";
const LORE_DATA_CHANGED_EVENT = "rst-lore-data-changed";

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
const genderOptions = [
  { label: "male", value: "male" },
  { label: "female", value: "female" },
  { label: "hermaphrodite", value: "hermaphrodite" },
  { label: "asexual", value: "asexual" },
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
const characterOverlaySections = ref<OverlaySection[]>([]);
const characterOverlayContent = ref("");
const selectedCharacterFormId = ref<string | null>(null);
const characterRows = ref<CharacterData[]>([]);
const selectedCharacterIds = ref<string[]>([]);
const characterCopyModalVisible = ref(false);
const characterCopyTarget = ref<string | null>(null);
const characterMemoryCollapsed = ref(true);
const editingMemoryId = ref<string | null>(null);
const memoryActionLoading = ref(false);
const memoryEditDraft = reactive<MemoryEditDraft>({
  event: "",
  importance: 5,
  tags: "",
  known_by: "",
});
const skillEntryOptions = ref<Array<{ label: string; value: string }>>([]);
const skillEntryNameCache = ref<Record<string, string>>({});
const skillEntryOptionsLoadSeq = ref(0);
const pendingCharacterOverlayRequest = ref<OpenCharacterOverlayRequest | null>(null);

function setSkillEntryOptions(options: Array<{ label: string; value: string }>): void {
  // Keep the same array reference so already-open overlays receive async option updates.
  options.forEach((option) => {
    const optionValue = String(option.value ?? "").trim();
    if (!optionValue) {
      return;
    }
    const optionLabel = String(option.label ?? "").trim();
    if (!optionLabel) {
      return;
    }
    skillEntryNameCache.value[optionValue] = optionLabel;
  });
  skillEntryOptions.value.splice(0, skillEntryOptions.value.length, ...options);
}

function resetSkillEntryCache(): void {
  skillEntryOptionsLoadSeq.value += 1;
  Object.keys(skillEntryNameCache.value).forEach((entryId) => {
    delete skillEntryNameCache.value[entryId];
  });
}

const templateForm = reactive({
  confirm_prompt: "",
  extract_prompt: "",
  consolidate_prompt: "",
});
const collapsedSchedulerPrompts = reactive<Record<SchedulerPromptKey, boolean>>({
  confirm_prompt: false,
  extract_prompt: false,
  consolidate_prompt: false,
});
const schedulerHitsOverlayVisible = ref(false);
const schedulerHitLoading = ref(false);
const schedulerHitItems = ref<SchedulerHitItem[]>([]);
const syncChangesOverlayVisible = ref(false);

const importInputRef = ref<HTMLInputElement | null>(null);
const importModalVisible = ref(false);
const importingFile = ref<File | null>(null);
const splitFactionCharacters = ref(false);
const importLlmFallback = ref(true);
const reportOverlayVisible = ref(false);
const importReport = ref<ConversionReport | null>(null);
const importRecoveryToken = ref(0);

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
const editingCharacter = computed(() =>
  editingCharacterId.value
    ? loreStore.characters.find((item) => item.character_id === editingCharacterId.value) ?? null
    : null,
);
const characterFormOptions = computed<Array<{ label: string; value: string }>>(() => {
  const forms = editingCharacter.value?.forms ?? [];
  return forms.map((form) => ({
    label: form.is_default
      ? `${form.form_name} (${t("rstPanel.overlay.character.form.default_suffix")})`
      : form.form_name,
    value: form.form_id,
  }));
});
const activeFormDisplayName = computed(() => {
  const character = editingCharacter.value;
  if (!character) {
    return t("rstPanel.overlay.character.form.none");
  }
  const activeForm = resolveCharacterActiveForm(character);
  return activeForm?.form_name || t("rstPanel.overlay.character.form.none");
});
const showCharacterFormToolbar = computed(
  () => Boolean(editingCharacter.value && characterFormOptions.value.length > 0),
);
const showCharacterMemoryPanel = computed(() => Boolean(editingCharacter.value));
const characterMemoryItems = computed<CharacterMemory[]>(() => {
  const character = editingCharacter.value;
  if (!character) {
    return [];
  }
  return [...character.memories].sort((left, right) => {
    const leftTs = timestampToEpochMs(left.created_at);
    const rightTs = timestampToEpochMs(right.created_at);
    if (Number.isNaN(leftTs) || Number.isNaN(rightTs)) {
      return 0;
    }
    return rightTs - leftTs;
  });
});
const canSwitchCharacterForm = computed(() => {
  const character = editingCharacter.value;
  if (!character || !selectedCharacterFormId.value) {
    return false;
  }
  return selectedCharacterFormId.value !== character.active_form_id;
});
const canDeleteCharacterForm = computed(() => {
  const character = editingCharacter.value;
  return Boolean(character && character.forms.length > 1 && selectedCharacterFormId.value);
});
const characterCopyConfirmDisabled = computed(
  () => !hasCharacterSelection.value || !characterCopyTarget.value || targetSessionOptions.value.length === 0,
);
const schedulerPromptConfigs = computed<
  Array<{ key: SchedulerPromptKey; label: string; placeholder: string; hint: string }>
>(() => [
  {
    key: "confirm_prompt",
    label: t("rstPanel.scheduler.prompt.confirm"),
    placeholder: t("rstPanel.scheduler.placeholder.confirm_prompt"),
    hint: t("rstPanel.scheduler.hint.confirm_prompt"),
  },
  {
    key: "extract_prompt",
    label: t("rstPanel.scheduler.prompt.extract"),
    placeholder: t("rstPanel.scheduler.placeholder.extract_prompt"),
    hint: t("rstPanel.scheduler.hint.extract_prompt"),
  },
  {
    key: "consolidate_prompt",
    label: t("rstPanel.scheduler.prompt.consolidate"),
    placeholder: t("rstPanel.scheduler.placeholder.consolidate_prompt"),
    hint: t("rstPanel.scheduler.hint.consolidate_prompt"),
  },
]);
const allSchedulerPromptsCollapsed = computed(() =>
  schedulerPromptConfigs.value.every((prompt) => collapsedSchedulerPrompts[prompt.key]),
);
const schedulerMatchedIds = computed(() => {
  const matched = loreStore.scheduleStatus?.last_matched_entry_ids ?? [];
  if (matched.length > 0) {
    return matched;
  }
  return loreStore.scheduleStatus?.cached_candidates ?? [];
});
const syncLastResult = computed(() => loreStore.syncStatus?.last_result ?? null);
const syncOverlayCreatedCount = computed(() => syncLastResult.value?.created_entries.length ?? 0);
const syncOverlayUpdatedCount = computed(() => syncLastResult.value?.updated_entries.length ?? 0);
const syncOverlayMemoryCount = computed(() => syncLastResult.value?.new_memories ?? 0);
const syncOverlayPlotCount = computed(() => syncLastResult.value?.new_plot_events ?? 0);
const syncOverlayItems = computed<SyncOverlayItem[]>(() => {
  const result = syncLastResult.value;
  if (!result) {
    return [];
  }
  const syncChanges: SyncChange[] = result.changes;
  if (syncChanges.length > 0) {
    return syncChanges.map((change) => ({
      ...change,
      summary: change.summary || "",
      before_content: change.before_content,
      after_content: change.after_content,
      content_append: change.content_append,
      tags_added: [...change.tags_added],
      field_changes: change.field_changes.map((item) => ({ ...item })),
      memory_event: change.memory_event,
    }));
  }
  const fallbackItems: SyncOverlayItem[] = [];
  result.created_entries.forEach((entryId) => {
    fallbackItems.push({
      entry_id: entryId,
      name: entryId,
      category: "unknown",
      action: "created",
      summary: "",
      before_content: null,
      after_content: null,
      content_append: null,
      tags_added: [],
      field_changes: [],
      memory_event: null,
    });
  });
  result.updated_entries.forEach((entryId) => {
    fallbackItems.push({
      entry_id: entryId,
      name: entryId,
      category: "unknown",
      action: "updated",
      summary: "",
      before_content: null,
      after_content: null,
      content_append: null,
      tags_added: [],
      field_changes: [],
      memory_event: null,
    });
  });
  return fallbackItems;
});

function parseOpenCharacterOverlayRequest(event: Event): OpenCharacterOverlayRequest | null {
  const customEvent = event as CustomEvent<Record<string, unknown> | undefined>;
  const characterId = String(customEvent.detail?.characterId ?? "").trim();
  if (!characterId) {
    return null;
  }
  const preferredFormRaw = customEvent.detail?.preferredFormId;
  const preferredFormId =
    typeof preferredFormRaw === "string" && preferredFormRaw.trim().length > 0
      ? preferredFormRaw.trim()
      : null;
  return {
    characterId,
    preferredFormId,
  };
}

function tryOpenCharacterOverlayFromRequest(request: OpenCharacterOverlayRequest): boolean {
  const exists = loreStore.characters.some(
    (character) => character.character_id === request.characterId,
  );
  if (!exists) {
    return false;
  }
  activeTab.value = "characters";
  void openCharacterOverlay(request.characterId, request.preferredFormId ?? undefined);
  return true;
}

function handleOpenCharacterOverlayEvent(event: Event) {
  const request = parseOpenCharacterOverlayRequest(event);
  if (!request) {
    return;
  }
  if (tryOpenCharacterOverlayFromRequest(request)) {
    pendingCharacterOverlayRequest.value = null;
    return;
  }
  pendingCharacterOverlayRequest.value = request;
}

function handleExternalLoreDataChanged(event: Event) {
  if (!currentSession.value?.name) {
    return;
  }
  const customEvent = event as CustomEvent<Record<string, unknown> | undefined>;
  const source = String(customEvent.detail?.source ?? "").trim();
  if (source === "rst-lore-panel") {
    return;
  }
  const targetSessionName = String(customEvent.detail?.sessionName ?? "").trim();
  if (targetSessionName && targetSessionName !== currentSession.value.name) {
    return;
  }
  void refreshLorePanelData(currentSession.value.name);
}

onMounted(async () => {
  if (typeof window !== "undefined") {
    window.addEventListener(OPEN_CHARACTER_OVERLAY_EVENT, handleOpenCharacterOverlayEvent as EventListener);
    window.addEventListener(LORE_DATA_CHANGED_EVENT, handleExternalLoreDataChanged as EventListener);
  }
  if (sessions.value.length === 0) {
    await sessionStore.loadSessions();
  }
  await bootstrapCurrentSession();
});

onBeforeUnmount(() => {
  if (typeof window === "undefined") {
    return;
  }
  window.removeEventListener(
    OPEN_CHARACTER_OVERLAY_EVENT,
    handleOpenCharacterOverlayEvent as EventListener,
  );
  window.removeEventListener(LORE_DATA_CHANGED_EVENT, handleExternalLoreDataChanged as EventListener);
});

watch(
  () => currentSession.value?.name,
  async () => {
    importRecoveryToken.value += 1;
    pendingCharacterOverlayRequest.value = null;
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
    if (
      pendingCharacterOverlayRequest.value &&
      tryOpenCharacterOverlayFromRequest(pendingCharacterOverlayRequest.value)
    ) {
      pendingCharacterOverlayRequest.value = null;
    }
  },
  { immediate: true, deep: true },
);

watch(
  () => editingCharacter.value,
  (character) => {
    if (!character) {
      selectedCharacterFormId.value = null;
      return;
    }
    const exists = selectedCharacterFormId.value
      ? character.forms.some((form) => form.form_id === selectedCharacterFormId.value)
      : false;
    if (!exists) {
      selectedCharacterFormId.value = resolveCharacterActiveForm(character)?.form_id ?? null;
    }
  },
  { deep: true },
);

watch(
  () => selectedCharacterFormId.value,
  (formId, previousFormId) => {
    if (formId === previousFormId || !characterOverlayVisible.value || !editingCharacter.value) {
      return;
    }
    const selectedForm = resolveCharacterOverlayForm(editingCharacter.value, formId);
    applyCharacterOverlayForForm(editingCharacter.value, selectedForm);
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
  schedulerHitsOverlayVisible.value = false;
  schedulerHitLoading.value = false;
  schedulerHitItems.value = [];
  syncChangesOverlayVisible.value = false;
  if (!currentSession.value?.name) {
    resetSkillEntryCache();
    resetEntryListState();
    entryRows.value = [];
    entryFilter.value = entryCategory.value;
    resetCharacterListState();
    characterRows.value = [];
    setSkillEntryOptions([]);
    return;
  }
  resetSkillEntryCache();
  setSkillEntryOptions([]);
  // Reset stale UI state first. Do not reset after async loading, otherwise
  // a newly opened character overlay can be immediately closed by this reset.
  entryFilter.value = entryCategory.value;
  resetEntryListState();
  resetCharacterListState();
  await Promise.all([
    loreStore.loadEntries(currentSession.value.name, entryCategory.value),
    loreStore.loadCharacters(currentSession.value.name),
    loreStore.refreshSchedulerState(currentSession.value.name),
    loadSkillEntryOptions(currentSession.value.name),
  ]);
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
    .split(/[\n,\uFF0C]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseIdList(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value
      .map((item) => String(item).trim())
      .filter(Boolean);
  }
  return parseDelimitedText(String(value ?? ""));
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
      const separator = row.includes("\uFF1A") ? "\uFF1A" : ":";
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
  return parseNonNegativeInt(value, 100);
}

function normalizeSkillEntryName(entryName: string): string {
  return entryName.trim() || t("rstPanel.report.unnamed_entry");
}

function buildSkillFieldOptions(selectedIds: string[]): Array<{ label: string; value: string }> {
  const merged = skillEntryOptions.value.map((option) => ({ ...option }));
  const existingIds = new Set(merged.map((option) => option.value));
  selectedIds.forEach((rawId) => {
    const id = String(rawId ?? "").trim();
    if (!id || existingIds.has(id)) {
      return;
    }
    merged.push({
      label: skillEntryNameCache.value[id] ?? t("rstPanel.scheduler.hit_type.unknown"),
      value: id,
    });
    existingIds.add(id);
  });
  return merged;
}

async function hydrateSkillEntryNamesForIds(sessionName: string, ids: string[]): Promise<void> {
  const missingIds = Array.from(
    new Set(
      ids
        .map((id) => String(id ?? "").trim())
        .filter((id) => id.length > 0 && !skillEntryNameCache.value[id]),
    ),
  );
  if (missingIds.length === 0) {
    return;
  }
  await Promise.all(
    missingIds.map(async (entryId) => {
      try {
        const entry = await getEntry(sessionName, entryId);
        if (!("id" in entry) || !("category" in entry) || entry.category !== "skills") {
          return;
        }
        skillEntryNameCache.value[entry.id] = normalizeSkillEntryName(entry.name);
      } catch {
        // Best-effort lookup only.
      }
    }),
  );
}

function collectSkillIds(form: CharacterForm | null): string[] {
  if (!form) {
    return [];
  }
  return [
    ...form.weak,
    ...form.resist,
    ...form.element,
    ...form.skills,
    ...form.penetration,
  ]
    .map((id) => String(id ?? "").trim())
    .filter(Boolean);
}

function toSkillEntryOptions(entries: LoreEntry[]): Array<{ label: string; value: string }> {
  return entries.map((entry) => {
    const name = normalizeSkillEntryName(entry.name);
    skillEntryNameCache.value[entry.id] = name;
    return {
      label: name,
      value: entry.id,
    };
  });
}

async function loadSkillEntryOptions(sessionName: string): Promise<void> {
  const requestSeq = ++skillEntryOptionsLoadSeq.value;
  try {
    const response = await listEntries(sessionName, "skills");
    if (requestSeq !== skillEntryOptionsLoadSeq.value) {
      return;
    }
    if (currentSession.value?.name !== sessionName) {
      return;
    }
    setSkillEntryOptions(toSkillEntryOptions(response.entries));
  } catch {
    if (requestSeq !== skillEntryOptionsLoadSeq.value) {
      return;
    }
    if (currentSession.value?.name !== sessionName) {
      return;
    }
    // Keep existing options cache to avoid fallback to raw ids on transient request failures.
  }
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
  if (entryCategory.value === "skills" || result.category === "skills") {
    await loadSkillEntryOptions(currentSession.value.name);
  }
  activeEntryId.value = result.category === entryCategory.value ? result.id : null;
  notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
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
  const updated = await loreStore.updateEntry(currentSession.value.name, target.id, {
    disabled: !enabled,
  });
  if (updated) {
    notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
  }
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
  const sessionName = currentSession.value.name;
  const ids = [...selectedEntryIds.value];
  for (const id of ids) {
    await loreStore.deleteEntry(sessionName, id);
  }
  if (entryCategory.value === "skills") {
    await loadSkillEntryOptions(sessionName);
  }
  selectedEntryIds.value = [];
  if (activeEntryId.value && ids.includes(activeEntryId.value)) {
    activeEntryId.value = null;
  }
  if (editingEntryId.value && ids.includes(editingEntryId.value)) {
    closeEntryOverlay();
  }
  if (ids.length > 0) {
    notifyLoreDataChanged(sessionName, "rst-lore-panel");
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
  const targetSessionName = copyTargetSession.value;
  const touchedSessions = new Set<string>();
  let copiedCount = 0;
  for (const entry of selectedEntries.value) {
    if (entry.category === "character" || entry.category === "memory") {
      continue;
    }
    try {
      await createEntry(targetSessionName, {
        name: entry.name,
        category: entry.category,
        content: entry.content,
        tags: [...entry.tags],
        disabled: entry.disabled,
        constant: entry.constant,
      });
      copiedCount += 1;
      touchedSessions.add(targetSessionName);
    } catch (error) {
      message.error(parseApiError(error));
    }
  }
  touchedSessions.forEach((sessionName) => {
    notifyLoreDataChanged(sessionName, "rst-lore-panel");
  });
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
  const sessionName = currentSession.value.name;
  const reordered = await loreStore.reorderEntries(sessionName, {
    category: entryCategory.value,
    entry_ids: entryRows.value.map((entry) => entry.id),
  });
  if (!reordered) {
    entryRows.value = loreStore.entries.map((entry) => ({ ...entry, tags: [...entry.tags] }));
    return;
  }
  notifyLoreDataChanged(sessionName, "rst-lore-panel");
}

function resetCharacterOverlay() {
  activeCharacterId.value = null;
  editingCharacterId.value = null;
  characterOverlayVisible.value = false;
  characterOverlayTitle.value = "";
  characterOverlayFields.value = [];
  characterOverlaySections.value = [];
  characterOverlayContent.value = "";
  selectedCharacterFormId.value = null;
  characterMemoryCollapsed.value = true;
  cancelMemoryEdit();
}

function resetCharacterListState() {
  selectedCharacterIds.value = [];
  closeCharacterCopyModal();
  resetCharacterOverlay();
}

function characterModeLabel(character: CharacterData): string {
  return character.constant ? t("rstPanel.mode.const_short") : t("rstPanel.mode.rst_short");
}

function characterFormMeta(character: CharacterData): string {
  const activeForm = resolveCharacterActiveForm(character);
  return formatText("rstPanel.characters.form_meta", {
    active: activeForm?.form_name || t("rstPanel.overlay.character.form.none"),
    count: character.forms.length,
  });
}

function formatMemoryCreatedAt(raw: string): string {
  return formatTimestampLocal(raw, "-");
}

function toggleMemoryPanelCollapsed() {
  characterMemoryCollapsed.value = !characterMemoryCollapsed.value;
}

function resetMemoryEditDraft() {
  memoryEditDraft.event = "";
  memoryEditDraft.importance = 5;
  memoryEditDraft.tags = "";
  memoryEditDraft.known_by = "";
}

function startMemoryEdit(memory: CharacterMemory) {
  editingMemoryId.value = memory.memory_id;
  memoryEditDraft.event = memory.event;
  memoryEditDraft.importance = memory.importance;
  memoryEditDraft.tags = memory.tags.join(", ");
  memoryEditDraft.known_by = memory.known_by.join(", ");
  characterMemoryCollapsed.value = false;
}

function cancelMemoryEdit() {
  editingMemoryId.value = null;
  resetMemoryEditDraft();
}

function normalizeMemoryImportance(value: number | null): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 5;
  }
  const rounded = Math.round(value);
  if (rounded < 1) {
    return 1;
  }
  if (rounded > 10) {
    return 10;
  }
  return rounded;
}

async function saveMemoryEdit(memoryId: string) {
  if (!currentSession.value?.name || !editingCharacterId.value) {
    return;
  }
  const eventText = memoryEditDraft.event.trim();
  if (!eventText) {
    message.error(t("rstPanel.overlay.character.memory.validation.event_required"));
    return;
  }

  memoryActionLoading.value = true;
  try {
    await updateMemory(currentSession.value.name, editingCharacterId.value, memoryId, {
      event: eventText,
      importance: normalizeMemoryImportance(memoryEditDraft.importance),
      tags: parseDelimitedText(memoryEditDraft.tags),
      known_by: parseDelimitedText(memoryEditDraft.known_by),
    });
    await loreStore.loadCharacters(currentSession.value.name);
    notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
    cancelMemoryEdit();
    message.success(t("rstPanel.overlay.character.memory.updated"));
  } catch (error) {
    message.error(parseApiError(error));
  } finally {
    memoryActionLoading.value = false;
  }
}

async function deleteMemoryEntry(memoryId: string) {
  if (!currentSession.value?.name || !editingCharacterId.value) {
    return;
  }
  memoryActionLoading.value = true;
  try {
    await deleteMemory(currentSession.value.name, editingCharacterId.value, memoryId);
    await loreStore.loadCharacters(currentSession.value.name);
    notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
    if (editingMemoryId.value === memoryId) {
      cancelMemoryEdit();
    }
    message.success(t("rstPanel.overlay.character.memory.deleted"));
  } catch (error) {
    message.error(parseApiError(error));
  } finally {
    memoryActionLoading.value = false;
  }
}

interface CharacterOverlayValues {
  name: string;
  race: string;
  gender: string;
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
  const weakOptions = buildSkillFieldOptions(character.weak);
  const resistOptions = buildSkillFieldOptions(character.resist);
  const elementOptions = buildSkillFieldOptions(character.element);
  const skillsOptions = buildSkillFieldOptions(character.skills);
  const penetrationOptions = buildSkillFieldOptions(character.penetration);
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
      key: "gender",
      label: t("rstPanel.overlay.character.field.gender"),
      type: "select",
      value: character.gender,
      options: genderOptions,
      placeholder: t("rstPanel.overlay.character.placeholder.gender"),
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
      type: "select",
      value: [...character.weak],
      options: weakOptions,
      multiple: true,
      placeholder: t("rstPanel.overlay.character.placeholder.weak"),
      wide: true,
    },
    {
      key: "resist",
      label: t("rstPanel.overlay.character.field.resist"),
      type: "select",
      value: [...character.resist],
      options: resistOptions,
      multiple: true,
      placeholder: t("rstPanel.overlay.character.placeholder.resist"),
      wide: true,
    },
    {
      key: "element",
      label: t("rstPanel.overlay.character.field.element"),
      type: "select",
      value: [...character.element],
      options: elementOptions,
      multiple: true,
      placeholder: t("rstPanel.overlay.character.placeholder.element"),
      wide: true,
      description: t("rstPanel.overlay.character.description.element"),
    },
    {
      key: "skills",
      label: t("rstPanel.overlay.character.field.skills"),
      type: "select",
      value: [...character.skills],
      options: skillsOptions,
      multiple: true,
      placeholder: t("rstPanel.overlay.character.placeholder.skills"),
      wide: true,
      description: t("rstPanel.overlay.character.description.skills"),
    },
    {
      key: "penetration",
      label: t("rstPanel.overlay.character.field.penetration"),
      type: "select",
      value: [...character.penetration],
      options: penetrationOptions,
      multiple: true,
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
        fieldByKey.get("gender")!,
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

function resolveCharacterOverlayForm(
  character: CharacterData,
  preferredFormId?: string | null,
): CharacterForm | null {
  if (preferredFormId) {
    const matched = character.forms.find((form) => form.form_id === preferredFormId);
    if (matched) {
      return matched;
    }
  }
  return resolveCharacterActiveForm(character);
}

function applyCharacterOverlayForForm(character: CharacterData, form: CharacterForm | null) {
  const config = buildCharacterOverlayConfig({
    name: character.name,
    race: character.race,
    gender: character.gender ?? "",
    strength: form?.strength ?? 100,
    form_name: form?.form_name ?? t("rstPanel.overlay.character.form.none"),
    is_default: form?.is_default ?? true,
    physique: form?.physique ?? "",
    features: form?.features ?? "",
    vitality_max: form?.vitality_max ?? 100,
    mana_potency: form?.mana_potency ?? 100,
    toughness: form?.toughness ?? 100,
    weak: [...(form?.weak ?? [])],
    resist: [...(form?.resist ?? [])],
    element: [...(form?.element ?? [])],
    skills: [...(form?.skills ?? [])],
    penetration: [...(form?.penetration ?? [])],
    clothing: form?.clothing ?? "",
    body: form?.body ?? "",
    mind: form?.mind ?? "",
    vitality_cur: form?.vitality_cur ?? 50,
    activity: form?.activity ?? "",
    birth: character.birth,
    homeland: character.homeland,
    aliases: character.aliases,
    role: character.role,
    faction: character.faction,
    objective: character.objective,
    relationship: character.relationship,
    tags: character.tags,
    constant: character.constant,
    disabled: character.disabled,
  });
  characterOverlayFields.value = config.fields;
  characterOverlaySections.value = config.sections;
  characterOverlayContent.value = character.personality;
}

function openNewCharacterOverlay() {
  editingCharacterId.value = null;
  activeCharacterId.value = null;
  selectedCharacterFormId.value = null;
  characterMemoryCollapsed.value = true;
  cancelMemoryEdit();
  characterOverlayTitle.value = t("rstPanel.overlay.character.create_title");
  const config = buildCharacterOverlayConfig({
    name: "",
    race: "",
    gender: "",
    strength: 100,
    form_name: t("rstPanel.overlay.character.form.default_suffix"),
    is_default: true,
    physique: "",
    features: "",
    vitality_max: 100,
    mana_potency: 100,
    toughness: 100,
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

async function openCharacterOverlay(characterId: string, preferredFormId?: string) {
  const initialTarget = loreStore.characters.find((item) => item.character_id === characterId);
  if (!initialTarget) {
    return;
  }
  const sessionName = currentSession.value?.name;
  const initialForm = resolveCharacterOverlayForm(initialTarget, preferredFormId);
  if (sessionName) {
    await hydrateSkillEntryNamesForIds(sessionName, collectSkillIds(initialForm));
    if (currentSession.value?.name !== sessionName) {
      return;
    }
  }
  const target = loreStore.characters.find((item) => item.character_id === characterId);
  if (!target) {
    return;
  }
  cancelMemoryEdit();
  activeCharacterId.value = target.character_id;
  editingCharacterId.value = target.character_id;
  characterOverlayTitle.value = formatText("rstPanel.overlay.character.edit_title", {
    name: target.name,
  });
  const selectedForm = resolveCharacterOverlayForm(target, preferredFormId);
  selectedCharacterFormId.value = selectedForm?.form_id ?? null;
  applyCharacterOverlayForForm(target, selectedForm);
  characterOverlayVisible.value = true;
}

function closeCharacterOverlay() {
  characterOverlayVisible.value = false;
  editingCharacterId.value = null;
  characterOverlayTitle.value = "";
  characterOverlayFields.value = [];
  characterOverlaySections.value = [];
  characterOverlayContent.value = "";
  selectedCharacterFormId.value = null;
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
    gender: String(data.fields.gender ?? "").trim(),
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
    strength: parseStrength(data.fields.strength),
    mana_potency: parseNonNegativeInt(data.fields.mana_potency, 100),
    toughness: parseNonNegativeInt(data.fields.toughness, 100),
    weak: parseIdList(data.fields.weak),
    resist: parseIdList(data.fields.resist),
    element: parseIdList(data.fields.element),
    skills: parseIdList(data.fields.skills),
    penetration: parseIdList(data.fields.penetration),
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
  const targetFormId =
    selectedCharacterFormId.value &&
    result.forms.some((form) => form.form_id === selectedCharacterFormId.value)
      ? selectedCharacterFormId.value
      : resolveCharacterActiveForm(result)?.form_id;
  if (targetFormId) {
    await loreStore.updateCharacterForm(
      currentSession.value.name,
      result.character_id,
      targetFormId,
      formPayload,
    );
  }
  activeCharacterId.value = result.character_id;
  notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
  closeCharacterOverlay();
}

function notifyLoreDataChanged(
  sessionName: string,
  source: "status-panel" | "rst-lore-panel",
) {
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

function buildNewFormName(character: CharacterData): string {
  const prefix = t("rstPanel.overlay.character.form.name_prefix");
  const existingNames = new Set(
    character.forms.map((form) => form.form_name.trim().toLowerCase()).filter(Boolean),
  );
  for (let index = 2; index <= 999; index += 1) {
    const candidate = `${prefix} ${index}`;
    if (!existingNames.has(candidate.toLowerCase())) {
      return candidate;
    }
  }
  return `${prefix} ${Date.now()}`;
}

async function switchCharacterForm() {
  if (!currentSession.value?.name || !editingCharacter.value || !selectedCharacterFormId.value) {
    return;
  }
  if (selectedCharacterFormId.value === editingCharacter.value.active_form_id) {
    return;
  }
  const switched = await loreStore.setCharacterActiveForm(
    currentSession.value.name,
    editingCharacter.value.character_id,
    selectedCharacterFormId.value,
  );
  if (!switched) {
    return;
  }
  void openCharacterOverlay(switched.character_id, selectedCharacterFormId.value);
  notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
}

async function createCharacterForm() {
  if (!currentSession.value?.name || !editingCharacter.value) {
    return;
  }
  const character = editingCharacter.value;
  const created = await loreStore.addCharacterForm(currentSession.value.name, character.character_id, {
    form_name: buildNewFormName(character),
    is_default: false,
  });
  if (!created) {
    return;
  }
  const switched = await loreStore.setCharacterActiveForm(
    currentSession.value.name,
    character.character_id,
    created.form_id,
  );
  if (!switched) {
    return;
  }
  void openCharacterOverlay(switched.character_id, created.form_id);
  notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
}

async function deleteCharacterForm() {
  if (!currentSession.value?.name || !editingCharacter.value || !selectedCharacterFormId.value) {
    return;
  }
  const deleted = await loreStore.deleteCharacterForm(
    currentSession.value.name,
    editingCharacter.value.character_id,
    selectedCharacterFormId.value,
  );
  if (!deleted) {
    return;
  }
  void openCharacterOverlay(editingCharacter.value.character_id);
  notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
}

async function handleCharacterToggle(characterId: string, enabled: boolean) {
  if (!currentSession.value?.name) {
    return;
  }
  const target = loreStore.characters.find((item) => item.character_id === characterId);
  if (!target) {
    return;
  }
  const updated = await loreStore.updateCharacter(currentSession.value.name, characterId, {
    disabled: !enabled,
  });
  if (updated) {
    notifyLoreDataChanged(currentSession.value.name, "rst-lore-panel");
  }
}

async function handleCharacterReorder() {
  if (!currentSession.value?.name || characterRows.value.length === 0) {
    return;
  }
  const sessionName = currentSession.value.name;
  const reordered = await loreStore.reorderCharacters(sessionName, {
    character_ids: characterRows.value.map((character) => character.character_id),
  });
  if (!reordered) {
    characterRows.value = [...loreStore.characters];
    return;
  }
  notifyLoreDataChanged(sessionName, "rst-lore-panel");
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
  const sessionName = currentSession.value.name;
  const ids = [...selectedCharacterIds.value];
  for (const characterId of ids) {
    await loreStore.deleteCharacter(sessionName, characterId);
  }
  selectedCharacterIds.value = [];
  if (activeCharacterId.value && ids.includes(activeCharacterId.value)) {
    activeCharacterId.value = null;
  }
  if (editingCharacterId.value && ids.includes(editingCharacterId.value)) {
    closeCharacterOverlay();
  }
  if (ids.length > 0) {
    notifyLoreDataChanged(sessionName, "rst-lore-panel");
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

function toFormCreatePayload(form: CharacterForm) {
  return {
    form_name: form.form_name,
    is_default: form.is_default,
    physique: form.physique,
    features: form.features,
    vitality_max: form.vitality_max,
    strength: form.strength,
    mana_potency: form.mana_potency,
    toughness: form.toughness,
    weak: [...form.weak],
    resist: [...form.resist],
    element: [...form.element],
    skills: [...form.skills],
    penetration: [...form.penetration],
  };
}

function toFormUpdatePayload(form: CharacterForm) {
  return {
    form_name: form.form_name,
    is_default: form.is_default,
    physique: form.physique,
    features: form.features,
    vitality_max: form.vitality_max,
    strength: form.strength,
    mana_potency: form.mana_potency,
    toughness: form.toughness,
    weak: [...form.weak],
    resist: [...form.resist],
    element: [...form.element],
    skills: [...form.skills],
    penetration: [...form.penetration],
    clothing: form.clothing,
    body: form.body,
    mind: form.mind,
    vitality_cur: form.vitality_cur,
    activity: form.activity,
  };
}

async function copyCharacterFormsToSession(
  targetSessionName: string,
  sourceCharacter: CharacterData,
  targetCharacterId: string,
  initialTargetFormId: string | null,
): Promise<boolean> {
  if (sourceCharacter.forms.length === 0) {
    return true;
  }
  if (!initialTargetFormId) {
    return false;
  }

  const sourceToTargetFormId = new Map<string, string>();
  const firstSourceForm = sourceCharacter.forms[0];

  try {
    await updateForm(
      targetSessionName,
      targetCharacterId,
      initialTargetFormId,
      toFormUpdatePayload(firstSourceForm),
    );
    sourceToTargetFormId.set(firstSourceForm.form_id, initialTargetFormId);

    for (const sourceForm of sourceCharacter.forms.slice(1)) {
      const createdForm = await addForm(
        targetSessionName,
        targetCharacterId,
        toFormCreatePayload(sourceForm),
      );
      await updateForm(
        targetSessionName,
        targetCharacterId,
        createdForm.form_id,
        toFormUpdatePayload(sourceForm),
      );
      sourceToTargetFormId.set(sourceForm.form_id, createdForm.form_id);
    }

    const sourceDefaultForm = sourceCharacter.forms.find((form) => form.is_default);
    if (sourceDefaultForm) {
      const mappedDefaultFormId = sourceToTargetFormId.get(sourceDefaultForm.form_id);
      if (!mappedDefaultFormId) {
        return false;
      }
      await updateForm(targetSessionName, targetCharacterId, mappedDefaultFormId, {
        is_default: true,
      });
    }

    const mappedActiveFormId = sourceToTargetFormId.get(sourceCharacter.active_form_id);
    if (mappedActiveFormId) {
      await setActiveForm(targetSessionName, targetCharacterId, mappedActiveFormId);
    }
  } catch (error) {
    message.error(parseApiError(error));
    return false;
  }

  return true;
}

async function copyCharacterMemoriesToSession(
  targetSessionName: string,
  sourceCharacter: CharacterData,
  targetCharacterId: string,
): Promise<boolean> {
  try {
    for (const memory of sourceCharacter.memories) {
      await addMemory(targetSessionName, targetCharacterId, {
        event: memory.event,
        importance: memory.importance,
        tags: [...memory.tags],
        known_by: [...memory.known_by],
        plot_event_id: memory.plot_event_id ?? undefined,
      });
    }
  } catch (error) {
    message.error(parseApiError(error));
    return false;
  }
  return true;
}

async function confirmCharacterCopy() {
  if (!characterCopyTarget.value || selectedCharacters.value.length === 0) {
    return;
  }
  const targetSessionName = characterCopyTarget.value;
  const touchedSessions = new Set<string>();
  let copiedCount = 0;
  for (const character of selectedCharacters.value) {
    let createdCharacterId: string | null = null;
    try {
      const created = await createCharacter(targetSessionName, {
        name: character.name,
        race: character.race,
        gender: character.gender,
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
      createdCharacterId = created.character_id;

      const formsCopied = await copyCharacterFormsToSession(
        targetSessionName,
        character,
        created.character_id,
        created.forms[0]?.form_id ?? null,
      );
      if (!formsCopied) {
        await deleteCharacter(targetSessionName, created.character_id);
        continue;
      }

      const memoriesCopied = await copyCharacterMemoriesToSession(
        targetSessionName,
        character,
        created.character_id,
      );
      if (!memoriesCopied) {
        await deleteCharacter(targetSessionName, created.character_id);
        continue;
      }

      copiedCount += 1;
      touchedSessions.add(targetSessionName);
    } catch (error) {
      message.error(parseApiError(error));
      if (createdCharacterId) {
        try {
          await deleteCharacter(targetSessionName, createdCharacterId);
        } catch {
          // Ignore rollback failures to keep copy flow moving.
        }
      }
    }
  }
  touchedSessions.forEach((sessionName) => {
    notifyLoreDataChanged(sessionName, "rst-lore-panel");
  });
  closeCharacterCopyModal();
  if (copiedCount > 0) {
    message.success(
      formatText("rstPanel.messages.copy_characters_done", {
        count: copiedCount,
      }),
    );
  }
}

function toggleSchedulerPrompt(promptKey: SchedulerPromptKey) {
  collapsedSchedulerPrompts[promptKey] = !collapsedSchedulerPrompts[promptKey];
}

function toggleAllSchedulerPrompts() {
  const nextCollapsed = !allSchedulerPromptsCollapsed.value;
  schedulerPromptConfigs.value.forEach((prompt) => {
    collapsedSchedulerPrompts[prompt.key] = nextCollapsed;
  });
}

function buildSchedulerHitLookup(entries: LoreEntry[], characters: CharacterData[]): Map<string, SchedulerHitItem> {
  const lookup = new Map<string, SchedulerHitItem>();

  entries.forEach((entry) => {
    lookup.set(entry.id, {
      id: entry.id,
      name: entry.name || entry.id,
      typeLabel: t("rstPanel.scheduler.hit_type.entry"),
    });
  });

  characters.forEach((character) => {
    lookup.set(character.character_id, {
      id: character.character_id,
      name: character.name || character.character_id,
      typeLabel: t("rstPanel.scheduler.hit_type.character"),
    });
    character.memories.forEach((memory) => {
      const memoryName = memory.event
        ? `${character.name || character.character_id}: ${memory.event}`
        : `${character.name || character.character_id}: ${memory.memory_id}`;
      lookup.set(memory.memory_id, {
        id: memory.memory_id,
        name: memoryName,
        typeLabel: t("rstPanel.scheduler.hit_type.memory"),
      });
    });
  });

  return lookup;
}

async function openSchedulerHitsOverlay() {
  if (!currentSession.value?.name) {
    return;
  }
  schedulerHitsOverlayVisible.value = true;
  const ids = [...schedulerMatchedIds.value];
  schedulerHitItems.value = [];
  if (ids.length === 0) {
    schedulerHitLoading.value = false;
    return;
  }

  schedulerHitLoading.value = true;
  try {
    const entriesResponse = await listEntries(currentSession.value.name);
    const hitLookup = buildSchedulerHitLookup(entriesResponse.entries, characterRows.value);
    schedulerHitItems.value = ids.map((id) => {
      const found = hitLookup.get(id);
      if (found) {
        return found;
      }
      return {
        id,
        name: id,
        typeLabel: t("rstPanel.scheduler.hit_type.unknown"),
      };
    });
  } catch {
    schedulerHitItems.value = ids.map((id) => ({
      id,
      name: id,
      typeLabel: t("rstPanel.scheduler.hit_type.unknown"),
    }));
    message.error(t("rstPanel.messages.scheduler_hits_load_failed"));
  } finally {
    schedulerHitLoading.value = false;
  }
}

function openSyncChangesOverlay() {
  syncChangesOverlayVisible.value = true;
}

function syncActionLabel(action: string): string {
  const labels: Record<string, string> = {
    created: t("rstPanel.scheduler.sync_change.action.created"),
    updated: t("rstPanel.scheduler.sync_change.action.updated"),
    memory_added: t("rstPanel.scheduler.sync_change.action.memory_added"),
  };
  return labels[action] ?? t("rstPanel.scheduler.sync_change.action.unknown");
}

function syncCategoryLabel(category: string): string {
  const labels: Record<string, string> = {
    world_base: t("rstPanel.category.world_base"),
    society: t("rstPanel.category.society"),
    place: t("rstPanel.category.place"),
    faction: t("rstPanel.category.faction"),
    skills: t("rstPanel.category.skills"),
    others: t("rstPanel.category.others"),
    plot: t("rstPanel.category.plot"),
    character: t("rstPanel.scheduler.hit_type.character"),
    memory: t("rstPanel.scheduler.hit_type.memory"),
  };
  return labels[category] ?? category;
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
  importLlmFallback.value = true;
  importModalVisible.value = true;
  // Reset input value so selecting the same file triggers change again.
  target.value = "";
}

function closeImportModal() {
  importModalVisible.value = false;
  importingFile.value = null;
  splitFactionCharacters.value = false;
  importLlmFallback.value = true;
}

async function refreshLorePanelData(sessionName: string) {
  await Promise.all([
    loreStore.loadEntries(sessionName, entryCategory.value),
    loreStore.loadCharacters(sessionName),
    loadSkillEntryOptions(sessionName),
  ]);
}

async function fetchLoreTotals(sessionName: string): Promise<LoreTotals | null> {
  try {
    const [entriesResponse, charactersResponse] = await Promise.all([
      listEntries(sessionName),
      listCharacters(sessionName),
    ]);
    return {
      entries: entriesResponse.total ?? entriesResponse.entries.length,
      characters: charactersResponse.total ?? charactersResponse.characters.length,
    };
  } catch {
    return null;
  }
}

function didLoreTotalsChange(before: LoreTotals | null, after: LoreTotals | null): boolean {
  if (!before || !after) {
    return false;
  }
  return before.entries !== after.entries || before.characters !== after.characters;
}

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function recoverImportAfterTimeout(sessionName: string, baseline: LoreTotals | null) {
  const recoveryToken = ++importRecoveryToken.value;
  const maxAttempts = 8;
  const intervalMs = 4000;

  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    await wait(intervalMs);
    if (importRecoveryToken.value !== recoveryToken) {
      return;
    }
    if (currentSession.value?.name !== sessionName) {
      return;
    }
    const currentTotals = await fetchLoreTotals(sessionName);
    if (didLoreTotalsChange(baseline, currentTotals)) {
      await refreshLorePanelData(sessionName);
      notifyLoreDataChanged(sessionName, "rst-lore-panel");
      message.success(t("rstPanel.messages.import_timeout_recovered"));
      return;
    }
  }

  if (currentSession.value?.name !== sessionName) {
    return;
  }
  await refreshLorePanelData(sessionName);
  notifyLoreDataChanged(sessionName, "rst-lore-panel");
  message.info(t("rstPanel.messages.import_timeout_refresh_done"));
}

async function confirmImportLore() {
  if (!currentSession.value?.name || !importingFile.value) {
    return;
  }

  const sessionName = currentSession.value.name;
  importRecoveryToken.value += 1;
  const baselineTotals = await fetchLoreTotals(sessionName);

  const result = await loreStore.importLore(
    sessionName,
    importingFile.value,
    splitFactionCharacters.value,
    importLlmFallback.value,
  );
  if (!result.report) {
    if (result.timedOut) {
      closeImportModal();
      message.warning(t("rstPanel.messages.import_timeout_tracking"));
      await recoverImportAfterTimeout(sessionName, baselineTotals);
      return;
    }
    if (result.errorMessage) {
      message.error(result.errorMessage);
    }
    return;
  }

  const report = result.report;
  if (currentSession.value?.name !== sessionName) {
    return;
  }
  closeImportModal();
  await refreshLorePanelData(sessionName);
  notifyLoreDataChanged(sessionName, "rst-lore-panel");
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
    character_llm_structured_created: t(
      "rstPanel.report.action_type.character_llm_structured_created",
    ),
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
  overflow: hidden;
}

.panel-body :deep(.n-spin-container) {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.panel-body :deep(.n-spin-content) {
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
  overflow: hidden;
}

.panel-body :deep(.n-tabs-pane-wrapper) {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden !important;
}

.panel-body :deep(.n-tab-pane) {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden !important;
  padding: 0 !important;
}

.tab-content-wrapper {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
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

.entries-scroll-area {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  scrollbar-gutter: stable;
}

.entry-list {
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

.character-form-meta {
  font-size: 11px;
  color: var(--rst-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.character-form-toolbar {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  padding: 10px;
  background: var(--rst-bg-topbar);
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.character-form-toolbar-summary {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.character-form-toolbar-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.character-form-toolbar-actions :deep(.n-select) {
  width: 220px;
  max-width: 100%;
}

.character-memory-panel {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  padding: 10px;
  background: color-mix(in srgb, var(--rst-bg-topbar) 75%, transparent);
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 4px;
}

.character-memory-toggle {
  border: none;
  background: transparent;
  color: inherit;
  width: 100%;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 0;
}

.character-memory-toggle-meta {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.character-memory-title {
  font-size: 12px;
  font-weight: 600;
}

.character-memory-count {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.character-memory-arrow {
  display: inline-flex;
  transition: transform 0.2s ease;
}

.character-memory-arrow.collapsed {
  transform: rotate(-90deg);
}

.character-memory-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.character-memory-empty {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.character-memory-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 180px;
  overflow-y: auto;
  padding-right: 4px;
}

.character-memory-item {
  border: 1px solid var(--rst-border-color);
  border-radius: 8px;
  padding: 8px;
  background: var(--rst-bg-panel);
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.character-memory-item-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
}

.character-memory-item-actions {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.character-memory-event {
  font-size: 13px;
  font-weight: 600;
  white-space: pre-wrap;
  word-break: break-word;
  flex: 1;
  min-width: 0;
}

.character-memory-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 10px;
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.character-memory-extra {
  font-size: 11px;
  color: var(--rst-text-secondary);
  white-space: pre-wrap;
  word-break: break-word;
}

.memory-edit-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}

.memory-edit-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.memory-edit-item--full {
  grid-column: 1 / -1;
}

.memory-edit-label {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.memory-edit-actions {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
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
  min-height: 100%;
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
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  background: var(--rst-bg-topbar);
  padding: 10px;
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.scheduler-actions-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  position: sticky;
  top: 0;
  z-index: 2;
  background: var(--rst-bg-topbar);
}

.scheduler-actions-row :deep(.n-space) {
  flex-wrap: wrap;
}

.scheduler-prompts-panel {
  flex: 1;
  min-height: 0;
  border: 1px solid var(--rst-border-color);
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.scheduler-prompts-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-bottom: 1px solid var(--rst-border-color);
}

.scheduler-prompts-title {
  font-size: 12px;
  font-weight: 600;
}

.scheduler-prompts-scroll {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  scrollbar-gutter: stable;
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.scheduler-prompt-section {
  border: 1px solid var(--rst-border-color);
  border-radius: 8px;
  overflow: hidden;
}

.scheduler-prompt-toggle {
  width: 100%;
  border: none;
  background: transparent;
  color: inherit;
  cursor: pointer;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  font-size: 12px;
}

.scheduler-prompt-label {
  font-weight: 600;
}

.scheduler-prompt-arrow {
  transition: transform 0.2s ease;
}

.scheduler-prompt-arrow.collapsed {
  transform: rotate(-90deg);
}

.scheduler-prompt-input {
  border-top: 1px solid var(--rst-border-color);
  padding: 8px;
}

.scheduler-prompt-editor :deep(.n-input__textarea-el) {
  min-height: 180px;
  max-height: min(56vh, 560px);
  overflow-y: auto !important;
  resize: vertical;
  line-height: 1.45;
  tab-size: 2;
}

.scheduler-prompt-hint {
  margin-top: 8px;
  font-size: 11px;
  line-height: 1.45;
  color: var(--rst-text-secondary);
  white-space: pre-wrap;
}

.scheduler-hit-overlay-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-height: 220px;
  max-height: 65vh;
}

.scheduler-hit-summary {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.scheduler-hit-empty {
  border: 1px dashed var(--rst-border-color);
  border-radius: 8px;
  padding: 16px;
  text-align: center;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.scheduler-hit-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-right: 2px;
}

.scheduler-hit-item {
  border: 1px solid var(--rst-border-color);
  border-radius: 8px;
  padding: 8px 10px;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 10px;
}

.scheduler-hit-item-main {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.scheduler-hit-name {
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.scheduler-hit-id {
  font-size: 11px;
  color: var(--rst-text-secondary);
  word-break: break-all;
}

.sync-change-overlay-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-height: 260px;
  max-height: 70vh;
}

.sync-change-summary {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.sync-change-empty {
  border: 1px dashed var(--rst-border-color);
  border-radius: 8px;
  padding: 16px;
  text-align: center;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.sync-change-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-right: 2px;
}

.sync-change-card {
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  padding: 10px;
  background: var(--rst-bg-topbar);
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.sync-change-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}

.sync-change-title {
  font-size: 13px;
  font-weight: 600;
}

.sync-change-meta {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.sync-change-section {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.sync-change-label {
  font-size: 12px;
  font-weight: 600;
}

.sync-change-line {
  font-size: 12px;
  color: var(--rst-text-secondary);
  line-height: 1.4;
  white-space: pre-wrap;
}

.sync-change-block {
  font-size: 12px;
  color: var(--rst-text-secondary);
  line-height: 1.4;
  padding: 8px;
  border-radius: 8px;
  border: 1px dashed var(--rst-border-color);
  white-space: pre-wrap;
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
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.status-meta--interactive {
  border: none;
  padding: 0;
  background: transparent;
  cursor: pointer;
  text-align: left;
}

.status-meta-hint {
  color: #2563eb;
}

.status-meta--interactive:hover .status-meta-hint {
  text-decoration: underline;
}

@media (max-width: 720px) {
  .grid {
    grid-template-columns: 1fr;
  }

  .scheduler-actions-row {
    align-items: flex-start;
    flex-direction: column;
  }

  .character-form-toolbar-actions :deep(.n-select) {
    width: 100%;
  }

  .memory-edit-grid {
    grid-template-columns: 1fr;
  }
}
</style>

