import { defineStore } from "pinia";
import { ref, watch } from "vue";

export type LocaleCode = "en" | "zh-CN";

const STORAGE_KEY = "rst_locale";

function isLocaleCode(raw: string | null): raw is LocaleCode {
  return raw === "en" || raw === "zh-CN";
}

function detectBrowserLocale(): LocaleCode {
  if (typeof navigator === "undefined") {
    return "en";
  }
  return navigator.language.toLowerCase().startsWith("zh") ? "zh-CN" : "en";
}

function loadStoredLocale(): LocaleCode {
  if (typeof window === "undefined") {
    return "en";
  }
  const raw = window.localStorage.getItem(STORAGE_KEY);
  return isLocaleCode(raw) ? raw : detectBrowserLocale();
}

function applyLocale(locale: LocaleCode): void {
  if (typeof document !== "undefined") {
    document.documentElement.lang = locale;
  }
  if (typeof window !== "undefined") {
    window.localStorage.setItem(STORAGE_KEY, locale);
  }
}

export const useLanguageStore = defineStore("language", () => {
  const locale = ref<LocaleCode>(loadStoredLocale());
  const languageOptions: Array<{ label: string; value: LocaleCode }> = [
    { label: "English", value: "en" },
    { label: "\u7b80\u4f53\u4e2d\u6587", value: "zh-CN" },
  ];

  function setLocale(nextLocale: LocaleCode): void {
    locale.value = nextLocale;
  }

  watch(
    locale,
    (value) => {
      applyLocale(value);
    },
    { immediate: true },
  );

  return {
    locale,
    languageOptions,
    setLocale,
  };
});
