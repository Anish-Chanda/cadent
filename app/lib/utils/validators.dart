/// Validation utility functions for forms
class Validators {
  /// Email validator
  /// 
  /// Accepted format examples:
  /// - user@example.com
  /// - test.user@domain.co.uk
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Password validator
  /// 
  /// Requirements:
  /// - Minimum length: 6 characters
  /// - Can contain any characters
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Confirm password validator
  /// 
  /// Validates that the confirmation matches the original password
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Name validator
  /// 
  /// Accepted format examples:
  /// - John Doe
  /// - Jane Smith-Johnson
  /// - José García
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    return null;
  }

  /// Server URL validator
  /// 
  /// Accepted format examples:
  /// - http://cadence.local
  /// - https://api.example.com
  /// - http://192.168.1.100:8080
  /// 
  /// Must include http:// or https:// scheme
  static String? serverUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a server URL';
    }
    try {
      final uri = Uri.parse(value.trim());
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return 'Please enter a valid URL';
      }
      return null;
    } catch (e) {
      return 'Please enter a valid URL';
    }
  }

  /// Required field validator
  /// 
  /// Generic validator for any required field
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter ${fieldName ?? 'this field'}';
    }
    return null;
  }
}
