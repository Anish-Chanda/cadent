import { createPlannedActivityPayload } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectJson, UUID_PATTERN } from '../../lib/assertions';
import { readTestFile } from '../../lib/test-data';
import type { CalendarResponse, UploadResponse } from '../../lib/types';

test.describe('activity calendar', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    const response = await anonymousApi.getCalendar('2000-01-01', '2100-01-01');
    expect(response.status()).toBe(401);
  });

  test('returns uploaded activities and planned activities in the range', async ({ session }) => {
    test.slow();

    const gpxUpload = await session.api.uploadActivity(
      readTestFile('mcfarland_bike_ride.gpx'),
      { enrich: false },
    );
    expect(gpxUpload.status()).toBe(201);
    const { id: gpxId } = await expectJson<UploadResponse>(gpxUpload);
    expect(gpxId).toMatch(UUID_PATTERN);

    const fitUpload = await session.api.uploadActivity(readTestFile('Morning_Run.fit'), {
      enrich: false,
      title: 'Calendar Morning Run',
    });
    expect(fitUpload.status()).toBe(201);
    const { id: fitId } = await expectJson<UploadResponse>(fitUpload);
    expect(fitId).toMatch(UUID_PATTERN);

    const ridePayload = createPlannedActivityPayload({
      title: 'Planned Tempo Ride',
      description: 'Steady tempo effort',
      activityType: 'road_biking',
      startTime: '2026-03-10T07:30:00Z',
      plannedDistanceMeter: 25000,
      plannedDurationSecond: 3600,
      plannedElevationGainMeter: 120,
      targetAverageSpeedMeterPerSecond: 6.94,
      targetPowerWatt: 185,
    });
    const ride = await session.api.createPlannedActivity(ridePayload);
    expect(ride.status()).toBe(201);
    const { id: rideId } = await expectJson<{ id: string }>(ride);
    expect(rideId).toMatch(UUID_PATTERN);

    const runPayload = createPlannedActivityPayload({
      title: 'Planned Progression Run',
      description: 'Easy to moderate progression',
      activityType: 'running',
      startTime: '2026-03-12T18:15:00Z',
      plannedDistanceMeter: 10000,
      plannedDurationSecond: 3000,
      plannedElevationGainMeter: 80,
      targetAverageSpeedMeterPerSecond: 3.5,
      targetPowerWatt: null,
    });
    const run = await session.api.createPlannedActivity(runPayload);
    expect(run.status()).toBe(201);
    const { id: runId } = await expectJson<{ id: string }>(run);
    expect(runId).toMatch(UUID_PATTERN);

    const response = await session.api.getCalendar('2000-01-01', '2100-01-01');
    expect(response.status()).toBe(200);
    const calendar = await expectJson<CalendarResponse>(response);

    expect(calendar.activities).toHaveLength(2);
    expect(calendar.activities.map((activity) => activity.id)).toEqual(
      expect.arrayContaining([gpxId, fitId]),
    );
    expect(calendar.activities.map((activity) => activity.title)).toEqual(
      expect.arrayContaining(['Bike ride to McFarland', 'Calendar Morning Run']),
    );
    expect(calendar.activities.map((activity) => activity.type)).toEqual(
      expect.arrayContaining(['road_biking', 'running']),
    );
    for (const activity of calendar.activities) {
      expect(activity.stats.distance_m).toBeGreaterThan(0);
      expect(activity.stats.elapsed_seconds).toBeGreaterThan(0);
    }

    expect(calendar.planned_activities).toHaveLength(2);
    expect(calendar.planned_activities.map((activity) => activity.id)).toEqual(
      expect.arrayContaining([rideId, runId]),
    );
    expect(calendar.planned_activities.map((activity) => activity.title)).toEqual(
      expect.arrayContaining(['Planned Tempo Ride', 'Planned Progression Run']),
    );

    const plannedRide = calendar.planned_activities.find((activity) => activity.id === rideId);
    expect(plannedRide).toMatchObject({
      type: 'road_biking',
      planned_distance_m: 25000,
      planned_duration_s: 3600,
      planned_elevation_gain_m: 120,
      target_avg_speed_mps: 6.94,
      target_power_watt: 185,
    });
    expect(plannedRide?.start_time).toContain('2026-03-10T07:30:00');

    const plannedRun = calendar.planned_activities.find((activity) => activity.id === runId);
    expect(plannedRun).toMatchObject({
      type: 'running',
      planned_distance_m: 10000,
      planned_duration_s: 3000,
      planned_elevation_gain_m: 80,
      target_avg_speed_mps: 3.5,
    });
    expect(plannedRun?.start_time).toContain('2026-03-12T18:15:00');
  });

  test('returns empty collections for a range with no data', async ({ session }) => {
    const response = await session.api.getCalendar('2013-06-12', '2013-06-12');
    expect(response.status()).toBe(200);

    const calendar = await expectJson<CalendarResponse>(response);
    expect(calendar.activities).toHaveLength(0);
    expect(calendar.planned_activities).toHaveLength(0);
  });

  const invalidRanges = [
    { label: 'invalid start date', start: '12-06-2013', end: '2013-06-12' },
    { label: 'invalid end date', start: '2013-06-12', end: '12-06-2013' },
    { label: 'missing start date', start: '', end: '2013-06-12' },
    { label: 'missing end date', start: '2013-06-12', end: '' },
    { label: 'end before start', start: '2013-06-12', end: '2012-06-12' },
  ];

  for (const range of invalidRanges) {
    test(`rejects ${range.label}`, async ({ session }) => {
      const response = await session.api.getCalendar(range.start, range.end);
      expect(response.status()).toBe(400);
    });
  }
});
