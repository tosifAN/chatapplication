import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import 'auth.dart';

class ApiGroupMessageService {
  final String baseUrl;
  
  static final ApiGroupMessageService _instance = ApiGroupMessageService._internal();
  
  factory ApiGroupMessageService() {
    return _instance;
  }
  
  ApiGroupMessageService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';
  
  // Replace the old _headers getter with a call to getAuthHeaders()
  // Remove the old _headers getter
  
  Future<List<Message>> getGroupMessages(String groupId, {int limit = 50, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/group/$groupId?limit=$limit&offset=$offset'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get group messages: ${response.body}');
    }
  }
  
  Future<Message> sendInGroupMessages(Message message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/group'),
      headers: getAuthHeaders(),
      body: jsonEncode({
        'group_id': message.groupId,
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
  
  Future<Group> createGroup(String name, String description, List<String> memberIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: getAuthHeaders(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'member_ids': memberIds,
      }),
    );
    if (response.statusCode == 201) {
      return Group.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }
  
  Future<List<Group>> getUserGroups(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/groups'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      print("this is group data see it : $data");
      return data.map((json) => Group.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get user groups: ${response.body}');
    }
  }
  
  Future<Group> getGroupDetails(String groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/$groupId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      print("this is group details : ${jsonDecode(response.body)}");
      return Group.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get group details: ${response.body}');
    }
  }
  
  Future<void> addUserToGroup(String groupId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/members'),
      headers: getAuthHeaders(),
      body: jsonEncode({
        'user_id': userId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add user to group: ${response.body}');
    }
  }
  
  Future<void> removeUserFromGroup(String groupId, String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/groups/$groupId/members/$userId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove user from group: ${response.body}');
    }
  }
  
  Future<void> deleteGroup(String groupId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/groups/$groupId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
  }
}