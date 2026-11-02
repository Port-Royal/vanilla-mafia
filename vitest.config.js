import { fileURLToPath } from "node:url"
import { defineConfig } from "vitest/config"

export default defineConfig({
  resolve: {
    // The same bare names the importmap pins in the browser.
    alias: { live_protocol: fileURLToPath(new URL("./app/javascript/live_protocol", import.meta.url)) }
  },
  test: {
    environment: "jsdom",
    include: ["test/javascript/**/*.test.js"]
  }
})
