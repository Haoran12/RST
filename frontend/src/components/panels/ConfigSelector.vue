<template>
  <div class="config-selector">
    <div v-if="isRenaming" class="rename-row">
      <n-input
        v-model:value="renameInput"
        size="small"
        placeholder="输入新名称"
        :disabled="props.disabled"
        @keydown.enter.prevent="confirmRename"
        @keydown.esc.prevent="cancelRename"
      />
      <div class="rename-actions">
        <n-button size="small" type="primary" :disabled="props.disabled" @click="confirmRename">
          OK
        </n-button>
        <n-button size="small" secondary :disabled="props.disabled" @click="cancelRename">
          Cancel
        </n-button>
      </div>
    </div>
    <div v-else class="select-row">
      <n-select
        :value="selectedValue"
        :options="options"
        :placeholder="placeholder"
        size="small"
        :loading="props.loading ?? false"
        :disabled="props.disabled"
        @update:value="handleSelect"
      />
      <div class="action-buttons">
        <n-button size="small" type="primary" :disabled="props.disabled" @click="emit('create')">
          +
        </n-button>
        <n-button
          size="small"
          :disabled="props.disabled || !selectedValue || props.loading"
          @click="startRename"
        >
          ✍
        </n-button>
        <n-popconfirm
          :show-icon="false"
          positive-text="确认删除"
          :positive-button-props="{ type: 'error' }"
          @positive-click="emit('delete')"
        >
          <template #trigger>
            <n-button
              size="small"
              type="error"
              :disabled="props.disabled || !selectedValue || props.loading"
            >
              🗑️
            </n-button>
          </template>
          确认删除当前配置？
        </n-popconfirm>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { NButton, NInput, NPopconfirm, NSelect } from "naive-ui";
import type { SelectOption } from "naive-ui";

type ConfigSelectorOption = Omit<SelectOption, "label" | "value"> & {
  label: string;
  value: string;
};

const props = defineProps<{
  options: ConfigSelectorOption[];
  selectedValue: string | null;
  placeholder?: string;
  loading?: boolean;
  disabled?: boolean;
}>();

const emit = defineEmits<{
  (e: "select", value: string): void;
  (e: "create"): void;
  (e: "rename-confirm", newName: string): void;
  (e: "delete"): void;
}>();

const isRenaming = ref(false);
const renameInput = ref("");

const selectedLabel = computed<string>(() => {
  const selected = props.options.find((option) => option.value === props.selectedValue);
  return selected?.label ?? "";
});

watch(
  () => props.selectedValue,
  () => {
    if (!props.selectedValue && isRenaming.value) {
      isRenaming.value = false;
    }
  },
);

watch(
  () => props.disabled,
  (disabled) => {
    if (disabled && isRenaming.value) {
      isRenaming.value = false;
    }
  },
);

function handleSelect(value: string) {
  emit("select", value);
}

function startRename() {
  if (!props.selectedValue || props.disabled) {
    return;
  }
  renameInput.value = selectedLabel.value || props.selectedValue;
  isRenaming.value = true;
}

function confirmRename() {
  const newName = renameInput.value.trim();
  if (!newName) {
    return;
  }
  emit("rename-confirm", newName);
  isRenaming.value = false;
}

function cancelRename() {
  isRenaming.value = false;
}
</script>

<style scoped lang="scss">
.config-selector {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.select-row,
.rename-row {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
  align-items: center;
}

.action-buttons,
.rename-actions {
  display: flex;
  gap: 6px;
}
</style>
