import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import 'auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

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
    // Create a cache key based on group ID and pagination
    final cacheKey = 'group_msgs_$groupId';
    final messageBox = await Hive.openBox<Message>('messages');
    final groupCacheBox = await Hive.openBox<Map>('group_chat_cache');
    
    // For pagination, we'll cache the first page (offset=0) separately
    final isFirstPage = offset == 0;
    final cacheKeyWithPagination = isFirstPage ? cacheKey : '${cacheKey}_${offset}_$limit';
    
    // Check if we have cached results for this group chat and pagination
    dynamic cachedResult;
    if (isFirstPage) {
      cachedResult = groupCacheBox.get(cacheKey);
      if (cachedResult != null) {
        final messageIds = List<String>.from(cachedResult['messageIds'] ?? []);
        final timestamp = cachedResult['timestamp'] as int? ?? 0;
        
        // If cache is less than 10 seconds old, return cached results
        if (DateTime.now().millisecondsSinceEpoch - timestamp < 1 * 10 * 1000) {
          // Get messages from cache
          final cachedMessages = messageIds
              .map((id) => messageBox.get(id))
              .whereType<Message>()
              .toList();
          
          if (cachedMessages.isNotEmpty) {
            return cachedMessages;
          }
        }
      }
    }
    
    // Check internet connectivity
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      // If we have any cache (even if expired), return it with empty list as fallback
      if (cachedResult != null) {
        final messageIds = List<String>.from(cachedResult['messageIds'] ?? []);
        final cachedMessages = messageIds
            .map((id) => messageBox.get(id))
            .whereType<Message>()
            .toList();
        if (cachedMessages.isNotEmpty) {
          return cachedMessages;
        }
      }
      // If no cache is available, return empty list instead of throwing
      return [];
    }
    
    try {
      // If we're online, fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/messages/group/$groupId?limit=$limit&offset=$offset'),
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final messages = data.map((json) => Message.fromJson(json)).toList();
        
        // Store messages and collect their IDs
        final messageIds = <String>[];
        for (final message in messages) {
          await messageBox.put(message.id, message);
          messageIds.add(message.id);
        }
        
        // Save the group chat messages with a timestamp
        if (isFirstPage) {
          await groupCacheBox.put(cacheKey, {
            'messageIds': messageIds,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
        
        return messages;
      } else {
        // If API fails but we have cached data, return that
        if (cachedResult != null) {
          final messageIds = List<String>.from(cachedResult['messageIds'] ?? []);
          final cachedMessages = messageIds
              .map((id) => messageBox.get(id))
              .whereType<Message>()
              .toList();
          if (cachedMessages.isNotEmpty) {
            return cachedMessages;
          }
        }
        // If no cache is available, return empty list instead of throwing
        return [];
      }
    } catch (e) {
      // For any error, try to return cached data if available
      if (cachedResult != null) {
        final messageIds = List<String>.from(cachedResult['messageIds'] ?? []);
        final cachedMessages = messageIds
            .map((id) => messageBox.get(id))
            .whereType<Message>()
            .toList();
        if (cachedMessages.isNotEmpty) {
          return cachedMessages;
        }
      }
      // If no cache is available, return empty list
      return [];
    }
  }
  
  Future<Message> sendInGroupMessages(Message message) async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return Message.create(senderId: 'noInternet', content: 'noInternet');
    }
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
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return Group.create(name: 'noInternet', creatorId: 'noInternet', memberIds: ['noInternet']);
    }
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
    final cacheKey = 'user_groups_$userId';
    final groupBox = await Hive.openBox<Group>('groups');
    final userGroupsCache = await Hive.openBox<Map>('user_groups_cache');
    
    // Check if we have cached results for this user
    final cachedResult = userGroupsCache.get(cacheKey);
    if (cachedResult != null) {
      final groupIds = List<String>.from(cachedResult['groupIds'] ?? []);
      final timestamp = cachedResult['timestamp'] as int? ?? 0;
      
      // If cache is less than 15 second old, return cached results
      if (DateTime.now().millisecondsSinceEpoch - timestamp < 1 * 15 * 1000) {
        // Get groups from cache
        final cachedGroups = groupIds
            .map((id) => groupBox.get(id))
            .whereType<Group>()
            .toList();
        
        if (cachedGroups.isNotEmpty) {
          print('Returning cached groups for user $userId');
          return cachedGroups;
        }
      }
    }
    
    // Check internet connectivity
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      // If we have any cache (even if expired), return it with empty list as fallback
      if (cachedResult != null) {
        final groupIds = List<String>.from(cachedResult['groupIds'] ?? []);
        final cachedGroups = groupIds
            .map((id) => groupBox.get(id))
            .whereType<Group>()
            .toList();
        if (cachedGroups.isNotEmpty) {
          print('Offline: Returning cached groups for user $userId');
          return cachedGroups;
        }
      }
      // If no cache is available, return empty list instead of throwing
      return [];
    }
    
    try {
      // If we're online, fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/groups'),
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        print('Fetched groups from API for user $userId: $data');
        
        // Process and store groups
        final groups = <Group>[];
        final groupIds = <String>[];
        
        for (final json in data) {
          final group = Group.fromJson(json);
          groups.add(group);
          groupIds.add(group.id);
          
          // Store group in the groups box
          await groupBox.put(group.id, group);
        }
        
        // Update the cache with the new data
        await userGroupsCache.put(cacheKey, {
          'groupIds': groupIds,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        return groups;
      } else {
        // If API fails but we have cached data, return that
        if (cachedResult != null) {
          final groupIds = List<String>.from(cachedResult['groupIds'] ?? []);
          final cachedGroups = groupIds
              .map((id) => groupBox.get(id))
              .whereType<Group>()
              .toList();
          if (cachedGroups.isNotEmpty) {
            print('API Error: Returning cached groups for user $userId');
            return cachedGroups;
          }
        }
        // If no cache is available, return empty list instead of throwing
        return [];
      }
    } catch (e) {
      // For any error, try to return cached data if available
      if (cachedResult != null) {
        final groupIds = List<String>.from(cachedResult['groupIds'] ?? []);
        final cachedGroups = groupIds
            .map((id) => groupBox.get(id))
            .whereType<Group>()
            .toList();
        if (cachedGroups.isNotEmpty) {
          print('Error ($e): Returning cached groups for user $userId');
          return cachedGroups;
        }
      }
      // If no cache is available, return empty list
      return [];
    }
  }
  
  Future<Group> getGroupDetails(String groupId) async {
    final groupBox = await Hive.openBox<Group>('groups');
    final groupDetailsCache = await Hive.openBox<Map>('group_details_cache');
    final cacheKey = 'group_details_$groupId';
    
    // Check if we have a cached version of this group
    final cachedGroup = groupBox.get(groupId);
    final cacheInfo = groupDetailsCache.get(cacheKey);
    
    // If we have a cached group and it's less than 120 minutes old, return it
    if (cachedGroup != null && 
        cacheInfo != null && 
        DateTime.now().millisecondsSinceEpoch - (cacheInfo['timestamp'] as int? ?? 0) < 120 * 60 * 1000) {
      print('Returning cached group details for group $groupId');
      return cachedGroup;
    }
    
    // Check internet connectivity
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      if (cachedGroup != null) {
        print('Offline: Returning cached group details for group $groupId');
        return cachedGroup;
      }
      throw Exception('No internet connection and no cached group available');
    }
    
    try {
      // If we're online, fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('Fetched group details from API for group $groupId: $jsonData');
        
        final group = Group.fromJson(jsonData);
        
        // Update the cache
        await groupBox.put(groupId, group);
        await groupDetailsCache.put(cacheKey, {
          'groupId': groupId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        return group;
      } else if (cachedGroup != null) {
        // If the API call fails but we have a cached version, return that
        print('API Error: Returning cached group details for group $groupId');
        return cachedGroup;
      } else {
        throw Exception('Failed to get group details: ${response.statusCode}');
      }
    } catch (e) {
      if (cachedGroup != null) {
        print('Error ($e): Returning cached group details for group $groupId');
        return cachedGroup;
      }
      rethrow;
    }
  }
  
  Future<void> addUserToGroup(String groupId, String userId) async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return ;
    }
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
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return ;
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/groups/$groupId/members/$userId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove user from group: ${response.body}');
    }
  }
  
  Future<void> deleteGroup(String groupId) async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return ;
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/groups/$groupId'),
      headers: getAuthHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group: ${response.body}');
    }
  }
}