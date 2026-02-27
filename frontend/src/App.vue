<template>
  <n-config-provider :theme="naiveTheme">
    <n-message-provider>
      <div class="rst-app">
        <main class="rst-main">
          <RouterView />
        </main>
      </div>
    </n-message-provider>
  </n-config-provider>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { storeToRefs } from "pinia";
import { NConfigProvider, NMessageProvider, darkTheme } from "naive-ui";

import { useAppearanceStore } from "@/stores/appearance";

const appearanceStore = useAppearanceStore();
const { theme } = storeToRefs(appearanceStore);

const naiveTheme = computed(() => (theme.value === "dark" ? darkTheme : null));
</script>

<style scoped lang="scss">
.rst-app {
  display: flex;
  width: 100vw;
  height: 100vh;
  background: var(--rst-bg-primary);
  color: var(--rst-text-primary);
  font-family: var(--rst-font-family);
  position: relative;
}

.rst-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: var(--rst-bg-secondary);
}
</style>

