import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/user.dart';
import 'auth.dart';


class ApiService {
  final String baseUrl;
  
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';

  // Remove the old _headers getter

  Future<User> getUserProfile(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: getAuthHeaders(),
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
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search users: ${response.body}');
    }
  }

  Future<List<User>> getRecentChats(String userid) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userid/recent-chats'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      print("this is the recent chat user data $data");
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get recent interacted users: ${response.body}');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
  }
}