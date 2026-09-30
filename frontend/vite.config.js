import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// f dev (npm run dev) kandouzo /api w /health l backend li khdam f local
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
