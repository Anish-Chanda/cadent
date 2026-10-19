import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import type {
  CreateActivityRequest,
  CreatePlannedActivityRequest,
  Sample,
} from './types';
import { testDataPath } from './test-data';

export interface TestUser {
  id?: string;
  email: string;
  password: string;
  name: string;
}

export function createUserData(overrides: Partial<TestUser> = {}): TestUser {
  return {
    email: `e2e-${randomUUID()}@test.com`,
    password: 'Password123!',
    name: 'E2E Test User',
    ...overrides,
  };
}

export function createActivityPayload(
  overrides: Partial<CreateActivityRequest> = {},
): CreateActivityRequest {
  return {
    client_activity_id: randomUUID(),
    activity_type: 'running',
    title: 'E2E Minimal Activity',
    description: 'Minimal two-sample activity created by Playwright',
    samples: createSamples(),
    ...overrides,
  };
}

export function createSamples(): Sample[] {
  return [
    { t: 1771092000000, lat: 42.02888, lon: -93.64974 },
    { t: 1771092010000, lat: 42.02898, lon: -93.6498 },
  ];
}

export function loadActivityFixture(
  name: 'campus_loop_220pts.json' | 'afternoon_run.json',
  overrides: Partial<CreateActivityRequest> = {},
): CreateActivityRequest {
  const data = JSON.parse(
    fs.readFileSync(testDataPath(name), 'utf8'),
  ) as CreateActivityRequest;

  return {
    ...data,
    client_activity_id: randomUUID(),
    ...overrides,
  };
}

export function createPlannedActivityPayload(
  overrides: Partial<CreatePlannedActivityRequest> = {},
): CreatePlannedActivityRequest {
  return {
    title: 'E2E Planned Ride',
    description: 'Steady aerobic ride created by Playwright',
    activityType: 'road_biking',
    startTime: '2026-04-15T06:00:00Z',
    plannedDistanceMeter: 30000,
    plannedDurationSecond: 5400,
    plannedElevationGainMeter: 500,
    targetAverageSpeedMeterPerSecond: 5.56,
    targetPowerWatt: 200,
    ...overrides,
  };
}
