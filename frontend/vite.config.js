import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(process.cwd(), './src'),
      },
    },
    server: {
      port: 5173
    },
    build: {
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (id.includes('node_modules')) {
              if (id.includes('framer-motion')) {
                return 'vendor-framer-motion';
              }
              if (id.includes('gsap')) {
                return 'vendor-gsap';
              }
              if (id.includes('lucide-react')) {
                return 'vendor-lucide';
              }
              if (id.includes('recharts')) {
                return 'vendor-recharts';
              }
              if (id.includes('react') || id.includes('react-dom') || id.includes('react-router-dom')) {
                return 'vendor-react-core';
              }
              return 'vendor-libs';
            }
          }
        }
      }
    },
    envPrefix: ['VITE_', 'NEXT_PUBLIC_'],
    define: {
      'process.env.NEXT_PUBLIC_API_URL': (env.NEXT_PUBLIC_API_URL || env.VITE_API_URL)
        ? JSON.stringify(env.NEXT_PUBLIC_API_URL || env.VITE_API_URL)
        : '(typeof window !== "undefined" && window.location && window.location.hostname !== "localhost" && window.location.hostname !== "127.0.0.1" ? "https://api.between.indevs.in/api/v1" : "http://127.0.0.1:8000/api/v1")',
      'import.meta.env.VITE_GITHUB_CLIENT_ID': JSON.stringify(env.VITE_GITHUB_CLIENT_ID || 'Ov23liZTawFuQJbU3Q1J'),
      'import.meta.env.VITE_GOOGLE_CLIENT_ID': JSON.stringify(env.VITE_GOOGLE_CLIENT_ID || '320168228370-ad5e4ps0mahi6eogc3rum8971441hcnp.apps.googleusercontent.com')
    }
  }
})
