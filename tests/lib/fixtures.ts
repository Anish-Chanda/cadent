import type { APIRequestContext } from '@playwright/test';
import { test as base, expect } from '@playwright/test';
import { CadentApi } from './api-client';
import { baseURL } from './env';
import { createUserData, type TestUser } from './factories';
import type { SignupResponse } from './types';

const requestTimeout = 60_000;

export interface TestSession {
  user: TestUser;
  api: CadentApi;
  context: APIRequestContext;
}

export interface CreateSessionOptions {
  login?: boolean;
}

export type CreateSession = (
  overrides?: Partial<TestUser>,
  options?: CreateSessionOptions,
) => Promise<TestSession>;

interface Fixtures {
  session: TestSession;
  createSession: CreateSession;
  anonymousApi: CadentApi;
}

export const test = base.extend<Fixtures>({
  createSession: async ({ playwright }, use) => {
    const contexts: APIRequestContext[] = [];

    const createSession: CreateSession = async (overrides = {}, options = {}) => {
      const context = await playwright.request.newContext({
        baseURL,
        timeout: requestTimeout,
        extraHTTPHeaders: { Accept: 'application/json' },
      });
      contexts.push(context);
      const api = new CadentApi(context);
      const user = createUserData(overrides);

      const signupResponse = await api.signup({
        user: user.email,
        passwd: user.password,
        name: user.name,
      });
      if (signupResponse.status() !== 201) {
        throw new Error(
          `Signup failed with ${signupResponse.status()}: ${await signupResponse.text()}`,
        );
      }

      const signup = (await signupResponse.json()) as SignupResponse;
      user.id = signup.user_id;

      if (options.login !== false) {
        const loginResponse = await api.login(user.email, user.password);
        if (loginResponse.status() !== 200) {
          throw new Error(
            `Login failed with ${loginResponse.status()}: ${await loginResponse.text()}`,
          );
        }
      }

      return { user, api, context };
    };

    await use(createSession);

    await Promise.all(contexts.map((context) => context.dispose()));
  },

  session: async ({ createSession }, use) => {
    await use(await createSession());
  },

  anonymousApi: async ({ playwright }, use) => {
    const context = await playwright.request.newContext({
      baseURL,
      timeout: requestTimeout,
      extraHTTPHeaders: { Accept: 'application/json' },
    });

    await use(new CadentApi(context));
    await context.dispose();
  },
});

export { expect };
