import { test, expect, type TestSession } from '../../lib/fixtures';
import {
  expectActivityShape,
  expectJson,
  expectStreamResponse,
  UUID_PATTERN,
} from '../../lib/assertions';
import { readTestFile } from '../../lib/test-data';
import type {
  ActivityResult,
  GetActivitiesResponse,
  StreamsResponse,
  UploadResponse,
} from '../../lib/types';

const streamTypes = ['time', 'distance', 'elevation', 'speed'];

async function getActivity(session: TestSession, id: string): Promise<ActivityResult> {
  const body = await expectJson<GetActivitiesResponse>(await session.api.listActivities());
  const activity = body.activities.find((item) => item.id === id);
  expect(activity, `activity ${id} should be listed`).toBeDefined();
  return activity as ActivityResult;
}

test.describe('activity file upload', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    const response = await anonymousApi.uploadActivity(
      readTestFile('mcfarland_bike_ride.gpx'),
    );
    expect(response.status()).toBe(401);
  });

  test('uploads a GPX file with embedded elevation and streams', async ({ session }) => {
    test.slow();

    const upload = await session.api.uploadActivity(
      readTestFile('mcfarland_bike_ride.gpx'),
      { enrich: false },
    );
    expect(upload.status()).toBe(201);
    const { id } = await expectJson<UploadResponse>(upload);
    expect(id).toMatch(UUID_PATTERN);

    const activity = await getActivity(session, id);
    expectActivityShape(activity);
    expect(activity).toMatchObject({ type: 'road_biking', title: 'Bike ride to McFarland' });
    expect(activity.description).toBe('');

    expect(activity.stats.elevation_gain_m).toBeGreaterThan(90);
    expect(activity.stats.elevation_gain_m).toBeLessThan(120);
    expect(activity.stats.elevation_loss_m).toBeGreaterThan(70);
    expect(activity.stats.elevation_loss_m).toBeLessThan(130);
    expect(activity.stats.max_height_m).toBeGreaterThan(290);
    expect(activity.stats.max_height_m).toBeLessThan(315);
    expect(activity.stats.min_height_m).toBeGreaterThan(270);
    expect(activity.stats.min_height_m).toBeLessThan(285);
    expect(activity.stats.distance_m).toBeGreaterThan(10950);
    expect(activity.stats.distance_m).toBeLessThan(11200);
    expect(activity.stats.elapsed_seconds).toBeGreaterThan(2520);
    expect(activity.stats.elapsed_seconds).toBeLessThan(2570);
    expect(activity.stats.avg_speed_ms).toBeGreaterThan(4.0);
    expect(activity.stats.avg_speed_ms).toBeLessThan(5.5);
    expect(activity.stats.derived.speed_kmh).toBeGreaterThan(14);
    expect(activity.stats.derived.speed_kmh).toBeLessThan(20);
    expect(activity.stats.derived.distance_km).toBeGreaterThan(10.8);
    expect(activity.stats.derived.distance_km).toBeLessThan(11.4);

    const streams = await session.api.getStreams(id, {
      lod: 'medium',
      types: streamTypes,
    });
    expect(streams.status()).toBe(200);
    expectStreamResponse(await expectJson<StreamsResponse>(streams), {
      activityId: id,
      lod: 'medium',
      types: streamTypes,
    });
  });

  test('uploads a GPX file without elevation, enriches it, and applies a title override', async ({
    session,
  }) => {
    test.slow();

    const upload = await session.api.uploadActivity(
      readTestFile('campus_loop_220pts_var_time.gpx'),
      { enrich: true, title: 'My Campus Run' },
    );
    expect(upload.status()).toBe(201);
    const { id } = await expectJson<UploadResponse>(upload);
    expect(id).toMatch(UUID_PATTERN);

    const activity = await getActivity(session, id);
    expectActivityShape(activity);
    expect(activity).toMatchObject({ type: 'running', title: 'My Campus Run' });
    expect(activity.stats.elevation_gain_m).toBeGreaterThan(0);
    expect(activity.stats.elevation_loss_m).toBeGreaterThan(0);
    expect(activity.stats.max_height_m).toBeGreaterThan(0);
    expect(activity.stats.distance_m).toBeGreaterThan(2200);
    expect(activity.stats.distance_m).toBeLessThan(2400);
    expect(activity.stats.elapsed_seconds).toBeGreaterThan(400);
    expect(activity.stats.derived.pace_s_per_km).toBeGreaterThan(0);
    expect(activity.stats.derived.distance_km).toBeGreaterThan(2);

    const streams = await session.api.getStreams(id, {
      lod: 'medium',
      types: streamTypes,
    });
    expect(streams.status()).toBe(200);
    expectStreamResponse(await expectJson<StreamsResponse>(streams), {
      activityId: id,
      lod: 'medium',
      types: streamTypes,
    });
  });

  test('rejects an unsupported file extension', async ({ session }) => {
    const response = await session.api.uploadActivity(
      readTestFile('campus_loop_220pts.json'),
    );
    expect(response.status()).toBe(400);
  });

  test('rejects a request without a file field', async ({ session }) => {
    const response = await session.api.uploadActivityWithoutFile({ enrich: false });
    expect(response.status()).toBe(400);
  });

  test('uploads a FIT file with embedded elevation and streams', async ({ session }) => {
    test.slow();

    const upload = await session.api.uploadActivity(readTestFile('Morning_Run.fit'), {
      enrich: false,
    });
    expect(upload.status()).toBe(201);
    const { id } = await expectJson<UploadResponse>(upload);
    expect(id).toMatch(UUID_PATTERN);

    const activity = await getActivity(session, id);
    expectActivityShape(activity);
    expect(activity.type).toBe('running');
    expect(activity.description).toBe('');

    expect(activity.stats.elevation_gain_m).toBeGreaterThan(90);
    expect(activity.stats.elevation_gain_m).toBeLessThan(600);
    expect(activity.stats.elevation_loss_m).toBeGreaterThan(70);
    expect(activity.stats.elevation_loss_m).toBeLessThan(650);
    expect(activity.stats.distance_m).toBeGreaterThan(6950);
    expect(activity.stats.distance_m).toBeLessThan(7400);
    expect(activity.stats.elapsed_seconds).toBeGreaterThan(2000);
    expect(activity.stats.elapsed_seconds).toBeLessThan(2200);

    const streams = await session.api.getStreams(id, {
      lod: 'medium',
      types: streamTypes,
    });
    expect(streams.status()).toBe(200);
    expectStreamResponse(await expectJson<StreamsResponse>(streams), {
      activityId: id,
      lod: 'medium',
      types: streamTypes,
    });
  });
});
