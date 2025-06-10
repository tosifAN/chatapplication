import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import '../../models/user.dart';
import 'auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ApiService {
  final String baseUrl;
  
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';

  // Remove the old _headers getter

  Future<User> getUserProfile(String userId) async {
    // Try to get from cache first
    final userBox = await Hive.openBox<User>('users');
    final cachedUser = userBox.get(userId);
    
    if (cachedUser != null) {
      // Return cached user immediately
      print("this is your cashed user ${cachedUser.username}");
      return cachedUser;
    }

    print("it is not yet cashed mr");
    
    // If not in cache, fetch from API
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: getAuthHeaders(),
    );
    
    if (response.statusCode == 200) {
      final user = User.fromJson(jsonDecode(response.body));
      // Store in Hive with userId as the key
      await userBox.put(userId, user);
      return user;
    } else {
      throw Exception('Failed to get user profile: ${response.body}');
    }
  }
  
  Future<List<User>> searchUsers(String query) async {
    // Create a unique cache key for this search query
    final cacheKey = 'search_${query.toLowerCase().trim()}';
    final userBox = await Hive.openBox<User>('users');
    final searchCacheBox = await Hive.openBox<Map>('search_cache');
    
    // Check if we have cached results for this query
    final cachedResult = searchCacheBox.get(cacheKey);
    if (cachedResult != null) {
      // Get the list of user IDs from cache
      final userIds = List<String>.from(cachedResult['userIds'] ?? []);
      final timestamp = cachedResult['timestamp'] as int? ?? 0;
      
      // If cache is less than 120 minutes old, return cached results
      if (DateTime.now().millisecondsSinceEpoch - timestamp < 120 * 60 * 1000) {
        // Get users from cache
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
    }
    
    // If no valid cache, fetch from API
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: getAuthHeaders(),
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final users = data.map((json) => User.fromJson(json)).toList();
      
      // Cache the users
      final userIds = <String>[];
      
      // Store users and collect their IDs
      for (final user in users) {
        await userBox.put(user.id, user);
        userIds.add(user.id);
      }
      
      // Save the search results with a timestamp
      await searchCacheBox.put(cacheKey, {
        'userIds': userIds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      return users;
    } else {
      throw Exception('Failed to search users: ${response.body}');
    }
  }

  Future<List<User>> getRecentChats(String userid) async {
    final cacheKey = 'recent_chats_$userid';
    final userBox = await Hive.openBox<User>('users');
    final recentChatsBox = await Hive.openBox<Map>('recent_chats_cache');
    
    // Check if we have cached results for this user
    final cachedResult = recentChatsBox.get(cacheKey);
    if (cachedResult != null) {
      // Get the list of user IDs from cache
      final userIds = List<String>.from(cachedResult['userIds'] ?? []);
      final timestamp = cachedResult['timestamp'] as int? ?? 0;
      
      // If cache is less than 120 minute old, return cached results
      if (DateTime.now().millisecondsSinceEpoch - timestamp < 120 * 60 * 1000) {
        // Get users from cache
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
    }
    
    // If no valid cache, fetch from API
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userid/recent-chats'),
      headers: getAuthHeaders(),
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final users = data.map((json) => User.fromJson(json)).toList();
      
      // Store users and collect their IDs
      final userIds = <String>[];
      for (final user in users) {
        await userBox.put(user.id, user);
        userIds.add(user.id);
      }
      
      // Save the recent chats with a timestamp (1 minute cache)
      await recentChatsBox.put(cacheKey, {
        'userIds': userIds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      return users;
    } else {
      throw Exception('Failed to get recent interacted users: ${response.body}');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return ;
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
  }
}