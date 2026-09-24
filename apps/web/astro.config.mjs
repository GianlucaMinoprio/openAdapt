import { defineConfig } from "astro/config";
export default defineConfig({
  site: "https://openadapt.app",
  output: "static",
  devToolbar: { enabled: false },
  // Keep the demo script external so the strict production CSP permits it.
  vite: { build: { assetsInlineLimit: 0 } },
});
