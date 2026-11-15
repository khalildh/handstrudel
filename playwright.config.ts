import { defineConfig } from "@playwright/test";

const local = "http://127.0.0.1:3819";

export default defineConfig({
  testDir: "./tests/web",
  workers: 1,
  use: { baseURL: local, browserName: "chromium", trace: "retain-on-failure" },
  webServer: {
    command: "npm run dev -- --hostname 127.0.0.1 --port 3819",
    url: `${local}/watch`,
    timeout: 120_000,
    env: {
      NEXT_PUBLIC_SUPABASE_URL: "https://feed.handstrudel.test",
      NEXT_PUBLIC_SUPABASE_ANON_KEY: "browser-test-placeholder",
      NEXT_PUBLIC_MEDIA_BASE_URL: "https://media.handstrudel.test",
    },
  },
});
