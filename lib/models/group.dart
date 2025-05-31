import 'package:uuid/uuid.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Group({
    String? id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.creatorId,
    required this.memberIds,
    DateTime? createdAt,
    this.updatedAt,
  }) : 
    this.id = id ?? const Uuid().v4(),
    this.createdAt = createdAt ?? DateTime.now();

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      avatarUrl: json['avatar_url'],
      creatorId: json['creator_id'],
      memberIds: List<String>.from(json['member_ids'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
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
    return Group(
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

  Group addMember(String userId) {
    if (memberIds.contains(userId)) return this;
    return copyWith(memberIds: [...memberIds, userId]);
  }

  Group removeMember(String userId) {
    if (!memberIds.contains(userId)) return this;
    return copyWith(memberIds: memberIds.where((id) => id != userId).toList());
  }
}