import {
  createActivityPayload,
  createSamples,
  loadActivityFixture,
} from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectActivityShape, expectJson } from '../../lib/assertions';
import type { ActivityResult, CreateActivityRequest, Sample } from '../../lib/types';

test.describe('activity creation', () => {
  test('creates a campus loop activity with calculated metrics', async ({ session }) => {
    test.slow();

    const payload = loadActivityFixture('campus_loop_220pts.json');
    const response = await session.api.createActivity(payload);

    expect(response.status()).toBe(201);
    const activity = await expectJson<ActivityResult>(response);
    expectActivityShape(activity);
    expect(activity).toMatchObject({
      type: 'road_biking',
      title: 'Campus Loop',
      start: { lat: 42.02888, lon: -93.64974 },
    });
    expect(activity.description).toContain('Test activity');
    expect(activity.description).toContain('220 GPS points');

    expect(activity.stats.distance_m).toBeGreaterThan(2250);
    expect(activity.stats.distance_m).toBeLessThan(2300);
    expect(activity.stats.elapsed_seconds).toBe(414);
    expect(activity.stats.avg_speed_ms).toBeGreaterThan(5.4);
    expect(activity.stats.avg_speed_ms).toBeLessThan(5.6);
    expect(activity.stats.elevation_gain_m).toBeGreaterThan(15);
    expect(activity.stats.elevation_gain_m).toBeLessThan(25);
    expect(activity.stats.elevation_loss_m).toBeGreaterThan(15);
    expect(activity.stats.elevation_loss_m).toBeLessThan(25);
  });

  test('creates an afternoon run with calculated metrics', async ({ session }) => {
    test.slow();

    const payload = loadActivityFixture('afternoon_run.json');
    const response = await session.api.createActivity(payload);

    expect(response.status()).toBe(201);
    const activity = await expectJson<ActivityResult>(response);
    expectActivityShape(activity);
    expect(activity).toMatchObject({
      type: 'running',
      title: 'Afternoon Run',
      start: { lat: 42.019797, lon: -93.644527 },
    });
    expect(activity.description).toContain('Test running activity');

    expect(activity.stats.distance_m).toBeGreaterThan(8100);
    expect(activity.stats.distance_m).toBeLessThan(8200);
    expect(activity.stats.elapsed_seconds).toBe(2129);
    expect(activity.stats.avg_speed_ms).toBeGreaterThan(3.7);
    expect(activity.stats.avg_speed_ms).toBeLessThan(4.0);
    expect(activity.stats.elevation_gain_m).toBeGreaterThan(38);
    expect(activity.stats.elevation_gain_m).toBeLessThan(45);
    expect(activity.stats.elevation_loss_m).toBeGreaterThan(44);
    expect(activity.stats.elevation_loss_m).toBeLessThan(50);
  });

  test('rejects a duplicate client_activity_id', async ({ session }) => {
    test.slow();

    const payload = loadActivityFixture('campus_loop_220pts.json');
    expect((await session.api.createActivity(payload)).status()).toBe(201);
    expect((await session.api.createActivity(payload)).status()).toBe(409);
  });

  test('requires authentication', async ({ anonymousApi }) => {
    const response = await anonymousApi.createActivity(createActivityPayload());
    expect(response.status()).toBe(401);
  });

  test('rejects fewer than two samples', async ({ session }) => {
    const response = await session.api.createActivity(
      createActivityPayload({ samples: [createSamples()[0]] }),
    );
    expect(response.status()).toBe(400);
  });

  test('rejects an invalid activity type', async ({ session }) => {
    const response = await session.api.createActivity(
      createActivityPayload({ activity_type: 'skateboarding' as 'running' }),
    );
    expect(response.status()).toBe(400);
  });

  test('creates a minimal activity with description', async ({ session }) => {
    const response = await session.api.createActivity(
      createActivityPayload({
        title: 'Minimal Run',
        description: 'A minimal two-sample activity',
      }),
    );

    expect(response.status()).toBe(201);
    const activity = await expectJson<ActivityResult>(response);
    expect(activity).toMatchObject({
      type: 'running',
      title: 'Minimal Run',
      description: 'A minimal two-sample activity',
    });
    expect(activity.stats.distance_m).toBeGreaterThan(0);
    expect(activity.stats.elapsed_seconds).toBe(10);
  });

  const missingFields: Array<{
    label: string;
    build: () => Partial<CreateActivityRequest>;
  }> = [
    {
      label: 'client_activity_id',
      build: () => {
        const { client_activity_id, ...rest } = createActivityPayload();
        return rest;
      },
    },
    {
      label: 'activity_type',
      build: () => {
        const { activity_type, ...rest } = createActivityPayload();
        return rest;
      },
    },
    {
      label: 'samples',
      build: () => {
        const { samples, ...rest } = createActivityPayload();
        return rest;
      },
    },
  ];

  for (const { label, build } of missingFields) {
    test(`rejects a request missing ${label}`, async ({ session }) => {
      const response = await session.api.createActivity(
        build() as CreateActivityRequest,
      );
      expect(response.status()).toBe(400);
    });
  }

  test('rejects a sample missing its timestamp', async ({ session }) => {
    const samples = [
      { lat: 42.02888, lon: -93.64974 },
      { t: 1771092010000, lat: 42.0289, lon: -93.64976 },
    ] as Sample[];

    const response = await session.api.createActivity(
      createActivityPayload({ samples }),
    );
    expect(response.status()).toBe(400);
  });

  test('rejects a sample missing coordinates', async ({ session }) => {
    const samples = [
      { t: 1771092000000, lat: 42.02888 },
      { t: 1771092010000, lat: 42.0289, lon: -93.64976 },
    ] as Sample[];

    const response = await session.api.createActivity(
      createActivityPayload({ samples }),
    );
    expect(response.status()).toBe(400);
  });

  test('allows an empty title', async ({ session }) => {
    const response = await session.api.createActivity(
      createActivityPayload({ title: '' }),
    );

    expect(response.status()).toBe(201);
    expect((await expectJson<ActivityResult>(response)).title).toBe('');
  });

  test('rejects malformed JSON', async ({ session }) => {
    const response = await session.api.createRawActivity('{invalid json}');
    expect(response.status()).toBe(400);
  });
});
