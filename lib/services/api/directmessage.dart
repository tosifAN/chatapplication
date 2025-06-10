import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import '../../models/message.dart';
import 'auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ApiDirectMessageService {
  final String baseUrl;

  static final ApiDirectMessageService _instance = ApiDirectMessageService._internal();

  factory ApiDirectMessageService() {
    return _instance;
  }

  ApiDirectMessageService._internal() : baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8080/api';

  Future<List<Message>> getDirectMessages(String userId, String otherUserId, {int limit = 50, int offset = 0}) async {
    // Create a cache key based on both user IDs and pagination
    final cacheKey = 'direct_msgs_${userId}_$otherUserId';
    final messageBox = await Hive.openBox<Message>('messages');
    final chatCacheBox = await Hive.openBox<Map>('chat_cache');
    
    // For pagination, we'll cache the first page (offset=0) separately
    final isFirstPage = offset == 0;
    final cacheKeyWithPagination = isFirstPage ? cacheKey : '${cacheKey}_${offset}_$limit';
    
    // Check if we have cached results for this chat and pagination
    if (isFirstPage) {
      final cachedResult = chatCacheBox.get(cacheKey);
      if (cachedResult != null) {
        final messageIds = List<String>.from(cachedResult['messageIds'] ?? []);
        final timestamp = cachedResult['timestamp'] as int? ?? 0;
        
        // If cache is less than 120 minutes old, return cached results
        if (DateTime.now().millisecondsSinceEpoch - timestamp < 120 * 60 * 1000) {
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
    
    // If no valid cache, fetch from API
    final response = await http.get(
      Uri.parse('$baseUrl/messages/direct/$userId/$otherUserId?limit=$limit&offset=$offset'),
      headers: getAuthHeaders(),
    );
    
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final messages = data.map((json) => Message.fromJson(json)).toList();
      
      // Store messages and collect their IDs
      final messageIds = <String>[];
      for (final message in messages) {
        await messageBox.put(message.id, message);
        messageIds.add(message.id);
      }
      
      // Save the chat messages with a timestamp (30 seconds cache for first page)
      if (isFirstPage) {
        await chatCacheBox.put(cacheKey, {
          'messageIds': messageIds,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      return messages;
    } else {
      throw Exception('Failed to get direct messages: ${response.body}');
    }
  }

  Future<Message> sendDirectMessage(Message message) async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return Message.create(senderId: 'noInternet', content: 'noInternet');
    }
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
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return false;
    }
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
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
       print("No Internet Connection! Please connect with internet");
       return 0;
    }
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
