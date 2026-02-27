<template>
  <aside
    class="rst-panel-container"
    :class="{ 'is-open': activePanel }"
    @click.stop
  >
    <div class="rst-icon-bar">
      <div class="rst-icon-group">
        <button
          v-for="item in panelItems"
          :key="item.type"
          class="icon-button"
          :class="{ 'is-active': activePanel === item.type }"
          type="button"
          @click="togglePanel(item.type)"
          :aria-label="item.label"
          :title="item.label"
        >
          <span class="icon-emoji" aria-hidden="true">{{ item.icon }}</span>
        </button>
      </div>
      <div class="rst-icon-footer">
        <button
          class="icon-button"
          :class="{ 'is-active': activePanel === 'log' }"
          type="button"
          @click="togglePanel('log')"
          aria-label="Log"
          title="Log"
        >
          <span class="icon-emoji" aria-hidden="true">📜</span>
        </button>
      </div>
    </div>

    <transition name="panel-slide">
      <div v-if="activePanel" class="rst-panel">
        <transition name="panel-content" mode="out-in">
          <component :is="panelComponent" :key="activePanel" />
        </transition>
      </div>
    </transition>
  </aside>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";

import ApiConfigPanel from "@/components/panels/ApiConfigPanel.vue";
import AppearancePanel from "@/components/panels/AppearancePanel.vue";
import ExtensionsPanel from "@/components/panels/ExtensionsPanel.vue";
import LogPanel from "@/components/panels/LogPanel.vue";
import LorePanel from "@/components/panels/LorePanel.vue";
import PresetPanel from "@/components/panels/PresetPanel.vue";
import RstLorePanel from "@/components/panels/RstLorePanel.vue";
import SessionPanel from "@/components/panels/SessionPanel.vue";

type PanelType =
  | "session"
  | "api"
  | "preset"
  | "lore"
  | "rst-lore"
  | "appearance"
  | "extensions"
  | "log"
  | null;

const activePanel = ref<PanelType>(null);
const panelItems = [
  { label: "Presets", icon: "📝", type: "preset" as const },
  { label: "API", icon: "🔌", type: "api" as const },
  { label: "Lores", icon: "📚", type: "lore" as const },
  { label: "RST Lores", icon: "🌍", type: "rst-lore" as const },
  { label: "Sessions", icon: "💬", type: "session" as const },
  { label: "Appearance", icon: "🎨", type: "appearance" as const },
  { label: "Extensions", icon: "🧩", type: "extensions" as const },
];

const panelComponent = computed(() => {
  switch (activePanel.value) {
    case "session":
      return SessionPanel;
    case "api":
      return ApiConfigPanel;
    case "preset":
      return PresetPanel;
    case "lore":
      return LorePanel;
    case "rst-lore":
      return RstLorePanel;
    case "appearance":
      return AppearancePanel;
    case "extensions":
      return ExtensionsPanel;
    case "log":
      return LogPanel;
    default:
      return null;
  }
});

function togglePanel(panel: PanelType) {
  if (activePanel.value === panel) {
    activePanel.value = null;
    return;
  }

  activePanel.value = panel;
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === "Escape") {
    activePanel.value = null;
  }
}

function handleChatAreaClick() {
  if (!activePanel.value) {
    return;
  }
  activePanel.value = null;
}

onMounted(() => {
  window.addEventListener("keydown", handleKeydown);
  window.addEventListener("rst-chat-area-click", handleChatAreaClick as EventListener);
});

onBeforeUnmount(() => {
  window.removeEventListener("keydown", handleKeydown);
  window.removeEventListener("rst-chat-area-click", handleChatAreaClick as EventListener);
});
</script>

<style scoped lang="scss">
.rst-panel-container {
  position: relative;
  width: 48px;
  height: 100%;
  flex-shrink: 0;
  background: var(--rst-bg-panel);
  border-right: 1px solid var(--rst-border-color);
  transition: width 0.2s ease;
  overflow: hidden;
}

.rst-panel-container.is-open {
  width: 408px;
}

.rst-icon-bar {
  width: 48px;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 8px;
  border-right: 1px solid var(--rst-border-color);
}

.rst-icon-group {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.rst-icon-footer {
  margin-top: auto;
  padding-top: 12px;
}

.icon-button {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-topbar);
  color: var(--rst-text-primary);
  font-size: 18px;
  line-height: 1;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s ease, border-color 0.2s ease, color 0.2s ease;
}

.icon-button:hover {
  background: var(--rst-accent);
  border-color: var(--rst-accent);
  color: #ffffff;
}

.icon-button.is-active {
  background: var(--rst-accent);
  border-color: var(--rst-accent);
  color: #ffffff;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
}

.rst-panel {
  position: absolute;
  inset: 0 0 0 48px;
  width: 360px;
  background: var(--rst-bg-panel);
  height: 100%;
  overflow: hidden;
}

.panel-slide-enter-active,
.panel-slide-leave-active {
  transition: transform 0.2s ease, opacity 0.2s ease;
}

.panel-slide-enter-from,
.panel-slide-leave-to {
  transform: translateX(-16px);
  opacity: 0;
}

.panel-content-enter-active,
.panel-content-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}

.panel-content-enter-from {
  opacity: 0;
  transform: translateY(8px);
}

.panel-content-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}


@media (max-width: 900px) {
  .rst-panel-container.is-open {
    width: 100vw;
  }

  .rst-panel {
    width: calc(100vw - 48px);
  }
}
</style>

