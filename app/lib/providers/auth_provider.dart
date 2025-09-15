import 'dart:developer';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/http_client.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  AuthProvider._();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  bool _isCheckingAuthState = false;
  bool get isCheckingAuthState => _isCheckingAuthState;
  
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  
  String _serverUrl = '';
  String get serverUrl => _serverUrl;

  String _email = '';
  String get email => _email;

  // Must call this before using any other AuthProvider methods.
  static Future<AuthProvider> initialize() async {
    final provider = AuthProvider._();

    // Load saved serverUrl or use a default.
    final savedUrl = await StorageService.getServerUrl();
    provider._serverUrl = savedUrl ?? 'http://cadence.local';

    // Initialize AuthService (sets up Dio & loads any persisted cookies).
    await provider._authService.initialize(serverUrl: provider._serverUrl);

    // Check if user is already authenticated
    await provider._checkAuthState();

    return provider;
  }

  // Check authentication state by making a test API call
  Future<void> _checkAuthState() async {
    log('Checking auth state...');
    _isCheckingAuthState = true;
    notifyListeners();

    try {
      _isAuthenticated = await _authService.checkAuthState();
      log('Auth state check result: $_isAuthenticated');
    } catch (e) {
      log('Auth state check failed: $e');
      _isAuthenticated = false;
    }

    _isCheckingAuthState = false;
    notifyListeners();
  }

  // Change serverUrl, persist it, and re-initialize Dio so its baseUrl updates.
  Future<void> updateServerUrl(String newUrl) async {
    if (newUrl == _serverUrl) return;

    _serverUrl = newUrl;
    notifyListeners();

    // Persist the new URL:
    await StorageService.saveServerUrl(newUrl);

    // Re-init only Dio’s baseUrl; reuse the same cookieJar
    await HttpClient.instance.init(baseUrl: _serverUrl);

    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(email: email, password: password);
      _isAuthenticated = true;
      _isLoading = false;
      _email = email;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String> signUp({required String email, required String password}) async {
    log('Starting signup for email: $email');
    _isLoading = true;
    notifyListeners();

    try {
      final userId = await _authService.signup(
        email: email,
        password: password,
      );
      log('Signup successful, userId: $userId. Now logging in...');
      
      // After successful signup, automatically log the user in
      await _authService.login(email: email, password: password);
      log('Auto-login after signup successful');
      
      _isAuthenticated = true;
      _email = email;
      _isLoading = false;
      notifyListeners();
      return userId;
    } catch (e) {
      log('Signup/auto-login failed: $e');
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Logout user and clear authentication state
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _isAuthenticated = false;
    } catch (e) {
      // Even if logout fails, clear local state
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }
}
