import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/message.dart';
import 'auth.dart';

class ApiDirectMessageService {
  final String baseUrl;

  static final ApiDirectMessageService _instance = ApiDirectMessageService._internal();

  factory ApiDirectMessageService() {
    return _instance;
  }

  ApiDirectMessageService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';

  Future<List<Message>> getDirectMessages(String userId, String otherUserId, {int limit = 50, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/direct/$userId/$otherUserId?limit=$limit&offset=$offset'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get direct messages: ${response.body}');
    }
  }

  Future<Message> sendDirectMessage(Message message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/direct'),
      headers: getAuthHeaders(),
      body: jsonEncode({
        'receiver_id': message.receiverId,
        'content': message.content,
        'type': message.type.name,
      }),
    );
    if (response.statusCode == 201) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to send direct message: ${response.body}');
    }
  }

  // Update the method signature to accept List<String>
  Future<bool> makeMessagesSeen(List<String> messageIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/mark-as-read'),
      headers: getAuthHeaders(),
      body: jsonEncode({
        'message_ids' : messageIds,
      }),
    );
    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Failed to makeMessagesSeen: ${response.body}');
    }
  }

  // Update the method signature to accept List<String>
  Future<int> getUnseenMessageCountBTUser(String userId, String otherUserId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/direct/unseen-count/$userId/$otherUserId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['unseen_count'] ?? 0;
    } else {
      throw Exception('Failed to get unseen message count: ${response.body}');
    }
  }
}
