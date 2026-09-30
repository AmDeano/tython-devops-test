import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// En dev (`npm run dev`), /api et /health sont proxifiés vers le backend local.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': process.env.VITE_API_PROXY || 'http://localhost:3000',
      '/health': process.env.VITE_API_PROXY || 'http://localhost:3000',
    },
  },
});
