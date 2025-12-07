import 'package:flutter/foundation.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/models/user_profile.dart';
import 'package:cadence/models/user.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  AuthStatus _status = AuthStatus.unauthenticated;
  String _serverUrl = 'http://mock-server.test';
  bool _isLoading = false;
  User? _currentUser;

  @override
  AuthStatus get status => _status;

  @override
  User? get currentUser => _currentUser;

  @override
  String? get email => _currentUser?.email;

  @override
  String? get name => _currentUser?.name;

  @override
  String? get userId => _currentUser?.id;

  @override
  UserProfile? get userProfile {
    if (_currentUser == null) return null;
    return UserProfile(
      id: _currentUser!.id,
      email: _currentUser!.email,
      name: _currentUser!.name,
    );
  }

  @override
  String get serverUrl => _serverUrl;

  @override
  bool get isLoading => _isLoading;

  // Fake async initialize
  static Future<MockAuthProvider> initialize() async {
    return MockAuthProvider();
  }

  @override
  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(Duration.zero);
    _status = AuthStatus.authenticated;
    _currentUser = User(id: 'mock-user-id', email: email, name: 'Test User');
    _isLoading = false;
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(Duration.zero);
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  Future<String> signUp({required String email, required String password, required String name}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(Duration.zero);
    _status = AuthStatus.authenticated;
    _currentUser = User(id: 'mock-user-id', email: email, name: name);
    _isLoading = false;
    notifyListeners();
    return 'mock-user-id';
  }

  @override
  Future<void> updateServerUrl(String newUrl) async {
    _serverUrl = newUrl;
    notifyListeners();
  }

  @override
  Future<bool> updateUserProfile({String? name, String? email}) async {
    if (_currentUser == null) return false;
    _currentUser = User(
      id: _currentUser!.id,
      email: email ?? _currentUser!.email,
      name: name ?? _currentUser!.name,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> updateName(String newName) async {
    return updateUserProfile(name: newName);
  }

  // Helper methods for testing
  void setAuthenticated(bool authenticated) {
    _status = authenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    if (!authenticated) {
      _currentUser = null;
    }
    notifyListeners();
  }

  void setUser(User user) {
    _currentUser = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
