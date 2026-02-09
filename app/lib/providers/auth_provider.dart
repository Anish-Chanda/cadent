import 'dart:developer';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/http_client.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../models/user_profile.dart';
import '../models/user.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final SettingsService _settingsService = SettingsService.instance;
  AuthProvider._();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;
  
  String _serverUrl = '';
  String get serverUrl => _serverUrl;

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Direct access to user properties - nullable to indicate when no user is authenticated, these should ideally
  // never be accessed when status is unauthenticated, the authwrapper send the user to the login screen.
  String? get email => _currentUser?.email;
  String? get name => _currentUser?.name;
  String? get userId => _currentUser?.id;

  UserProfile? get userProfile {
    if (_currentUser == null) {
      return null;
    }
    return UserProfile(
      id: _currentUser!.id,
      email: _currentUser!.email,
      name: _currentUser!.name,
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

  // Check authentication state by getting user profile from API
  Future<void> _checkAuthState() async {
    _status = AuthStatus.unknown;
    notifyListeners();

    try {
      final userData = await _authService.getUserProfile();
      
      if (userData != null) {
        log('User is authenticated, setting user data...');
        _currentUser = User(
          id: userData['id'] as String,
          email: userData['email'] as String,
          name: userData['name'] as String,
        );
        _status = AuthStatus.authenticated;
        log('Loaded user profile: ${_currentUser!.name} (${_currentUser!.email})');
      } else {
        log('User is not authenticated, clearing user data...');
        _setUnauthenticated();
      }
    } catch (e) {
      log('Auth state check failed: $e');
      _setUnauthenticated();
    }
  }

  // Load user profile data
  Future<void> _loadUserProfile() async {
    try {
      log('Loading user profile...');
      final profile = await _settingsService.getUserProfile();
      if (profile != null) {
        _currentUser = User(
          id: profile.id,
          email: profile.email,
          name: profile.name,
        );
        _status = AuthStatus.authenticated;
        log('Loaded user profile: ${profile.name} (${profile.email})');
      } else {
        log('getUserProfile returned null - user profile not found');
        _setUnauthenticated();
      }
    } catch (e) {
      log('Failed to load user profile: $e');
      _setUnauthenticated();
    }
    notifyListeners();
  }

  // Change serverUrl, persist it, and re-initialize Dio so its baseUrl updates.
  Future<void> updateServerUrl(String newUrl) async {
    if (newUrl == _serverUrl) return;

    _serverUrl = newUrl;
    notifyListeners();

    // Persist the new URL
    await StorageService.saveServerUrl(newUrl);

    // Re-init only Dio’s baseUrl, reuse the same cookieJar, if these are valid the user will remain logged in.
    // sothe case where a user migrates their instance to a new server.
    await HttpClient.instance.init(baseUrl: _serverUrl);

    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(email: email, password: password);
      
      // Create a temporary user with the email - profile will be loaded right after
      _currentUser = User(id: '', email: email, name: '');
      
      // Load complete user profile data
      await _loadUserProfile();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _setUnauthenticated();
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
      
      _currentUser = User(id: userId, email: email, name: name);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return userId;
    } catch (e) {
      log('Signup/auto-login failed: $e');
      _isLoading = false;
      _setUnauthenticated();
      rethrow;
    }
  }

  // Helper method to set unauthenticated state
  void _setUnauthenticated() {
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
  }

  // Logout user and clear authentication state
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (e) {
      // Even if logout fails, clear local state
      log('Logout failed: $e');
    }

    _setUnauthenticated();
    _isLoading = false;
    notifyListeners();
  }

  // Update user profile (name, email, etc.)
  Future<bool> updateUserProfile({String? name, String? email}) async {
    if (_status != AuthStatus.authenticated) {
      log('Cannot update profile: user not authenticated');
      return false;
    }

    try {
      final updatedProfile = await _settingsService.updateUserProfile(
        name: name,
        email: email,
      );
      
      if (updatedProfile != null) {
        _currentUser = User(
          id: updatedProfile.id,
          email: updatedProfile.email,
          name: updatedProfile.name,
        );
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
