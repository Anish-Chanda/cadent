import { createActivityPayload, createSamples } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import {
  expectActivityShape,
  expectJson,
  expectStreamResponse,
} from '../../lib/assertions';
import type {
  ActivityResult,
  GetActivitiesResponse,
  StreamsResponse,
} from '../../lib/types';

test.describe('activity retrieval', () => {
  test('requires authentication', async ({ anonymousApi }) => {
    expect((await anonymousApi.listActivities()).status()).toBe(401);
  });

  test('returns an empty collection for a new user', async ({ session }) => {
    const response = await session.api.listActivities();
    expect(response.status()).toBe(200);

    const body = await expectJson<GetActivitiesResponse>(response);
    expect(body.activities).toHaveLength(0);
  });

  test('returns activities and streams for the owner', async ({ session }) => {
    const create = await session.api.createActivity(
      createActivityPayload({
        title: 'Morning Run',
        description: 'Quick jog around campus',
        samples: [
          ...createSamples(),
          { t: 1771092020000, lat: 42.02908, lon: -93.6499 },
        ],
      }),
    );
    expect(create.status()).toBe(201);
    const created = await expectJson<ActivityResult>(create);
    expect(created.type).toBe('running');

    const list = await session.api.listActivities();
    expect(list.status()).toBe(200);
    const activities = await expectJson<GetActivitiesResponse>(list);
    expect(activities.activities.length).toBeGreaterThanOrEqual(1);
    expectActivityShape(activities.activities[0]);

    const streams = await session.api.getStreams(created.id, {
      lod: 'medium',
      types: ['time', 'distance', 'elevation'],
    });
    expect(streams.status()).toBe(200);
    const streamBody = await expectJson<StreamsResponse>(streams);
    expectStreamResponse(streamBody, {
      activityId: created.id,
      lod: 'medium',
      types: ['time', 'distance', 'elevation'],
    });
    expect(streamBody.streams.map((stream) => stream.type)).toEqual(
      expect.arrayContaining(['time', 'distance', 'elevation']),
    );
    for (const stream of streamBody.streams) {
      expect(stream.values).toHaveLength(3);
    }
  });

  test('rejects invalid stream requests', async ({ session }) => {
    const create = await session.api.createActivity(createActivityPayload());
    const { id } = await expectJson<ActivityResult>(create);

    expect(
      (
        await session.api.getStreams('00000000-0000-0000-0000-000000000000', {
          lod: 'medium',
          types: ['time'],
        })
      ).status(),
    ).toBe(404);
    expect(
      (
        await session.api.getStreams('not-a-valid-uuid', {
          lod: 'medium',
          types: ['time'],
        })
      ).status(),
    ).toBe(400);
    expect((await session.api.getStreams(id, { types: ['time'] })).status()).toBe(400);
    expect((await session.api.getStreams(id, { lod: 'medium' })).status()).toBe(400);
    expect(
      (await session.api.getStreams(id, { lod: 'ultra', types: ['time'] })).status(),
    ).toBe(400);
    expect(
      (await session.api.getStreams(id, { lod: 'medium', types: ['heartrate'] })).status(),
    ).toBe(400);
    expect(
      (await session.api.getStreams(id, { lod: 'full', types: ['time'] })).status(),
    ).toBe(501);
  });

  test('returns low LOD streams', async ({ session }) => {
    const create = await session.api.createActivity(createActivityPayload());
    const { id } = await expectJson<ActivityResult>(create);

    const response = await session.api.getStreams(id, {
      lod: 'low',
      types: ['time', 'distance'],
    });
    expect(response.status()).toBe(200);
    expectStreamResponse(await expectJson<StreamsResponse>(response), {
      activityId: id,
      lod: 'low',
      types: ['time', 'distance'],
    });
  });

  test('isolates activities and streams between users', async ({ createSession }) => {
    const userOne = await createSession();
    const userTwo = await createSession();

    const create = await userOne.api.createActivity(
      createActivityPayload({ title: 'User 1 Activity' }),
    );
    const userOneActivity = await expectJson<ActivityResult>(create);

    const userTwoList = await expectJson<GetActivitiesResponse>(
      await userTwo.api.listActivities(),
    );
    expect(userTwoList.activities).toHaveLength(0);
    expect(
      (
        await userTwo.api.getStreams(userOneActivity.id, {
          lod: 'medium',
          types: ['time'],
        })
      ).status(),
    ).toBe(404);

    const userTwoCreate = await userTwo.api.createActivity(
      createActivityPayload({ title: 'User 2 Activity' }),
    );
    const userTwoActivity = await expectJson<ActivityResult>(userTwoCreate);

    const userTwoOwnList = await expectJson<GetActivitiesResponse>(
      await userTwo.api.listActivities(),
    );
    expect(userTwoOwnList.activities).toHaveLength(1);
    expect(userTwoOwnList.activities[0].id).toBe(userTwoActivity.id);

    expect(
      (
        await userTwo.api.getStreams(userTwoActivity.id, {
          lod: 'medium',
          types: ['time', 'distance'],
        })
      ).status(),
    ).toBe(200);

    expect(
      (
        await userOne.api.getStreams(userTwoActivity.id, {
          lod: 'medium',
          types: ['time'],
        })
      ).status(),
    ).toBe(404);
  });
});
