import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String username;
  
  @HiveField(2)
  late String email;
  
  @HiveField(3)
  String? avatarUrl;
  
  @HiveField(4)
  late DateTime lastSeen;
  
  @HiveField(5, defaultValue: false)
  late bool isOnline;

  User();
  
  User.create({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.lastSeen,
    this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User.create(
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