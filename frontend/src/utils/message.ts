import { computed, ref } from "vue";
import { createDiscreteApi, darkTheme } from "naive-ui";

import type { ThemeMode } from "@/stores/appearance";

const messageTheme = ref(
  typeof window !== "undefined" && window.localStorage.getItem("rst_theme_mode") === "light"
    ? null
    : darkTheme,
);

const configProviderProps = computed(() => ({
  theme: messageTheme.value,
}));

const { message } = createDiscreteApi(["message"], {
  configProviderProps,
});

function setMessageTheme(theme: ThemeMode): void {
  messageTheme.value = theme === "dark" ? darkTheme : null;
}

export { message, setMessageTheme };
