<template>
  <div v-if="label" class="save-indicator" :class="statusClass">
    {{ label }}
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";

const props = defineProps<{
  status: "idle" | "saving" | "saved" | "error";
}>();

const label = computed(() => {
  if (props.status === "saving") {
    return "保存中...";
  }
  if (props.status === "saved") {
    return "已保存 ?";
  }
  if (props.status === "error") {
    return "保存失败";
  }
  return "";
});

const statusClass = computed(() => `is-${props.status}`);
</script>

<style scoped lang="scss">
.save-indicator {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.save-indicator.is-saved {
  color: var(--rst-success, #22c55e);
}

.save-indicator.is-error {
  color: var(--rst-danger, #ef4444);
}
</style>

