import { test, expect } from '../../lib/fixtures';
import { expectJson, expectJsonError, UUID_PATTERN } from '../../lib/assertions';
import type { TrainingPlan, TrainingPlanWorkout } from '../../lib/types';

const ZERO_UUID = '00000000-0000-0000-0000-000000000000';

test.describe('training plan workouts', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    expect((await anonymousApi.getTrainingPlanWorkouts(ZERO_UUID)).status()).toBe(401);
  });

  test('returns workouts for a valid plan', async ({ session }) => {
    const plansResponse = await session.api.listTrainingPlans({
      q: 'Hal Higdon Intermediate 10K',
      activity_type: 'running',
    });
    expect(plansResponse.status()).toBe(200);
    const plans = await expectJson<TrainingPlan[]>(plansResponse);
    expect(plans.length).toBeGreaterThanOrEqual(1);
    expect(plans[0].id).toMatch(UUID_PATTERN);

    const response = await session.api.getTrainingPlanWorkouts(plans[0].id);
    expect(response.status()).toBe(200);
    const workouts = await expectJson<TrainingPlanWorkout[]>(response);

    expect(Array.isArray(workouts)).toBe(true);
    expect(workouts.length).toBeGreaterThanOrEqual(50);
    expect(workouts[0].training_plan_id).toBe(plans[0].id);
    expect(workouts[0].sequence_index).toBe(1);
    expect(workouts[1].sequence_index).toBe(2);
    expect(workouts[0].template_day_offset).toBe(0);
    expect(workouts[1].template_day_offset).toBe(1);
    expect(workouts.map((workout) => workout.type)).toContain('running');
    expect(workouts.map((workout) => workout.type)).toContain('resting');
  });

  test('returns 400 for a valid but non-existent plan ID', async ({ session }) => {
    await expectJsonError(
      await session.api.getTrainingPlanWorkouts(ZERO_UUID),
      400,
      'Invalid training plan ID',
    );
  });

  test('returns 500 for an invalid UUID', async ({ session }) => {
    test.info().annotations.push({
      type: 'known-bug',
      description:
        'The API currently returns 500 for a malformed plan UUID instead of a clean 4xx response.',
    });

    const response = await session.api.getTrainingPlanWorkouts('invalid-uuid-abc');
    expect(response.status()).toBe(500);
    expect((await expectJson<{ error: string }>(response)).error).toBeTruthy();
  });
});
