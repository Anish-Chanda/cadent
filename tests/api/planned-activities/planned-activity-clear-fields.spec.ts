import { createPlannedActivityPayload } from '../../lib/factories';
import { test, expect, type TestSession } from '../../lib/fixtures';
import { expectJson, expectJsonError } from '../../lib/assertions';
import type { CalendarResponse, PlannedActivityResult } from '../../lib/types';

const APRIL_START = '2026-04-01';
const APRIL_END = '2026-04-30';

async function getPlannedActivity(session: TestSession): Promise<PlannedActivityResult> {
  const response = await session.api.getCalendar(APRIL_START, APRIL_END);
  expect(response.status()).toBe(200);
  const calendar = await expectJson<CalendarResponse>(response);
  expect(calendar.planned_activities).toHaveLength(1);
  return calendar.planned_activities[0];
}

test.describe('planned activity nullable field clearing', () => {
  test('clears nullable fields to null and then to empty/zero values', async ({ session }) => {
    const create = await session.api.createPlannedActivity(
      createPlannedActivityPayload({
        title: 'Full Detail Ride',
        description: 'A ride with every field filled in.',
        activityType: 'road_biking',
        startTime: '2026-04-15T06:00:00Z',
        plannedDistanceMeter: 30000,
        plannedDurationSecond: 5400,
        plannedElevationGainMeter: 500,
        targetAverageSpeedMeterPerSecond: 5.56,
        targetPowerWatt: 200,
      }),
    );
    expect(create.status()).toBe(201);
    const { id } = await expectJson<{ id: string }>(create);

    expect(await getPlannedActivity(session)).toMatchObject({
      description: 'A ride with every field filled in.',
      planned_distance_m: 30000,
      planned_duration_s: 5400,
      planned_elevation_gain_m: 500,
      target_avg_speed_mps: 5.56,
      target_power_watt: 200,
    });

    const clearDescription = await session.api.updatePlannedActivity({
      id,
      description: null,
    });
    expect(clearDescription.status()).toBe(200);
    expect(await expectJson<{ message: string }>(clearDescription)).toEqual({
      message: 'Planned activity updated',
    });
    expect((await getPlannedActivity(session)).description).toBe('');

    const clearNumbers = await session.api.updatePlannedActivity({
      id,
      plannedDistanceMeter: null,
      plannedDurationSecond: null,
      plannedElevationGainMeter: null,
      targetAverageSpeedMeterPerSecond: null,
      targetPowerWatt: null,
    });
    expect(clearNumbers.status()).toBe(200);

    expect(await getPlannedActivity(session)).toMatchObject({
      title: 'Full Detail Ride',
      type: 'road_biking',
      planned_distance_m: null,
      planned_duration_s: null,
      planned_elevation_gain_m: null,
      target_avg_speed_mps: null,
      target_power_watt: null,
    });
    expect((await getPlannedActivity(session)).start_time).toContain('2026-04-15');

    const repopulate = await session.api.updatePlannedActivity({
      id,
      description: 'Repopulated description for zero test.',
      plannedDistanceMeter: 20000,
      plannedDurationSecond: 3600,
      plannedElevationGainMeter: 300,
      targetAverageSpeedMeterPerSecond: 7.5,
      targetPowerWatt: 190,
    });
    expect(repopulate.status()).toBe(200);

    expect(await getPlannedActivity(session)).toMatchObject({
      description: 'Repopulated description for zero test.',
      planned_distance_m: 20000,
      planned_duration_s: 3600,
      planned_elevation_gain_m: 300,
      target_avg_speed_mps: 7.5,
      target_power_watt: 190,
    });

    const emptyDescription = await session.api.updatePlannedActivity({
      id,
      description: '',
    });
    expect(emptyDescription.status()).toBe(200);
    expect((await getPlannedActivity(session)).description).toBe('');

    const zeroNumbers = await session.api.updatePlannedActivity({
      id,
      plannedDistanceMeter: 0,
      plannedDurationSecond: 0,
      plannedElevationGainMeter: 0,
      targetAverageSpeedMeterPerSecond: 0,
      targetPowerWatt: 0,
    });
    expect(zeroNumbers.status()).toBe(200);

    expect(await getPlannedActivity(session)).toMatchObject({
      title: 'Full Detail Ride',
      type: 'road_biking',
      planned_distance_m: 0,
      planned_duration_s: 0,
      planned_elevation_gain_m: 0,
      target_avg_speed_mps: 0,
      target_power_watt: 0,
    });
    expect((await getPlannedActivity(session)).start_time).toContain('2026-04-15');

    await expectJsonError(
      await session.api.updatePlannedActivity({ id, title: null }),
      400,
      'Title cannot be null',
    );
    await expectJsonError(
      await session.api.updatePlannedActivity({ id, activityType: null }),
      400,
      'Activity type cannot be null',
    );
    await expectJsonError(
      await session.api.updatePlannedActivity({ id, startTime: null }),
      400,
      'Start time cannot be null',
    );

    expect(await getPlannedActivity(session)).toMatchObject({
      title: 'Full Detail Ride',
      type: 'road_biking',
    });
  });
});
