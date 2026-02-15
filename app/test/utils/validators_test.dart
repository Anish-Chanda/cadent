import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('should return error for null value', () {
        expect(Validators.email(null), 'Please enter your email');
      });

      test('should return error for empty value', () {
        expect(Validators.email(''), 'Please enter your email');
      });

      test('should return error for value without @', () {
        expect(Validators.email('invalidemail'), 'Please enter a valid email');
      });

      test('should return null for valid email', () {
        expect(Validators.email('test@example.com'), null);
      });

      test('should trim whitespace', () {
        expect(Validators.email('  '), 'Please enter your email');
      });
    });

    group('password', () {
      test('should return error for null value', () {
        expect(Validators.password(null), 'Please enter your password');
      });

      test('should return error for empty value', () {
        expect(Validators.password(''), 'Please enter your password');
      });

      test('should return error for password shorter than minimum length', () {
        expect(
          Validators.password('12345', minLength: 6),
          'Password must be at least 6 characters',
        );
      });

      test('should return null for password meeting minimum length', () {
        expect(Validators.password('123456'), null);
      });

      test('should work with custom minimum length', () {
        expect(Validators.password('1234', minLength: 4), null);
        expect(
          Validators.password('123', minLength: 4),
          'Password must be at least 4 characters',
        );
      });
    });

    group('confirmPassword', () {
      test('should return error for null value', () {
        expect(
          Validators.confirmPassword(null, 'password'),
          'Please confirm your password',
        );
      });

      test('should return error for empty value', () {
        expect(
          Validators.confirmPassword('', 'password'),
          'Please confirm your password',
        );
      });

      test('should return error when passwords do not match', () {
        expect(
          Validators.confirmPassword('password1', 'password2'),
          'Passwords do not match',
        );
      });

      test('should return null when passwords match', () {
        expect(Validators.confirmPassword('password', 'password'), null);
      });
    });

    group('name', () {
      test('should return error for null value', () {
        expect(Validators.name(null), 'Please enter your name');
      });

      test('should return error for empty value', () {
        expect(Validators.name(''), 'Please enter your name');
      });

      test('should return error for whitespace only', () {
        expect(Validators.name('   '), 'Please enter your name');
      });

      test('should return null for valid name', () {
        expect(Validators.name('John Doe'), null);
      });
    });

    group('serverUrl', () {
      test('should return error for null value', () {
        expect(Validators.serverUrl(null), 'Please enter a server URL');
      });

      test('should return error for empty value', () {
        expect(Validators.serverUrl(''), 'Please enter a server URL');
      });

      test('should return error for invalid URL', () {
        expect(Validators.serverUrl('not a url'), 'Please enter a valid URL');
      });

      test('should return null for valid URL', () {
        expect(Validators.serverUrl('http://example.com'), null);
        expect(Validators.serverUrl('https://example.com'), null);
      });

      test('should trim whitespace', () {
        expect(Validators.serverUrl('  '), 'Please enter a server URL');
        expect(Validators.serverUrl('  http://example.com  '), null);
      });
    });

    group('required', () {
      test('should return error for null value', () {
        expect(Validators.required(null), 'Please enter this field');
      });

      test('should return error for empty value', () {
        expect(Validators.required(''), 'Please enter this field');
      });

      test('should return error with custom field name', () {
        expect(
          Validators.required(null, fieldName: 'username'),
          'Please enter username',
        );
      });

      test('should return null for non-empty value', () {
        expect(Validators.required('some value'), null);
      });

      test('should trim whitespace', () {
        expect(Validators.required('   '), 'Please enter this field');
      });
    });
  });
}
