import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'token.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ApiAuthService {
  final String baseUrl;
  
  // Singleton pattern
  static final ApiAuthService _instance = ApiAuthService._internal();
  
  factory ApiAuthService() {
    return _instance;
  }
  
  ApiAuthService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';
  
  // User authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: getAuthHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ApiAuthTokenService().setToken(data['token']);
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
}

Map<String, String> getAuthHeaders() {
  final headers = {
    'Content-Type': 'application/json',
  };
  final token = ApiAuthTokenService().token;
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}