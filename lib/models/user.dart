class User {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final DateTime lastSeen;
  final bool isOnline;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.lastSeen,
    this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      lastSeen: DateTime.parse(json['last_seen']),
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'last_seen': lastSeen.toIso8601String(),
      'is_online': isOnline,
    };
  }
}