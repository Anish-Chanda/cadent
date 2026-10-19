import { test, expect } from '../../lib/fixtures';
import { expectJson, expectJwtCookie } from '../../lib/assertions';
import type { GetActivitiesResponse, UserResponse } from '../../lib/types';

test.describe('session isolation', () => {
  test('users only see and update their own data', async ({ createSession }) => {
    const userOne = await createSession({ name: 'User One' });
    const userTwo = await createSession({ name: 'User Two' });

    const userOneProfile = await expectJson<UserResponse>(await userOne.api.getUser());
    expect(userOneProfile).toMatchObject({
      id: userOne.user.id,
      email: userOne.user.email,
      name: 'User One',
    });

    const userOneActivities = await expectJson<GetActivitiesResponse>(
      await userOne.api.listActivities(),
    );
    expect(userOneActivities.activities).toHaveLength(0);

    const userTwoProfile = await expectJson<UserResponse>(await userTwo.api.getUser());
    expect(userTwoProfile).toMatchObject({
      id: userTwo.user.id,
      email: userTwo.user.email,
      name: 'User Two',
    });
    expect(userTwoProfile.id).not.toBe(userOne.user.id);
    expect(userTwoProfile.email).not.toBe(userOne.user.email);

    expect(
      (await expectJson<GetActivitiesResponse>(await userTwo.api.listActivities())).activities,
    ).toHaveLength(0);

    const updated = await userTwo.api.updateUser({ name: 'Updated User Two' });
    expect(updated.status()).toBe(200);
    expect(await expectJson<UserResponse>(updated)).toMatchObject({
      id: userTwo.user.id,
      name: 'Updated User Two',
    });

    const unchanged = await expectJson<UserResponse>(await userOne.api.getUser());
    expect(unchanged).toMatchObject({ id: userOne.user.id, name: 'User One' });
    expect(unchanged.name).not.toBe('Updated User Two');
  });

  test('logging in as another user replaces the active session', async ({ createSession }) => {
    const userOne = await createSession({ name: 'User One' });
    const userTwo = await createSession({ name: 'User Two' });

    const login = await userOne.api.login(userTwo.user.email, userTwo.user.password);
    expect(login.status()).toBe(200);
    await expectJwtCookie(userOne.context);

    expect(await expectJson<UserResponse>(await userOne.api.getUser())).toMatchObject({
      id: userTwo.user.id,
      name: 'User Two',
    });

    expect((await userOne.api.login('invalid@test.com', 'wrongpassword')).status()).toBe(401);
    expect(await expectJson<UserResponse>(await userOne.api.getUser())).toMatchObject({
      id: userTwo.user.id,
      name: 'User Two',
    });

    expect((await userOne.api.login(userOne.user.email, userOne.user.password)).status()).toBe(200);
    expect(await expectJson<UserResponse>(await userOne.api.getUser())).toMatchObject({
      id: userOne.user.id,
      name: 'User One',
    });
  });

  test('a third user cannot see another user profile', async ({ createSession }) => {
    const userOne = await createSession({ name: 'User One' });
    const userTwo = await createSession({ name: 'User Two' });
    const userThree = await createSession({ name: 'User Three' });

    const profile = await expectJson<UserResponse>(await userThree.api.getUser());
    expect(profile).toMatchObject({ id: userThree.user.id, name: 'User Three' });
    expect(profile.id).not.toBe(userOne.user.id);
    expect(profile.id).not.toBe(userTwo.user.id);
  });
});
