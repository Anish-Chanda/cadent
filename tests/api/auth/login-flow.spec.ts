import { createUserData } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectJson, expectJwtCookie, UUID_PATTERN } from '../../lib/assertions';
import type { UserResponse } from '../../lib/types';

test.describe('login flow', () => {
  test('logs in and sets a persistent HttpOnly JWT cookie', async ({ createSession }) => {
    const session = await createSession({}, { login: false });

    const response = await session.api.login(session.user.email, session.user.password);
    expect(response.status()).toBe(200);
    await expectJwtCookie(session.context);

    const profile = await session.api.getUser();
    expect(profile.status()).toBe(200);
    const body = await expectJson<UserResponse>(profile);
    expect(body.id).toBe(session.user.id);
    expect(body.email).toBe(session.user.email);

    expect((await session.api.listActivities()).status()).toBe(200);
    expect((await session.api.getUser()).status()).toBe(200);
  });

  test('rejects invalid credentials without clearing an existing session', async ({
    createSession,
  }) => {
    const session = await createSession();

    const wrongPassword = await session.api.login(session.user.email, 'wrongpassword');
    expect(wrongPassword.status()).toBe(401);

    const unknownUser = await session.api.login(
      `nonexistent-${createUserData().email}`,
      'anypassword',
    );
    expect(unknownUser.status()).toBe(401);

    const profile = await session.api.getUser();
    expect(profile.status()).toBe(200);
    expect((await expectJson<UserResponse>(profile)).id).toBe(session.user.id);
  });

  const emptyCredentials = [
    { label: 'empty username', user: '', passwd: 'somepassword' },
    { label: 'empty password', user: 'someuser@test.com', passwd: '' },
    { label: 'missing credentials', user: null, passwd: null },
  ];

  for (const credentials of emptyCredentials) {
    test(`rejects ${credentials.label}`, async ({ anonymousApi }) => {
      const response =
        credentials.user === null
          ? await anonymousApi.login('', '')
          : await anonymousApi.login(credentials.user, credentials.passwd);

      expect(response.status()).toBe(401);
    });
  }

  test('accepts a password containing spaces', async ({ anonymousApi }) => {
    const email = createUserData().email;
    const password = 'my password has spaces';

    expect(
      (
        await anonymousApi.signup({
          user: email,
          passwd: password,
          name: 'Space Password User',
        })
      ).status(),
    ).toBe(201);

    expect((await anonymousApi.login(email, password)).status()).toBe(200);
  });

  test('treats email case-insensitively and trims whitespace', async ({ anonymousApi }) => {
    const user = createUserData({ email: `CaseLogin-${createUserData().email}` });

    expect(
      (
        await anonymousApi.signup({
          user: user.email,
          passwd: user.password,
          name: 'Case Login Test',
        })
      ).status(),
    ).toBe(201);

    expect((await anonymousApi.login(user.email.toLowerCase(), user.password)).status()).toBe(200);
    expect((await anonymousApi.login(user.email.toUpperCase(), user.password)).status()).toBe(200);

    const trimmedUser = createUserData({ email: `  trimlogin-${createUserData().email}  ` });
    expect(
      (
        await anonymousApi.signup({
          user: trimmedUser.email,
          passwd: trimmedUser.password,
          name: 'Trim Login Test',
        })
      ).status(),
    ).toBe(201);
    expect(
      (await anonymousApi.login(trimmedUser.email.trim(), trimmedUser.password)).status(),
    ).toBe(200);
  });

  test('logout clears the session', async ({ createSession }) => {
    const session = await createSession();

    expect((await session.api.getUser()).status()).toBe(200);
    expect((await session.api.logout()).status()).toBe(200);
    expect((await session.api.getUser()).status()).toBe(401);
  });

  test('signup response user id matches the authenticated profile', async ({
    createSession,
  }) => {
    const session = await createSession();

    expect(session.user.id).toMatch(UUID_PATTERN);
    const body = (await session.api.getUser().then(expectJson)) as UserResponse;
    expect(body.id).toBe(session.user.id);
  });
});
