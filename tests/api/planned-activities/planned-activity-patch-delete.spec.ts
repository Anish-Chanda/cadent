import { createPlannedActivityPayload } from '../../lib/factories';
import { test, expect, type TestSession } from '../../lib/fixtures';
import { expectJson, expectJsonError, UUID_PATTERN } from '../../lib/assertions';
import type { CalendarResponse } from '../../lib/types';

const APRIL_START = '2026-04-01';
const APRIL_END = '2026-04-30';

async function getPlannedActivities(
  session: TestSession,
): Promise<CalendarResponse['planned_activities']> {
  const response = await session.api.getCalendar(APRIL_START, APRIL_END);
  expect(response.status()).toBe(200);
  return (await expectJson<CalendarResponse>(response)).planned_activities;
}

test.describe('planned activity update and delete', () => {
  test('updates every field and deletes the activity', async ({ session }) => {
    const create = await session.api.createPlannedActivity(
      createPlannedActivityPayload({
        title: 'Morning Hill Climb',
        description: 'Steady climb with cadence focus.',
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
    expect(id).toMatch(UUID_PATTERN);

    let planned = await getPlannedActivities(session);
    expect(planned).toHaveLength(1);
    expect(planned[0]).toMatchObject({
      id,
      title: 'Morning Hill Climb',
      description: 'Steady climb with cadence focus.',
      type: 'road_biking',
      planned_distance_m: 30000,
      planned_duration_s: 5400,
      planned_elevation_gain_m: 500,
      target_avg_speed_mps: 5.56,
      target_power_watt: 200,
    });

    const titleUpdate = await session.api.updatePlannedActivity({
      id,
      title: 'Evening Hill Climb',
      description: 'Updated to evening session with power intervals.',
    });
    expect(titleUpdate.status()).toBe(200);
    expect(await expectJson<{ message: string }>(titleUpdate)).toEqual({
      message: 'Planned activity updated',
    });

    planned = await getPlannedActivities(session);
    expect(planned[0]).toMatchObject({
      title: 'Evening Hill Climb',
      description: 'Updated to evening session with power intervals.',
      type: 'road_biking',
      planned_distance_m: 30000,
      planned_duration_s: 5400,
    });

    const metricsUpdate = await session.api.updatePlannedActivity({
      id,
      plannedDistanceMeter: 40000,
      plannedDurationSecond: 7200,
      plannedElevationGainMeter: 750,
      targetAverageSpeedMeterPerSecond: 5.0,
      targetPowerWatt: 220,
    });
    expect(metricsUpdate.status()).toBe(200);

    planned = await getPlannedActivities(session);
    expect(planned[0]).toMatchObject({
      planned_distance_m: 40000,
      planned_duration_s: 7200,
      planned_elevation_gain_m: 750,
      target_avg_speed_mps: 5.0,
      target_power_watt: 220,
    });

    const scheduleUpdate = await session.api.updatePlannedActivity({
      id,
      activityType: 'running',
      startTime: '2026-04-20T08:00:00Z',
    });
    expect(scheduleUpdate.status()).toBe(200);

    planned = await getPlannedActivities(session);
    expect(planned[0].type).toBe('running');
    expect(planned[0].start_time).toContain('2026-04-20');

    const remove = await session.api.deletePlannedActivity(id);
    expect(remove.status()).toBe(204);
    expect(await getPlannedActivities(session)).toHaveLength(0);

    await expectJsonError(
      await session.api.deletePlannedActivity(id),
      404,
      'Planned activity not found',
    );
  });

  test('rejects invalid updates', async ({ session }) => {
    const create = await session.api.createPlannedActivity(createPlannedActivityPayload());
    const { id } = await expectJson<{ id: string }>(create);

    await expectJsonError(
      await session.api.updatePlannedActivity({ title: 'No ID Provided' }),
      400,
      'Activity ID is required',
    );
    await expectJsonError(
      await session.api.updatePlannedActivity({ id }),
      400,
      'No updates provided',
    );
    await expectJsonError(
      await session.api.updatePlannedActivity({ id, title: '   ' }),
      400,
      'Title cannot be empty',
    );
    expect(
      (
        await session.api.updatePlannedActivity({
          id,
          activityType: 'swimming',
        })
      ).status(),
    ).toBe(400);
    await expectJsonError(
      await session.api.updatePlannedActivity({
        id: '00000000-0000-0000-0000-000000000000',
        title: 'Ghost Activity',
      }),
      404,
      'Planned activity not found',
    );
  });

  test('returns 404 when deleting a non-existent activity', async ({ session }) => {
    await expectJsonError(
      await session.api.deletePlannedActivity('00000000-0000-0000-0000-000000000000'),
      404,
      'Planned activity not found',
    );
  });
});
