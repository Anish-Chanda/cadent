import { createPlannedActivityPayload } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectJson, UUID_PATTERN } from '../../lib/assertions';

test.describe('planned activity creation', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    const response = await anonymousApi.createPlannedActivity(
      createPlannedActivityPayload(),
    );
    expect(response.status()).toBe(401);
  });

  test('creates a planned activity with all fields', async ({ session }) => {
    const response = await session.api.createPlannedActivity(
      createPlannedActivityPayload({
        title: 'Riverside Tempo Ride',
        description:
          'Maintain steady power on the flat sections. Focus on aerobic capacity.',
        activityType: 'road_biking',
        startTime: '2026-03-10T07:30:00Z',
        plannedDistanceMeter: 25000,
        plannedDurationSecond: 3600,
        plannedElevationGainMeter: 120,
        targetAverageSpeedMeterPerSecond: 6.94,
        targetPowerWatt: 185,
      }),
    );

    expect(response.status()).toBe(201);
    const body = await expectJson<{ id: string }>(response);
    expect(body.id).toMatch(UUID_PATTERN);
  });
});
