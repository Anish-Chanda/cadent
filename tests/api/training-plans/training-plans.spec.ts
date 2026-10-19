import { test, expect } from '../../lib/fixtures';
import { expectJson, expectJsonError, UUID_PATTERN } from '../../lib/assertions';
import type { TrainingPlan } from '../../lib/types';

test.describe('training plan listing', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    expect((await anonymousApi.listTrainingPlans()).status()).toBe(401);
  });

  test('returns all seeded training plans', async ({ session }) => {
    const response = await session.api.listTrainingPlans();
    expect(response.status()).toBe(200);

    const plans = await expectJson<TrainingPlan[]>(response);
    expect(Array.isArray(plans)).toBe(true);
    expect(plans.length).toBeGreaterThanOrEqual(2);
    expect(plans[0].id).toMatch(UUID_PATTERN);
    expect(plans[0].title).toBeTruthy();
    expect(plans[0].primary_activity_type).toBeTruthy();
    expect(plans[0].difficulty).toBeTruthy();
    expect(typeof plans[0].duration_weeks).toBe('number');
  });

  test('filters by running and road_biking activity types', async ({ session }) => {
    const runningResponse = await session.api.listTrainingPlans({
      activity_type: 'running',
    });
    expect(runningResponse.status()).toBe(200);
    const runningPlans = await expectJson<TrainingPlan[]>(runningResponse);
    expect(runningPlans.length).toBeGreaterThanOrEqual(2);
    expect(runningPlans.every((plan) => plan.primary_activity_type === 'running')).toBe(true);

    const bikingResponse = await session.api.listTrainingPlans({
      activity_type: 'road_biking',
    });
    expect(bikingResponse.status()).toBe(200);
    const bikingPlans = await expectJson<TrainingPlan[]>(bikingResponse);
    expect(Array.isArray(bikingPlans)).toBe(true);
    expect(
      bikingPlans.every((plan) => plan.primary_activity_type === 'road_biking'),
    ).toBe(true);
  });

  test('rejects an invalid activity type filter', async ({ session }) => {
    await expectJsonError(
      await session.api.listTrainingPlans({ activity_type: 'invalid_sport' }),
      400,
      'Invalid activity_type filter',
    );
  });

  test('searches plans by title', async ({ session }) => {
    const marathon = await session.api.listTrainingPlans({ q: 'marathon' });
    expect(marathon.status()).toBe(200);
    const marathonPlans = await expectJson<TrainingPlan[]>(marathon);
    expect(marathonPlans.length).toBeGreaterThanOrEqual(1);
    expect(marathonPlans.map((plan) => plan.title)).toContain(
      'Hal Higdon Intermediate 1 Marathon',
    );

    const tenK = await session.api.listTrainingPlans({
      q: '10K',
      activity_type: 'running',
    });
    expect(tenK.status()).toBe(200);
    const tenKPlans = await expectJson<TrainingPlan[]>(tenK);
    expect(tenKPlans.length).toBeGreaterThanOrEqual(1);
    expect(tenKPlans[0].primary_activity_type).toBe('running');
    expect(tenKPlans[0].title).toContain('10K');
  });

  test('returns an empty collection for a non-matching search', async ({ session }) => {
    const response = await session.api.listTrainingPlans({
      q: 'no-plan-matches-this-term-123456',
    });
    expect(response.status()).toBe(200);
    expect(await expectJson<TrainingPlan[]>(response)).toHaveLength(0);
  });
});
