import type { APIRequestContext, APIResponse } from '@playwright/test';
import type {
  CreateActivityRequest,
  CreatePlannedActivityRequest,
  ImportDryRunRequest,
  SignupRequest,
} from './types';

export interface UploadFile {
  name: string;
  buffer: Buffer;
}

export interface UploadOptions {
  enrich?: boolean;
  title?: string;
  description?: string;
}

export interface StreamOptions {
  lod?: string;
  types?: string[];
}

export class CadentApi {
  constructor(private readonly context: APIRequestContext) {}

  signup(body: SignupRequest): Promise<APIResponse> {
    return this.context.post('/api/signup', { data: body });
  }

  login(user: string, passwd: string): Promise<APIResponse> {
    return this.context.post('/api/auth/local/login', { form: { user, passwd } });
  }

  logout(): Promise<APIResponse> {
    return this.context.get('/api/auth/logout');
  }

  getUser(): Promise<APIResponse> {
    return this.context.get('/api/v1/user');
  }

  updateUser(body: Record<string, unknown>): Promise<APIResponse> {
    return this.context.patch('/api/v1/user', { data: body });
  }

  updateUserRaw(body: string): Promise<APIResponse> {
    return this.context.patch('/api/v1/user', {
      data: body,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  createActivity(body: CreateActivityRequest): Promise<APIResponse> {
    return this.context.post('/api/v1/activities', { data: body });
  }

  createRawActivity(body: string): Promise<APIResponse> {
    return this.context.post('/api/v1/activities', {
      data: body,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  listActivities(): Promise<APIResponse> {
    return this.context.get('/api/v1/activities');
  }

  uploadActivity(file: UploadFile, options: UploadOptions = {}): Promise<APIResponse> {
    const multipart: Record<string, string | { name: string; mimeType: string; buffer: Buffer }> = {
      file: {
        name: file.name,
        mimeType: 'application/octet-stream',
        buffer: file.buffer,
      },
    };

    if (options.enrich !== undefined) {
      multipart.enrich = String(options.enrich);
    }
    if (options.title !== undefined) {
      multipart.title = options.title;
    }
    if (options.description !== undefined) {
      multipart.description = options.description;
    }

    return this.context.post('/api/v1/activities/upload', { multipart });
  }

  uploadActivityWithoutFile(options: UploadOptions = {}): Promise<APIResponse> {
    const multipart: Record<string, string> = {};

    if (options.enrich !== undefined) {
      multipart.enrich = String(options.enrich);
    }
    if (options.title !== undefined) {
      multipart.title = options.title;
    }
    if (options.description !== undefined) {
      multipart.description = options.description;
    }

    return this.context.post('/api/v1/activities/upload', { multipart });
  }

  getStreams(activityId: string, options: StreamOptions = {}): Promise<APIResponse> {
    const params: Record<string, string> = {};
    if (options.lod !== undefined) {
      params.lod = options.lod;
    }
    if (options.types !== undefined) {
      params.type = options.types.join(',');
    }

    return this.context.get(`/api/v1/activities/${activityId}/streams`, { params });
  }

  createPlannedActivity(body: CreatePlannedActivityRequest): Promise<APIResponse> {
    return this.context.post('/api/v1/activities/plan', { data: body });
  }

  updatePlannedActivity(body: Record<string, unknown>): Promise<APIResponse> {
    return this.context.patch('/api/v1/activities/plan', { data: body });
  }

  deletePlannedActivity(id: string): Promise<APIResponse> {
    return this.context.delete('/api/v1/activities/plan', { data: { id } });
  }

  getCalendar(startDate: string, endDate: string): Promise<APIResponse> {
    return this.context.get('/api/v1/calendar', { params: { startDate, endDate } });
  }

  listTrainingPlans(params: { q?: string; activity_type?: string } = {}): Promise<APIResponse> {
    return this.context.get('/api/v1/training-plans', { params });
  }

  getTrainingPlanWorkouts(planId: string): Promise<APIResponse> {
    return this.context.get(`/api/v1/training-plans/${planId}/workouts`);
  }

  dryRunImport(planId: string, body: ImportDryRunRequest): Promise<APIResponse> {
    return this.context.post(`/api/v1/training-plans/${planId}/import/dry-run`, { data: body });
  }
}
