import { ref } from "vue";
import { createDiscreteApi, darkTheme } from "naive-ui";

import type { ThemeMode } from "@/stores/appearance";

const messageTheme = ref(
  typeof window !== "undefined" && window.localStorage.getItem("rst_theme_mode") === "light"
    ? null
    : darkTheme,
);

const { message } = createDiscreteApi(["message"], {
  configProviderProps: {
    theme: messageTheme,
  },
});

function setMessageTheme(theme: ThemeMode): void {
  messageTheme.value = theme === "dark" ? darkTheme : null;
}

export { message, setMessageTheme };
