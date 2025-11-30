/// Model representing a user's profile information
class UserProfile {
  final String id;
  final String email;
  final String name;

  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
  });

  /// Create from JSON with validation
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final email = json['email'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    
    // Validate required fields since backend enforces them
    if (id.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('Name cannot be empty - this is a required field');
    }
    
    return UserProfile(
      id: id,
      email: email,
      name: name,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
    };
  }

  /// Create a copy with updated values
  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }

  /// Check if profile has complete data
  bool get isComplete => id.isNotEmpty && email.isNotEmpty && name.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.email == email &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, email, name);

  @override
  String toString() {
    return 'UserProfile(id: $id, email: $email, name: $name)';
  }
}