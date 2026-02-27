import { defineStore } from "pinia";
import { ref, watch } from "vue";

import { setMessageTheme } from "@/utils/message";

export type ThemeMode = "dark" | "light";

const STORAGE_KEY = "rst_theme_mode";

function loadStoredTheme(): ThemeMode {
  if (typeof window === "undefined") {
    return "dark";
  }
  const raw = window.localStorage.getItem(STORAGE_KEY);
  return raw === "light" || raw === "dark" ? raw : "dark";
}

function applyTheme(theme: ThemeMode): void {
  if (typeof document !== "undefined") {
    document.documentElement.dataset.theme = theme;
  }
  if (typeof window !== "undefined") {
    window.localStorage.setItem(STORAGE_KEY, theme);
  }
  setMessageTheme(theme);
}

export const useAppearanceStore = defineStore("appearance", () => {
  const theme = ref<ThemeMode>(loadStoredTheme());
  const themeOptions = [
    { label: "Dark", value: "dark" },
    { label: "Light", value: "light" },
  ];

  watch(
    theme,
    (value) => {
      applyTheme(value);
    },
    { immediate: true },
  );

  return {
    theme,
    themeOptions,
  };
});
