import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import 'user.dart';

part 'group.g.dart';

@HiveType(typeId: 3)
class GroupMember extends HiveObject {
  @HiveField(0)
  late String groupId;
  
  @HiveField(1)
  late String userId;
  
  @HiveField(2)
  late DateTime joinedAt;
  
  @HiveField(3)
  late bool isAdmin;
  
  @HiveField(4)
  late DateTime createdAt;
  
  @HiveField(5)
  late DateTime updatedAt;
  
  @HiveField(6)
  User? user;

  GroupMember();
  
  GroupMember.create({
    required this.groupId,
    required this.userId,
    required this.joinedAt,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember.create(
      groupId: json['group_id'],
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
      isAdmin: json['is_admin'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

@HiveType(typeId: 4)
class Group extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String name;
  
  @HiveField(2)
  String? description;
  
  @HiveField(3)
  String? avatarUrl;
  
  @HiveField(4)
  late String creatorId;
  
  @HiveField(5)
  late List<String> memberIds;
  
  @HiveField(6)
  late DateTime createdAt;
  
  @HiveField(7)
  DateTime? updatedAt;
  
  @HiveField(8)
  User? creator;
  
  @HiveField(9)
  List<GroupMember>? members;

  Group();
  
  Group.create({
    String? id,
    required String name,
    this.description,
    this.avatarUrl,
    required String creatorId,
    required List<String> memberIds,
    DateTime? createdAt,
    this.updatedAt,
    this.creator,
    this.members,
  }) {
    this.id = id ?? const Uuid().v4();
    this.name = name;
    this.creatorId = creatorId;
    this.memberIds = memberIds;
    this.createdAt = createdAt ?? DateTime.now();
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group.create(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      avatarUrl: json['avatar_url'],
      creatorId: json['creator_id'],
      memberIds: json['members'] != null
          ? List<String>.from(json['members'].map((m) => m['user_id']))
          : (json['member_ids'] != null ? List<String>.from(json['member_ids']) : []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      creator: json['creator'] != null ? User.fromJson(json['creator']) : null,
      members: json['members'] != null
          ? List<GroupMember>.from(json['members'].map((m) => GroupMember.fromJson(m)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'creator_id': creatorId,
      'member_ids': memberIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    String? creatorId,
    List<String>? memberIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group.create(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      creatorId: creatorId ?? this.creatorId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}