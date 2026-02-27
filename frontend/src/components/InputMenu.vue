<template>
  <div class="input-menu">
    <input
      ref="fileInput"
      class="input-menu__file"
      type="file"
      multiple
      @change="handleFileChange"
    />

    <button type="button" class="input-menu__trigger" @click="toggleMenu">
      Actions
    </button>

    <div v-if="isMenuOpen" class="input-menu__panel">
      <button
        v-for="item in menuItems"
        :key="item.action"
        type="button"
        class="input-menu__item"
        :class="{ 'is-disabled': item.disabled }"
        :disabled="item.disabled"
        @click="handleAction(item.action)"
      >
        {{ item.label }}
      </button>
    </div>

    <div v-if="isMenuOpen" class="input-menu__backdrop" @click="closeMenu"></div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { storeToRefs } from "pinia";

import { message } from "@/utils/message";
import { useChatStore } from "@/stores/chat";

const chatStore = useChatStore();
const { hasMessages } = storeToRefs(chatStore);

const isMenuOpen = ref(false);
const fileInput = ref<HTMLInputElement | null>(null);

const menuItems = computed(() => [
  { label: "Attach file", action: "attach", disabled: false },
  { label: "Batch delete", action: "batch-delete", disabled: !hasMessages.value },
  { label: "Batch hide", action: "batch-hide", disabled: !hasMessages.value },
  { label: "Regenerate (soon)", action: "regenerate", disabled: true },
  { label: "Preview prompt (soon)", action: "preview", disabled: true },
  { label: "AI assist (soon)", action: "assist", disabled: true },
]);

const toggleMenu = () => {
  isMenuOpen.value = !isMenuOpen.value;
};

const closeMenu = () => {
  isMenuOpen.value = false;
};

const handleAction = (action: string) => {
  if (action !== "attach") {
    closeMenu();
  }

  switch (action) {
    case "attach":
      fileInput.value?.click();
      break;
    case "batch-delete":
      chatStore.enterBatchMode("delete");
      break;
    case "batch-hide":
      chatStore.enterBatchMode("hide");
      break;
    default:
      message.info("This action is not available yet.");
      break;
  }
};

const handleFileChange = (event: Event) => {
  const target = event.target as HTMLInputElement;
  if (!target.files) {
    return;
  }

  const files = Array.from(target.files);
  files.forEach((file) => {
    const reader = new FileReader();
    reader.onload = () => {
      const content = typeof reader.result === "string" ? reader.result : "";
      chatStore.addPendingAttachment({
        name: file.name,
        size: file.size,
        type: file.type,
        content,
      });
    };
    reader.readAsText(file);
  });

  target.value = "";
  closeMenu();
};
</script>

<style scoped lang="scss">
.input-menu {
  position: relative;
  display: inline-flex;
}

.input-menu__file {
  display: none;
}

.input-menu__trigger {
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-topbar);
  color: var(--rst-text-primary);
  padding: 8px 12px;
  border-radius: 8px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.input-menu__trigger:hover {
  border-color: var(--rst-accent);
  color: var(--rst-text-primary);
}

.input-menu__panel {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 0;
  min-width: 180px;
  display: flex;
  flex-direction: column;
  border-radius: 10px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-panel);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.35);
  z-index: 50;
  overflow: hidden;
}

.input-menu__item {
  padding: 10px 14px;
  text-align: left;
  border: none;
  background: transparent;
  color: var(--rst-text-primary);
  cursor: pointer;
  font-size: 12px;
  transition: background 0.2s ease, color 0.2s ease;
}

.input-menu__item:hover {
  background: rgba(255, 255, 255, 0.04);
}

.input-menu__item.is-disabled {
  color: var(--rst-text-secondary);
  cursor: not-allowed;
}

.input-menu__item.is-disabled:hover {
  background: transparent;
}

.input-menu__backdrop {
  position: fixed;
  inset: 0;
  z-index: 40;
}
</style>
