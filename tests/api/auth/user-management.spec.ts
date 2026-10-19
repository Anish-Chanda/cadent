import { test, expect } from '../../lib/fixtures';
import { expectJson, UUID_PATTERN } from '../../lib/assertions';
import type { UserResponse } from '../../lib/types';

test.describe('user management', () => {
  test('returns the current user and keeps the session after a failed login', async ({
    session,
  }) => {
    const profile = await session.api.getUser();
    expect(profile.status()).toBe(200);
    expect(profile.headers()['content-type']).toContain('application/json');

    const body = await expectJson<UserResponse>(profile);
    expect(body).toMatchObject({
      id: session.user.id,
      email: session.user.email,
      name: session.user.name,
    });
    expect(body.id).toMatch(UUID_PATTERN);

    expect((await session.api.login('invalid@test.com', 'wrong')).status()).toBe(401);
    expect(await expectJson<UserResponse>(await session.api.getUser())).toMatchObject({
      id: session.user.id,
      email: session.user.email,
    });
  });

  test('updates the user name and persists it', async ({ session }) => {
    const update = await session.api.updateUser({ name: 'Updated User Name' });
    expect(update.status()).toBe(200);
    expect(await expectJson<UserResponse>(update)).toMatchObject({
      id: session.user.id,
      name: 'Updated User Name',
    });

    expect(await expectJson<UserResponse>(await session.api.getUser())).toMatchObject({
      id: session.user.id,
      name: 'Updated User Name',
    });
  });

  const acceptedNames = ['José María 日本語', 'User 🚀 🏃‍♂️', 'Final Updated Name'];

  for (const name of acceptedNames) {
    test(`accepts name "${name}"`, async ({ session }) => {
      const update = await session.api.updateUser({ name });
      expect(update.status()).toBe(200);
      expect(await expectJson<UserResponse>(update)).toMatchObject({ name });

      expect(await expectJson<UserResponse>(await session.api.getUser())).toMatchObject({ name });
    });
  }

  test('rejects invalid updates and leaves the profile unchanged', async ({ session }) => {
    const original = await expectJson<UserResponse>(await session.api.getUser());

    const invalidUpdates = [
      { label: 'empty name', body: { name: '' } },
      { label: 'whitespace name', body: { name: '     ' } },
      { label: 'empty object', body: {} },
    ];

    for (const { label, body } of invalidUpdates) {
      const response = await session.api.updateUser(body);
      expect(response.status(), label).toBe(400);
    }

    const invalidJson = await session.api.updateUserRaw('{invalid json}');
    expect(invalidJson.status()).toBe(400);

    expect(await expectJson<UserResponse>(await session.api.getUser())).toMatchObject({
      id: original.id,
      email: original.email,
      name: original.name,
    });
  });

  const unsafeNames = [
    'ThisIsAVeryLongNameThatTestsTheMaximumLengthAllowedForUserNamesInTheSystemAbcdefghijklmnopqrstuvwxyzAbcdefghijklmnopqrstuvwxyz',
    "<script>alert('xss')</script>",
    "'; DROP TABLE users; --",
  ];

  for (const name of unsafeNames) {
    test(`accepts and stores name variant ${unsafeNames.indexOf(name) + 1}`, async ({
      session,
    }) => {
      const update = await session.api.updateUser({ name });
      expect(update.status()).toBe(200);
      expect(await expectJson<UserResponse>(update)).toMatchObject({ name });

      expect(await expectJson<UserResponse>(await session.api.getUser())).toMatchObject({ name });
    });
  }

  test('final update keeps id and email intact', async ({ session }) => {
    const update = await session.api.updateUser({ name: 'Final Updated Name' });
    expect(update.status()).toBe(200);
    expect(await expectJson<UserResponse>(update)).toMatchObject({
      id: session.user.id,
      email: session.user.email,
      name: 'Final Updated Name',
    });
  });
});
