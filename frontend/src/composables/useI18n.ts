import { computed } from "vue";
import { storeToRefs } from "pinia";

import { FALLBACK_LOCALE, messages } from "@/i18n/messages";
import { useLanguageStore } from "@/stores/language";

export function useI18n() {
  const languageStore = useLanguageStore();
  const { locale } = storeToRefs(languageStore);

  const currentMessages = computed(() => messages[locale.value] ?? messages[FALLBACK_LOCALE]);

  function t(key: string): string {
    return currentMessages.value[key] ?? messages[FALLBACK_LOCALE][key] ?? key;
  }

  return {
    t,
  };
}
