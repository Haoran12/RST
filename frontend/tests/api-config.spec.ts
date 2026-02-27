import { beforeEach, describe, expect, it, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";

import { useApiConfigStore } from "@/stores/api-config";

vi.mock("naive-ui", () => ({
  useMessage: () => ({ error: vi.fn() }),
}));

const fetchApiConfigs = vi.fn();
const fetchApiConfig = vi.fn();
const createApiConfig = vi.fn();
const updateApiConfig = vi.fn();
const deleteApiConfig = vi.fn();
const fetchModels = vi.fn();

vi.mock("@/api/api-configs", () => ({
  fetchApiConfigs: (...args: unknown[]) => fetchApiConfigs(...args),
  fetchApiConfig: (...args: unknown[]) => fetchApiConfig(...args),
  createApiConfig: (...args: unknown[]) => createApiConfig(...args),
  updateApiConfig: (...args: unknown[]) => updateApiConfig(...args),
  deleteApiConfig: (...args: unknown[]) => deleteApiConfig(...args),
  fetchModels: (...args: unknown[]) => fetchModels(...args),
}));

describe("api-config store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.resetAllMocks();
  });

  it("loads configs", async () => {
    fetchApiConfigs.mockResolvedValue([{ id: "1", name: "A", provider: "openai", model: "" }]);
    const store = useApiConfigStore();
    await store.loadConfigs();
    expect(store.configs).toHaveLength(1);
    expect(store.configs[0].name).toBe("A");
  });

  it("saves new config", async () => {
    fetchApiConfigs.mockResolvedValue([{ id: "1", name: "A", provider: "openai", model: "" }]);
    createApiConfig.mockResolvedValue({
      id: "1",
      name: "A",
      provider: "openai",
      base_url: "https://api.openai.com/v1",
      api_key_preview: "****1234",
      model: "",
      temperature: 0.7,
      max_tokens: 4096,
      stream: true,
    });
    const store = useApiConfigStore();
    const result = await store.saveConfig({
      name: "A",
      provider: "openai",
      api_key: "sk-test-1234",
    });
    expect(result?.id).toBe("1");
    expect(store.configs).toHaveLength(1);
  });

  it("removes config", async () => {
    fetchApiConfigs.mockResolvedValueOnce([
      { id: "1", name: "A", provider: "openai", model: "" },
    ]);
    fetchApiConfigs.mockResolvedValueOnce([]);
    const store = useApiConfigStore();
    await store.loadConfigs();
    await store.removeConfig("1");
    expect(store.configs).toHaveLength(0);
  });
});
