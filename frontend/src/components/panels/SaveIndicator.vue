<template>
  <div v-if="label" class="save-indicator" :class="statusClass">
    {{ label }}
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";

import { useI18n } from "@/composables/useI18n";

const props = defineProps<{
  status: "idle" | "saving" | "saved" | "error";
}>();
const { t } = useI18n();

const label = computed(() => {
  if (props.status === "saving") {
    return t("saveIndicator.saving");
  }
  if (props.status === "saved") {
    return t("saveIndicator.saved");
  }
  if (props.status === "error") {
    return t("saveIndicator.error");
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
