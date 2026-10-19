import { request } from '@playwright/test';
import { baseURL } from './lib/env';

export default async function globalSetup() {
  const context = await request.newContext({ baseURL, timeout: 5_000 });

  try {
    const response = await context.get('/health');
    if (!response.ok()) {
      throw new Error(`GET /health returned ${response.status()}`);
    }
  } catch (error) {
    throw new Error(
      `Cadent API is not reachable at ${baseURL}. Start PostgreSQL with "make dev-up" ` +
        `and the API with "make run-api" (or set E2E_BASE_URL to the running API). ` +
        `Original error: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    await context.dispose();
  }
}
