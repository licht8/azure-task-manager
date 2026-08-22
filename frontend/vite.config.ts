import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import tailwindcss from "@tailwindcss/vite";
import { nitro } from "nitro/vite";

export default defineConfig({
  plugins: [
    tanstackRouter(),
    tanstackStart(),
    react(),
    tailwindcss(),
    nitro(),
  ],

  server: {
    host: "0.0.0.0",
    port: 5173,
  },

  build: {
    target: "es2022",
  },

  resolve: {
    tsconfigPaths: true,
  },
});