import { ref } from "vue";

interface UseAutoSaveOptions {
  saveFn: () => Promise<void>;
  delay?: number;
}

export function useAutoSave(options: UseAutoSaveOptions) {
  const saveStatus = ref<"idle" | "saving" | "saved" | "error">("idle");
  const delay = options.delay ?? 300;
  let timer: number | undefined;
  let idleTimer: number | undefined;
  let dirty = false;

  async function runSave(): Promise<void> {
    if (!dirty) {
      return;
    }
    dirty = false;
    if (idleTimer) {
      window.clearTimeout(idleTimer);
      idleTimer = undefined;
    }
    saveStatus.value = "saving";
    try {
      await options.saveFn();
      saveStatus.value = "saved";
      idleTimer = window.setTimeout(() => {
        saveStatus.value = "idle";
      }, 1000);
    } catch {
      saveStatus.value = "error";
    }
  }

  function markDirty(): void {
    dirty = true;
    if (timer) {
      window.clearTimeout(timer);
    }
    timer = window.setTimeout(() => {
      timer = undefined;
      void runSave();
    }, delay);
  }

  async function flush(): Promise<void> {
    if (timer) {
      window.clearTimeout(timer);
      timer = undefined;
    }
    await runSave();
  }

  function cancel(): void {
    dirty = false;
    if (timer) {
      window.clearTimeout(timer);
      timer = undefined;
    }
    saveStatus.value = "idle";
  }

  return {
    saveStatus,
    markDirty,
    flush,
    cancel,
  };
}

