import { defineConfig } from '@playwright/test';
import { baseURL } from './lib/env';

const workers = process.env.E2E_WORKERS ? Number(process.env.E2E_WORKERS) : undefined;

export default defineConfig({
  testDir: './api',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  globalSetup: './global-setup.ts',
  outputDir: 'test-results',
  use: {
    baseURL,
    extraHTTPHeaders: { Accept: 'application/json' },
  },
  projects: [
    {
      name: 'api',
      testDir: './api',
    },
  ],
});
