import type { APIRequestContext, APIResponse } from '@playwright/test';
import { expect } from '@playwright/test';
import type { ActivityResult, StreamsResponse } from './types';

export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export async function expectJson<T>(response: APIResponse): Promise<T> {
  expect(response.headers()['content-type']).toContain('application/json');
  return response.json() as Promise<T>;
}

export async function expectTextError(
  response: APIResponse,
  status: number,
  message: string,
): Promise<void> {
  expect(response.status()).toBe(status);
  expect(await response.text()).toContain(message);
}

export async function expectJsonError(
  response: APIResponse,
  status: number,
  message: string,
): Promise<void> {
  expect(response.status()).toBe(status);
  const body = (await response.json()) as { error: string };
  expect(body.error).toContain(message);
}

export async function expectJwtCookie(context: APIRequestContext): Promise<void> {
  const state = await context.storageState();
  const jwt = state.cookies.find((cookie) => cookie.name === 'JWT');

  expect(jwt, 'JWT cookie should be present').toBeDefined();
  expect(jwt?.httpOnly).toBe(true);
  expect(jwt?.path).toBe('/');
}

export function expectActivityShape(activity: ActivityResult): void {
  expect(activity.id).toMatch(UUID_PATTERN);
  expect(activity).toMatchObject({
    title: expect.any(String),
    description: expect.any(String),
    type: expect.stringMatching(/^(running|road_biking)$/),
    start_time: expect.any(String),
    created_at: expect.any(String),
    updated_at: expect.any(String),
    stats: {
      distance_m: expect.any(Number),
      elapsed_seconds: expect.any(Number),
      avg_speed_ms: expect.any(Number),
      elevation_gain_m: expect.any(Number),
      elevation_loss_m: expect.any(Number),
      max_height_m: expect.any(Number),
      min_height_m: expect.any(Number),
      derived: {
        distance_km: expect.any(Number),
        distance_miles: expect.any(Number),
      },
    },
    bbox: {
      min_lat: expect.any(Number),
      max_lat: expect.any(Number),
      min_lon: expect.any(Number),
      max_lon: expect.any(Number),
    },
    start: {
      lat: expect.any(Number),
      lon: expect.any(Number),
    },
    polyline: expect.any(String),
    processing_ver: expect.any(Number),
  });
}

export function expectStreamResponse(
  body: StreamsResponse,
  options: {
    activityId: string;
    lod: string;
    types: string[];
  },
): void {
  expect(body.activity_id).toBe(options.activityId);
  expect(body.lod).toBe(options.lod);
  expect(body.index_by).toBe('distance');
  expect(body.num_points).toBeGreaterThan(0);
  expect(body.original_num_points).toBeGreaterThan(0);
  expect(body.streams).toHaveLength(options.types.length);
  expect(body.streams.map((stream) => stream.type)).toEqual(
    expect.arrayContaining(options.types),
  );

  for (const stream of body.streams) {
    expect(stream.values.length).toBeGreaterThan(0);
  }
}
