import { defineStore } from "pinia";
import { ref, watch } from "vue";

import { setMessageTheme } from "@/utils/message";

export type ThemeMode = "dark" | "light";

const THEME_STORAGE_KEY = "rst_theme_mode";
const APPEARANCE_STORAGE_KEY = "rst_appearance_settings";
const DEFAULT_FONT_FAMILY =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';
const FONT_SIZE_SCALE_MIN = 0.8;
const FONT_SIZE_SCALE_MAX = 1.6;
const FONT_SIZE_SCALE_STEP = 0.05;

type AppearanceSettings = {
  fontFamily: string;
  fontSizeScale: number;
  markdownParagraphColor: string;
  markdownHeadingColor: string;
  markdownItalicColor: string;
  markdownQuotedColor: string;
};

function defaultSettingsForTheme(theme: ThemeMode): AppearanceSettings {
  if (theme === "light") {
    return {
      fontFamily: DEFAULT_FONT_FAMILY,
      fontSizeScale: 1,
      markdownParagraphColor: "#1f2937",
      markdownHeadingColor: "#0f172a",
      markdownItalicColor: "#334155",
      markdownQuotedColor: "#b45309",
    };
  }
  return {
    fontFamily: DEFAULT_FONT_FAMILY,
    fontSizeScale: 1,
    markdownParagraphColor: "#d4d4d4",
    markdownHeadingColor: "#f5f5f5",
    markdownItalicColor: "#cbd5e1",
    markdownQuotedColor: "#fbbf24",
  };
}

function isHexColor(value: unknown): value is string {
  return typeof value === "string" && /^#[0-9A-Fa-f]{6}$/.test(value);
}

function clampFontScale(value: unknown): number {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return 1;
  }
  const clamped = Math.min(FONT_SIZE_SCALE_MAX, Math.max(FONT_SIZE_SCALE_MIN, value));
  return Number(clamped.toFixed(2));
}

function loadStoredTheme(): ThemeMode {
  if (typeof window === "undefined") {
    return "dark";
  }
  const raw = window.localStorage.getItem(THEME_STORAGE_KEY);
  return raw === "light" || raw === "dark" ? raw : "dark";
}

function loadStoredSettings(theme: ThemeMode): AppearanceSettings {
  const defaults = defaultSettingsForTheme(theme);
  if (typeof window === "undefined") {
    return defaults;
  }
  const raw = window.localStorage.getItem(APPEARANCE_STORAGE_KEY);
  if (!raw) {
    return defaults;
  }
  try {
    const parsed = JSON.parse(raw) as Partial<AppearanceSettings> | null;
    if (!parsed || typeof parsed !== "object") {
      return defaults;
    }
    return {
      fontFamily:
        typeof parsed.fontFamily === "string" && parsed.fontFamily.trim().length > 0
          ? parsed.fontFamily.trim()
          : defaults.fontFamily,
      fontSizeScale: clampFontScale(parsed.fontSizeScale),
      markdownParagraphColor: isHexColor(parsed.markdownParagraphColor)
        ? parsed.markdownParagraphColor
        : defaults.markdownParagraphColor,
      markdownHeadingColor: isHexColor(parsed.markdownHeadingColor)
        ? parsed.markdownHeadingColor
        : defaults.markdownHeadingColor,
      markdownItalicColor: isHexColor(parsed.markdownItalicColor)
        ? parsed.markdownItalicColor
        : defaults.markdownItalicColor,
      markdownQuotedColor: isHexColor(parsed.markdownQuotedColor)
        ? parsed.markdownQuotedColor
        : defaults.markdownQuotedColor,
    };
  } catch {
    return defaults;
  }
}

function applyTheme(theme: ThemeMode): void {
  if (typeof document !== "undefined") {
    document.documentElement.dataset.theme = theme;
  }
  if (typeof window !== "undefined") {
    window.localStorage.setItem(THEME_STORAGE_KEY, theme);
  }
  setMessageTheme(theme);
}

function applyAppearanceSettings(settings: AppearanceSettings): void {
  if (typeof document === "undefined") {
    return;
  }
  const root = document.documentElement;
  root.style.setProperty("--rst-font-family", settings.fontFamily);
  root.style.setProperty("--rst-font-size-scale", String(settings.fontSizeScale));
  root.style.setProperty("--rst-md-color-paragraph", settings.markdownParagraphColor);
  root.style.setProperty("--rst-md-color-heading", settings.markdownHeadingColor);
  root.style.setProperty("--rst-md-color-italic", settings.markdownItalicColor);
  root.style.setProperty("--rst-md-color-quoted", settings.markdownQuotedColor);
}

function persistAppearanceSettings(settings: AppearanceSettings): void {
  if (typeof window === "undefined") {
    return;
  }
  window.localStorage.setItem(APPEARANCE_STORAGE_KEY, JSON.stringify(settings));
}

export const useAppearanceStore = defineStore("appearance", () => {
  const theme = ref<ThemeMode>(loadStoredTheme());
  const loadedSettings = loadStoredSettings(theme.value);

  const fontFamily = ref(loadedSettings.fontFamily);
  const fontSizeScale = ref(loadedSettings.fontSizeScale);
  const markdownParagraphColor = ref(loadedSettings.markdownParagraphColor);
  const markdownHeadingColor = ref(loadedSettings.markdownHeadingColor);
  const markdownItalicColor = ref(loadedSettings.markdownItalicColor);
  const markdownQuotedColor = ref(loadedSettings.markdownQuotedColor);

  const themeOptions = [
    { label: "Dark", value: "dark" },
    { label: "Light", value: "light" },
  ];

  watch(
    theme,
    (value, previousValue) => {
      if (previousValue && previousValue !== value) {
        const previousDefaults = defaultSettingsForTheme(previousValue);
        const nextDefaults = defaultSettingsForTheme(value);
        if (markdownParagraphColor.value === previousDefaults.markdownParagraphColor) {
          markdownParagraphColor.value = nextDefaults.markdownParagraphColor;
        }
        if (markdownHeadingColor.value === previousDefaults.markdownHeadingColor) {
          markdownHeadingColor.value = nextDefaults.markdownHeadingColor;
        }
        if (markdownItalicColor.value === previousDefaults.markdownItalicColor) {
          markdownItalicColor.value = nextDefaults.markdownItalicColor;
        }
        if (markdownQuotedColor.value === previousDefaults.markdownQuotedColor) {
          markdownQuotedColor.value = nextDefaults.markdownQuotedColor;
        }
      }
      applyTheme(value);
    },
    { immediate: true },
  );

  watch(
    fontSizeScale,
    (value) => {
      fontSizeScale.value = clampFontScale(value);
    },
    { immediate: true },
  );

  watch(
    [fontFamily, fontSizeScale, markdownParagraphColor, markdownHeadingColor, markdownItalicColor, markdownQuotedColor],
    () => {
      const settings: AppearanceSettings = {
        fontFamily:
          typeof fontFamily.value === "string" && fontFamily.value.trim().length > 0
            ? fontFamily.value.trim()
            : DEFAULT_FONT_FAMILY,
        fontSizeScale: clampFontScale(fontSizeScale.value),
        markdownParagraphColor: isHexColor(markdownParagraphColor.value)
          ? markdownParagraphColor.value
          : defaultSettingsForTheme(theme.value).markdownParagraphColor,
        markdownHeadingColor: isHexColor(markdownHeadingColor.value)
          ? markdownHeadingColor.value
          : defaultSettingsForTheme(theme.value).markdownHeadingColor,
        markdownItalicColor: isHexColor(markdownItalicColor.value)
          ? markdownItalicColor.value
          : defaultSettingsForTheme(theme.value).markdownItalicColor,
        markdownQuotedColor: isHexColor(markdownQuotedColor.value)
          ? markdownQuotedColor.value
          : defaultSettingsForTheme(theme.value).markdownQuotedColor,
      };
      fontFamily.value = settings.fontFamily;
      fontSizeScale.value = settings.fontSizeScale;
      markdownParagraphColor.value = settings.markdownParagraphColor;
      markdownHeadingColor.value = settings.markdownHeadingColor;
      markdownItalicColor.value = settings.markdownItalicColor;
      markdownQuotedColor.value = settings.markdownQuotedColor;
      applyAppearanceSettings(settings);
      persistAppearanceSettings(settings);
    },
    { immediate: true },
  );

  return {
    theme,
    themeOptions,
    fontFamily,
    fontSizeScale,
    markdownParagraphColor,
    markdownHeadingColor,
    markdownItalicColor,
    markdownQuotedColor,
    fontSizeScaleMin: FONT_SIZE_SCALE_MIN,
    fontSizeScaleMax: FONT_SIZE_SCALE_MAX,
    fontSizeScaleStep: FONT_SIZE_SCALE_STEP,
  };
});
