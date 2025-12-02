import '../services/http_client.dart';

// AuthService handles API communication for authentication
// This service is responsible only for making HTTP requests
// State management is handled by AuthProvider
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // Must be called before using any other methods of AuthService
  Future<void> initialize({required String serverUrl}) async {
    await HttpClient.instance.init(baseUrl: serverUrl);
  }

  // Sign up a new user. Returns the user_id on success.
  Future<String> signup({required String email, required String password, required String name}) async {
    final dio = HttpClient.instance.dio;
    final response = await dio.post(
      '/signup',
      data: {'user': email, 'passwd': password, 'name': name},
    );

    if (response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true && data['user_id'] != null) {
        return data['user_id'] as String;
      } else {
        throw Exception('Sign-up failed: ${response.data}');
      }
    } else {
      throw Exception(
        'Sign-up HTTP ${response.statusCode}: ${response.statusMessage}',
      );
    }
  }

  // Authenticate user with email and password
  Future<void> login({required String email, required String password}) async {
    final dio = HttpClient.instance.dio;
    final response = await dio.post(
      '/auth/local/login?session=1',
      data: {'user': email, 'passwd': password},
    );

    if (response.statusCode == 200) {
      // CookieManager already saved any Set-Cookie headers to disk.
      return;
    } else {
      throw Exception(
        'Login HTTP ${response.statusCode}: ${response.statusMessage}',
      );
    }
  }

  // Check authentication status and get user data using the user endpoint
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final dio = HttpClient.instance.dio;
      // Use the /v1/user endpoint - returns user data if authenticated, 401 if not
      final response = await dio.get('/v1/user');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      // Any error (network, 401, 403, etc.) means not authenticated
      // TODO: Implement token refreshes in the backend, we will need a refreshcache and if the cookie
      // is still valid then we can refresh the token, or we can implement our sesssion mgmt in the backend.
      return null;
    }
  }

  // Logout user by clearing cookies
  Future<void> logout() async {
    await HttpClient.instance.clearCookies();
  }
}
