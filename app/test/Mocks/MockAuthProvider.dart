import 'package:flutter/foundation.dart';
import 'package:cadence/providers/auth_provider.dart'; // For type

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isAuthenticated = true;
  String _email = 'test@example.com';
  String _serverUrl = 'http://mock-server.test';
  bool _isLoading = false;
  bool _isCheckingAuthState = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String get email => _email;

  @override
  String get serverUrl => _serverUrl;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isCheckingAuthState => _isCheckingAuthState;

  // Fake async initialize
  static Future<MockAuthProvider> initialize() async {
    return MockAuthProvider();
  }

  @override
  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(Duration.zero);
    _isAuthenticated = true;
    _email = email;
    _isLoading = false;
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(Duration.zero);
    _isAuthenticated = false;
    _email = '';
    _isLoading = false;
    notifyListeners();
  }

  @override
  Future<String> signUp({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(Duration.zero);
    _isAuthenticated = true;
    _email = email;
    _isLoading = false;
    notifyListeners();
    return 'mock-user-id';
  }

  @override
  Future<void> updateServerUrl(String newUrl) async {
    _serverUrl = newUrl;
    notifyListeners();
  }
}
