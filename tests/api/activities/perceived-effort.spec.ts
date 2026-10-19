import { createActivityPayload } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectJson, expectTextError, UUID_PATTERN } from '../../lib/assertions';
import type { ActivityResult, GetActivitiesResponse } from '../../lib/types';

test.describe('perceived effort', () => {
  test('creates activities across the valid effort range', async ({ session }) => {
    const cases = [
      { effort: 1, title: 'Minimum Effort Bike' },
      { effort: 7, title: 'Valid Effort Run' },
      { effort: 10, title: 'Maximum Effort Run' },
    ];

    for (const { effort, title } of cases) {
      const response = await session.api.createActivity(
        createActivityPayload({
          activity_type: 'road_biking',
          title,
          description: `Testing perceived_effort ${effort}`,
          perceived_effort: effort,
        }),
      );

      expect(response.status()).toBe(201);
      const activity = await expectJson<ActivityResult>(response);
      expect(activity.id).toMatch(UUID_PATTERN);
      expect(activity.perceived_effort).toBe(effort);
      expect(activity.title).toBe(title);
    }
  });

  test('treats omitted and explicit-null effort as null', async ({ session }) => {
    const omitted = await session.api.createActivity(
      createActivityPayload({ activity_type: 'road_biking', title: 'No Effort Specified' }),
    );
    expect(omitted.status()).toBe(201);
    const omittedBody = await expectJson<ActivityResult>(omitted);
    expect(omittedBody.title).toBe('No Effort Specified');
    expect(omittedBody.perceived_effort).toBeNull();

    const explicitNull = await session.api.createActivity(
      createActivityPayload({
        activity_type: 'road_biking',
        title: 'Explicit Null Effort',
        perceived_effort: null,
      }),
    );
    expect(explicitNull.status()).toBe(201);
    const explicitNullBody = await expectJson<ActivityResult>(explicitNull);
    expect(explicitNullBody.title).toBe('Explicit Null Effort');
    expect(explicitNullBody.perceived_effort).toBeNull();
  });

  test('rejects out-of-range effort values', async ({ session }) => {
    for (const effort of [0, 11, -1]) {
      const response = await session.api.createActivity(
        createActivityPayload({
          activity_type: 'road_biking',
          title: `Invalid Effort ${effort}`,
          perceived_effort: effort,
        }),
      );

      await expectTextError(response, 400, 'perceived_effort must be between 1 and 10');
    }
  });

  test('returns perceived_effort in the activity list', async ({ session }) => {
    const withEffort = await session.api.createActivity(
      createActivityPayload({
        activity_type: 'road_biking',
        title: 'Valid Effort Run',
        perceived_effort: 7,
      }),
    );
    const withoutEffort = await session.api.createActivity(
      createActivityPayload({
        activity_type: 'road_biking',
        title: 'No Effort Specified',
      }),
    );

    const withEffortId = (await expectJson<ActivityResult>(withEffort)).id;
    const withoutEffortId = (await expectJson<ActivityResult>(withoutEffort)).id;

    const list = await expectJson<GetActivitiesResponse>(await session.api.listActivities());
    const effortActivity = list.activities.find((activity) => activity.id === withEffortId);
    const nullActivity = list.activities.find((activity) => activity.id === withoutEffortId);

    expect(effortActivity?.title).toBe('Valid Effort Run');
    expect(effortActivity?.perceived_effort).toBe(7);
    expect(nullActivity?.title).toBe('No Effort Specified');
    expect(nullActivity?.perceived_effort).toBeNull();
  });
});
