import { createPlannedActivityPayload } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectJson, UUID_PATTERN } from '../../lib/assertions';
import type {
  CalendarResponse,
  TrainingPlan,
  TrainingPlanWorkout,
} from '../../lib/types';

const ZERO_UUID = '00000000-0000-0000-0000-000000000000';

test.describe('training plan import dry run', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    const response = await anonymousApi.dryRunImport(ZERO_UUID, {
      startDate: '2026-06-02T09:00:00Z',
      selectedWorkoutsPerWeek: 2,
      title: 'Unauthorized Dry Run',
    });
    expect(response.status()).toBe(401);
  });

  test('previews existing and generated planned activities', async ({ session }) => {
    test.slow();

    const plansResponse = await session.api.listTrainingPlans();
    expect(plansResponse.status()).toBe(200);
    const plans = await expectJson<TrainingPlan[]>(plansResponse);
    expect(plans.length).toBeGreaterThanOrEqual(1);
    expect(plans[0].id).toMatch(UUID_PATTERN);
    expect(plans[0].title).toBeTruthy();
    const plan = plans[0];

    const workoutsResponse = await session.api.getTrainingPlanWorkouts(plan.id);
    expect(workoutsResponse.status()).toBe(200);
    const workouts = await expectJson<TrainingPlanWorkout[]>(workoutsResponse);
    expect(workouts.length).toBeGreaterThanOrEqual(2);
    expect(workouts[0].sequence_index).toBe(1);
    expect(workouts[1].sequence_index).toBe(2);
    const firstWorkoutTitle = workouts[0].title;
    const secondWorkoutTitle = workouts[1].title;

    const seed = await session.api.createPlannedActivity(
      createPlannedActivityPayload({
        title: 'Seed Planned Session',
        description: 'Existing planned activity before import dry-run',
        activityType: 'running',
        startTime: '2026-06-01T07:00:00Z',
        plannedDistanceMeter: 5000,
        plannedDurationSecond: 1800,
        plannedElevationGainMeter: 30,
        targetAverageSpeedMeterPerSecond: 2.8,
        targetPowerWatt: null,
      }),
    );
    expect(seed.status()).toBe(201);
    const { id: seedId } = await expectJson<{ id: string }>(seed);
    expect(seedId).toMatch(UUID_PATTERN);

    const dryRunA = await session.api.dryRunImport(plan.id, {
      startDate: '2026-06-02T09:00:00Z',
      selectedWorkoutsPerWeek: 2,
      title: 'Dry Run Variant A',
      description: 'Lower density import',
    });
    expect(dryRunA.status()).toBe(200);
    const previewA = await expectJson<CalendarResponse>(dryRunA);

    expect(previewA.activities).toHaveLength(0);
    expect(previewA.planned_activities.length).toBeGreaterThanOrEqual(3);
    expect(previewA.planned_activities[0]).toMatchObject({
      id: seedId,
      title: 'Seed Planned Session',
      start_time: '2026-06-01T07:00:00Z',
    });
    expect(previewA.planned_activities.map((activity) => activity.id)).toEqual(
      expect.arrayContaining(['dry-run-1', 'dry-run-2']),
    );
    expect(
      previewA.planned_activities.some((activity) => activity.is_dry_run === true),
    ).toBe(true);
    expect(previewA.planned_activities.map((activity) => activity.title)).toEqual(
      expect.arrayContaining([firstWorkoutTitle, secondWorkoutTitle]),
    );
    expect(previewA.planned_activities.map((activity) => activity.plan_sequence_index)).toEqual(
      expect.arrayContaining([1, 2]),
    );

    const firstImportStart = previewA.planned_activities[1].start_time;
    const secondImportStart = previewA.planned_activities[2].start_time;

    const dryRunB = await session.api.dryRunImport(plan.id, {
      startDate: '2026-06-09T09:00:00Z',
      selectedWorkoutsPerWeek: 4,
      title: 'Dry Run Variant B',
      description: 'Higher density import',
    });
    expect(dryRunB.status()).toBe(200);
    const previewB = await expectJson<CalendarResponse>(dryRunB);

    expect(previewB.activities).toHaveLength(0);
    expect(previewB.planned_activities.length).toBeGreaterThanOrEqual(5);
    expect(previewB.planned_activities[0]).toMatchObject({
      id: seedId,
      title: 'Seed Planned Session',
    });
    expect(previewB.planned_activities.map((activity) => activity.id)).toEqual(
      expect.arrayContaining(['dry-run-1', 'dry-run-2']),
    );
    expect(
      previewB.planned_activities.some((activity) => activity.is_dry_run === true),
    ).toBe(true);
    expect(previewB.planned_activities[1].start_time).not.toBe(firstImportStart);
    expect(previewB.planned_activities[2].start_time).not.toBe(secondImportStart);
    expect(previewB.planned_activities.map((activity) => activity.plan_sequence_index)).toEqual(
      expect.arrayContaining([1, 4]),
    );
  });
});
