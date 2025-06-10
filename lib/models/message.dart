import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 1)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  pdf,
  @HiveField(4)
  file,
  @HiveField(5)
  system
}

@HiveType(typeId: 2)
class Message extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String senderId;
  
  @HiveField(2)
  String? receiverId; // For direct messages
  
  @HiveField(3)
  String? groupId;    // For group messages
  
  @HiveField(4)
  late String content;
  
  @HiveField(5)
  late DateTime timestamp;
  
  @HiveField(6, defaultValue: false)
  late bool isRead;
  
  @HiveField(7)
  late MessageType type;

  Message();
  
  Message.create({
    String? id,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.content,
    DateTime? timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  }) {
    this.id = id ?? const Uuid().v4();
    this.timestamp = timestamp ?? DateTime.now();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message.create(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      groupId: json['group_id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'group_id': groupId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'type': type.toString().split('.').last,
    };
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? groupId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
  }) {
    return Message.create(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}