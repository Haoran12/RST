import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";
import path from "node:path";

export default defineConfig(({ mode }) => {
  const repoRoot = path.resolve(__dirname, "..");
  // Load env vars from repo root so backend/frontend share one .env
  const env = loadEnv(mode, repoRoot, "");
  const devPort = Number(env.VITE_DEV_PORT || 15173);
  const backendPort = Number(env.RST_BACKEND_PORT || 18080);

  return {
    envDir: repoRoot,
    plugins: [vue()],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "src"),
      },
    },
    css: {
      preprocessorOptions: {
        scss: {
          additionalData: '@use "@/styles/variables.scss" as *;',
        },
      },
    },
    server: {
      port: devPort,
      proxy: {
        "/api": {
          // Proxy API calls to backend in dev, stripping /api prefix
          target: `http://127.0.0.1:${backendPort}`,
          changeOrigin: true,
          rewrite: (pathValue) => pathValue.replace(/^\/api/, ""),
        },
      },
    },
  };
});
