import { createUserData } from '../../lib/factories';
import { test, expect } from '../../lib/fixtures';
import { expectJson, UUID_PATTERN } from '../../lib/assertions';
import type { SignupResponse } from '../../lib/types';

test.describe('signup flow', () => {
  test('creates a user successfully', async ({ anonymousApi }) => {
    const user = createUserData({ name: 'New User' });

    const response = await anonymousApi.signup({
      user: user.email,
      passwd: user.password,
      name: user.name,
    });

    expect(response.status()).toBe(201);
    const body = await expectJson<SignupResponse>(response);
    expect(body.success).toBe(true);
    expect(body.user_id).toMatch(UUID_PATTERN);
    expect(body.message).toBe('User created successfully');
  });

  const missingFields = [
    {
      label: 'email',
      body: { user: '', passwd: 'password123', name: 'No Email User' },
    },
    {
      label: 'password',
      body: { user: createUserData().email, passwd: '', name: 'No Password User' },
    },
    {
      label: 'name',
      body: { user: createUserData().email, passwd: 'password123', name: '' },
    },
    {
      label: 'whitespace-only name',
      body: { user: createUserData().email, passwd: 'password123', name: '     ' },
    },
  ];

  for (const { label, body } of missingFields) {
    test(`rejects missing ${label}`, async ({ anonymousApi }) => {
      const response = await anonymousApi.signup(body);

      expect(response.status()).toBe(400);
      const result = await expectJson<SignupResponse>(response);
      expect(result.success).toBe(false);
      if (label !== 'whitespace-only name') {
        expect(result.message).toBe('Email, password, and name are required');
      }
    });
  }

  test('rejects an invalid email format', async ({ anonymousApi }) => {
    const response = await anonymousApi.signup({
      user: 'notanemail',
      passwd: 'password123',
      name: 'Invalid Email User',
    });

    expect(response.status()).toBe(400);
    const body = await expectJson<SignupResponse>(response);
    expect(body.success).toBe(false);
    expect(body.message).toBe('Invalid email format');
  });

  test('accepts special characters in an email', async ({ anonymousApi }) => {
    const user = createUserData({ email: `special.email+tag-${createUserData().email}` });

    const response = await anonymousApi.signup({
      user: user.email,
      passwd: 'password123',
      name: 'Special Email User',
    });

    expect(response.status()).toBe(201);
    expect((await expectJson<SignupResponse>(response)).success).toBe(true);
  });

  test('rejects a password shorter than six characters', async ({ anonymousApi }) => {
    const response = await anonymousApi.signup({
      user: createUserData().email,
      passwd: '12345',
      name: 'Short Password User',
    });

    expect(response.status()).toBe(400);
    const body = await expectJson<SignupResponse>(response);
    expect(body.success).toBe(false);
    expect(body.message).toBe('Password must be at least 6 characters long');
  });

  test('accepts a six-character password', async ({ anonymousApi }) => {
    const response = await anonymousApi.signup({
      user: createUserData().email,
      passwd: '123456',
      name: 'Min Password User',
    });

    expect(response.status()).toBe(201);
    expect((await expectJson<SignupResponse>(response)).success).toBe(true);
  });

  test('accepts a password containing spaces', async ({ anonymousApi }) => {
    const response = await anonymousApi.signup({
      user: createUserData().email,
      passwd: 'my password has spaces',
      name: 'Space Password User',
    });

    expect(response.status()).toBe(201);
    expect((await expectJson<SignupResponse>(response)).success).toBe(true);
  });

  const acceptedNames = [
    'José María Müller 日本語',
    'Test User 🚀 🏃‍♂️',
    "<script>alert('xss')</script>",
    "'; DROP TABLE users; --",
    'ThisIsAVeryLongNameThatTestsTheMaximumLengthAllowedForUserNamesInTheSystemAbcdefghijklmnopqrstuvwxyzAbcdefghijklmnopqrstuvwxyz',
  ];

  for (const [index, name] of acceptedNames.entries()) {
    test(`accepts name variant ${index + 1}`, async ({ anonymousApi }) => {
      const response = await anonymousApi.signup({
        user: createUserData().email,
        passwd: 'password123',
        name,
      });

      expect(response.status()).toBe(201);
      expect((await expectJson<SignupResponse>(response)).success).toBe(true);
    });
  }

  test('rejects a duplicate email', async ({ anonymousApi }) => {
    const user = createUserData({ name: 'First User' });

    const first = await anonymousApi.signup({
      user: user.email,
      passwd: user.password,
      name: user.name,
    });
    expect(first.status()).toBe(201);

    const duplicate = await anonymousApi.signup({
      user: user.email,
      passwd: 'different_password',
      name: 'Second User',
    });

    expect(duplicate.status()).toBe(409);
    const body = await expectJson<SignupResponse>(duplicate);
    expect(body.success).toBe(false);
    expect(body.message).toBe('User with this email already exists');
  });

  test('treats email case-insensitively for duplicate detection', async ({ anonymousApi }) => {
    const user = createUserData({ email: `CaseTest-${createUserData().email}` });

    const first = await anonymousApi.signup({
      user: user.email,
      passwd: 'password123',
      name: 'Case Test User',
    });
    expect(first.status()).toBe(201);

    const duplicate = await anonymousApi.signup({
      user: user.email.toLowerCase(),
      passwd: 'password123',
      name: 'Duplicate Case User',
    });

    expect(duplicate.status()).toBe(409);
    expect((await expectJson<SignupResponse>(duplicate)).message).toBe(
      'User with this email already exists',
    );
  });

  test('trims email whitespace for duplicate detection', async ({ anonymousApi }) => {
    const user = createUserData({ email: `  trim-${createUserData().email}  ` });

    const first = await anonymousApi.signup({
      user: user.email,
      passwd: 'password123',
      name: '  Trim Test User  ',
    });
    expect(first.status()).toBe(201);

    const duplicate = await anonymousApi.signup({
      user: user.email.trim(),
      passwd: 'password123',
      name: 'Duplicate Attempt',
    });

    expect(duplicate.status()).toBe(409);
    expect((await expectJson<SignupResponse>(duplicate)).message).toBe(
      'User with this email already exists',
    );
  });
});
