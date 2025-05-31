import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/group.dart';

class ApiService {
  final String baseUrl;
  String? _token;
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';
  
  // Set auth token after login
  void setToken(String token) {
    _token = token;
  }
  
  // Clear token on logout
  void clearToken() {
    _token = null;
  }
  
  // Headers for authenticated requests
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }
  
  // User authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setToken(data['token']);
      return data;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }
  
  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }
  
  // User operations
  Future<User> getUserProfile(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get user profile: ${response.body}');
    }
  }
  
  Future<List<User>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search users: ${response.body}');
    }
  }
  
  // Message operations
  Future<List<Message>> getDirectMessages(String userId, String otherUserId, {int limit = 50, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/direct/$userId/$otherUserId?limit=$limit&offset=$offset'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get direct messages: ${response.body}');
    }
  }
  // Message operations
  Future<Message> sendDirectMessage(Message message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages/direct'),
      headers: _headers,
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
  
  Future<List<Message>> getGroupMessages(String groupId, {int limit = 50, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/group/$groupId?limit=$limit&offset=$offset'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get group messages: ${response.body}');
    }
  }
  
  // Group operations
  Future<Group> createGroup(String name, String description, List<String> memberIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: _headers,
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
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Group.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get user groups: ${response.body}');
    }
  }
  
  Future<Group> getGroupDetails(String groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/$groupId'),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      return Group.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get group details: ${response.body}');
    }
  }
  
  Future<void> addUserToGroup(String groupId, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/members'),
      headers: _headers,
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
      headers: _headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to remove user from group: ${response.body}');
    }
  }
}