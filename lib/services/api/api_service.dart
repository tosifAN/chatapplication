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
    final userBox = await Hive.openBox<User>('users');
    
    // First check for cached data
    final cachedUser = userBox.get(userId);
    
    // Check internet connectivity
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      if (cachedUser != null) {
        print("No internet. Returning cached user: ${cachedUser.username}");
        return cachedUser;
      }
      throw Exception('No internet connection and no cached data available');
    }
    
    try {
      // If we're online, fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final user = User.fromJson(jsonDecode(response.body));
        // Update cache with fresh data
        await userBox.put(userId, user);
        return user;
      } else {
        // If API fails but we have cached data, return that
        if (cachedUser != null) {
          print("API Error ${response.statusCode}, returning cached user: ${cachedUser.username}");
          return cachedUser;
        }
        throw Exception('Failed to get user profile: ${response.statusCode}');
      }
    } catch (e) {
      // For any error, try to return cached data if available
      if (cachedUser != null) {
        print("Error occurred (${e.runtimeType}), returning cached user: ${cachedUser.username}");
        return cachedUser;
      }
      rethrow;
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
    
    // Check internet connectivity
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      // If we have any cache (even if expired), return it with empty list as fallback
      if (cachedResult != null) {
        final userIds = List<String>.from(cachedResult['userIds'] ?? []);
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
      // If no cache is available, return empty list instead of throwing
      return [];
    }
    
    try {
      // If we're online, fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/users/search?q=$query'),
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
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
        // If API fails but we have cached data, return that
        if (cachedResult != null) {
          final userIds = List<String>.from(cachedResult['userIds'] ?? []);
          final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
          if (cachedUsers.isNotEmpty) {
            return cachedUsers;
          }
        }
        // If no cache is available, return empty list instead of throwing
        return [];
      }
    } catch (e) {
      // For any error, try to return cached data if available
      if (cachedResult != null) {
        final userIds = List<String>.from(cachedResult['userIds'] ?? []);
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
      // If no cache is available, return empty list
      return [];
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
      
      // If cache is less than 120 minutes old, return cached results
      if (DateTime.now().millisecondsSinceEpoch - timestamp < 120 * 60 * 1000) {
        // Get users from cache
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
    }
    
    // Check internet connectivity
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      // If we have any cache (even if expired), return it with empty list as fallback
      if (cachedResult != null) {
        final userIds = List<String>.from(cachedResult['userIds'] ?? []);
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
      // If no cache is available, return empty list instead of throwing
      return [];
    }
    
    try {
      // If we're online, fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userid/recent-chats'),
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final users = data.map((json) => User.fromJson(json)).toList();
        
        // Store users and collect their IDs
        final userIds = <String>[];
        for (final user in users) {
          await userBox.put(user.id, user);
          userIds.add(user.id);
        }
        
        // Save the recent chats with a timestamp
        await recentChatsBox.put(cacheKey, {
          'userIds': userIds,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        return users;
      } else {
        // If API fails but we have cached data, return that
        if (cachedResult != null) {
          final userIds = List<String>.from(cachedResult['userIds'] ?? []);
          final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
          if (cachedUsers.isNotEmpty) {
            return cachedUsers;
          }
        }
        // If no cache is available, return empty list instead of throwing
        return [];
      }
    } catch (e) {
      // For any error, try to return cached data if available
      if (cachedResult != null) {
        final userIds = List<String>.from(cachedResult['userIds'] ?? []);
        final cachedUsers = userIds.map((id) => userBox.get(id)).whereType<User>().toList();
        if (cachedUsers.isNotEmpty) {
          return cachedUsers;
        }
      }
      // If no cache is available, return empty list
      return [];
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return false;
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
    else{
      return true;
    }
  }
}