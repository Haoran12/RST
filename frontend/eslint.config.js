import vue from "eslint-plugin-vue";
import * as vueTs from "@vue/eslint-config-typescript";
import prettier from "eslint-config-prettier";

const defineConfig = vueTs.defineConfig ?? ((...config) => config);
const tsConfigs = vueTs.vueTsConfigs?.recommended ?? [];

export default defineConfig(
  {
    ignores: ["dist", "node_modules"],
  },
  ...vue.configs["flat/recommended"],
  ...tsConfigs,
  prettier,
  {
    rules: {
      "vue/multi-word-component-names": "off",
    },
  },
);
