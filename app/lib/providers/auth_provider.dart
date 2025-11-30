import 'dart:developer';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/http_client.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../models/user_profile.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final SettingsService _settingsService = SettingsService.instance;
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

  String _name = '';
  String get name => _name;

  String _userId = '';
  String get userId => _userId;

  UserProfile? get userProfile {
    if (!_isAuthenticated || _userId.isEmpty || _email.isEmpty) {
      return null;
    }
    return UserProfile(
      id: _userId,
      email: _email,
      name: _name,
    );
  }

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
      
      // If authenticated, load user profile
      if (_isAuthenticated) {
        log('User is authenticated, loading profile...');
        await _loadUserProfile();
      } else {
        log('User is not authenticated, clearing user data...');
        _clearUserData();
      }
    } catch (e) {
      log('Auth state check failed: $e');
      _isAuthenticated = false;
      _clearUserData();
    }

    _isCheckingAuthState = false;
    notifyListeners();
  }

  // Load user profile data
  Future<void> _loadUserProfile() async {
    try {
      log('Loading user profile...');
      final profile = await _settingsService.getUserProfile();
      if (profile != null) {
        _userId = profile.id;
        _email = profile.email;
        _name = profile.name;
        log('Loaded user profile: ${profile.name} (${profile.email})');
      } else {
        log('getUserProfile returned null - user profile not found');
      }
    } catch (e) {
      log('Failed to load user profile: $e');
    }
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
      
      // Store the email immediately after successful login
      _email = email;
      
      // Load complete user profile data
      await _loadUserProfile();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      _isLoading = false;
      _clearUserData();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> signUp({required String email, required String password, required String name}) async {
    log('Starting signup for email: $email');
    _isLoading = true;
    notifyListeners();

    try {
      final userId = await _authService.signup(
        email: email,
        password: password,
        name: name,
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

  // Clear user data
  void _clearUserData() {
    _userId = '';
    _email = '';
    _name = '';
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

    _clearUserData();
    _isLoading = false;
    notifyListeners();
  }

  // Update user profile (name, email, etc.)
  Future<bool> updateUserProfile({String? name, String? email}) async {
    if (!_isAuthenticated) {
      log('Cannot update profile: user not authenticated');
      return false;
    }

    try {
      final updatedProfile = await _settingsService.updateUserProfile(
        name: name,
        email: email,
      );
      
      if (updatedProfile != null) {
        _userId = updatedProfile.id;
        _email = updatedProfile.email;
        _name = updatedProfile.name;
        notifyListeners();
        log('User profile updated successfully');
        return true;
      }
      return false;
    } catch (e) {
      log('Failed to update user profile: $e');
      return false;
    }
  }

  Future<bool> updateName(String newName) async {
    return updateUserProfile(name: newName);
  }
}
