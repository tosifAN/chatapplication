import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/message.dart';

class MQTTService {
  MqttServerClient? _client;
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  String? _clientId;
  String? _currentUserId;
  
  // Singleton pattern
  static final MQTTService _instance = MQTTService._internal();
  
  factory MQTTService() {
    return _instance;
  }
  
  MQTTService._internal();
  
  Future<bool> connect(String userId) async {
    if (_isConnected) return true;
    
    _currentUserId = userId;
    _clientId = 'flutter_client_$userId';
    
    final String broker = dotenv.env['MQTT_BROKER'] ?? 'localhost';
    final int port = int.parse(dotenv.env['MQTT_PORT'] ?? '1883');
    
    _client = MqttServerClient(broker, _clientId!);
    _client!.port = port;
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    print("connection with mqtt starting....");
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId!)
        .withWillTopic('will/$_clientId')
        .withWillMessage('disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    _client!.connectionMessage = connMessage;
    
    try {
      await _client!.connect();
      print("sucessfully connected!");
      return _isConnected = true;
    } catch (e) {
      if (kDebugMode) {
        print('Exception: $e');
      }
      _client!.disconnect();
      return false;
    }
  }
  
  void _onConnected() {
    if (kDebugMode) {
      print('Connected to MQTT broker');
    }
    
    // Subscribe to direct messages
    _subscribeToDirectMessages();
    
    // Subscribe to group messages
    _subscribeToGroupMessages();
  }
  
  void _onDisconnected() {
    if (kDebugMode) {
      print('Disconnected from MQTT broker');
    }
    _isConnected = false;
  }
  
  void _onSubscribed(String topic) {
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }
  
  void _subscribeToDirectMessages() {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected && _currentUserId != null) {
      _client!.subscribe('chat/user/$_currentUserId', MqttQos.atLeastOnce);
      
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (var message in messages) {
          final MqttPublishMessage recMess = message.payload as MqttPublishMessage;
          final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          
          try {
            final Map<String, dynamic> messageJson = jsonDecode(payload);
            final Message chatMessage = Message.fromJson(messageJson);
            _messageController.add(chatMessage);
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing message: $e');
            }
          }
        }
      });
    }
  }
  
  void _subscribeToGroupMessages() {
    // This will be implemented when user joins groups
  }
  
  Future<bool> subscribeToGroup(String groupId) async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe('chat/group/$groupId', MqttQos.atLeastOnce);
      return true;
    }
    return false;
  }
  
  Future<bool> unsubscribeFromGroup(String groupId) async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.unsubscribe('chat/group/$groupId');
      return true;
    }
    return false;
  }
  
  Future<bool> sendMessage(Message message) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return false;
    }
    
    String topic;
    if (message.groupId != null) {
      topic = 'chat/group/${message.groupId}';
    } else if (message.receiverId != null) {
      topic = 'chat/user/${message.receiverId}';
    } else {
      return false;
    }
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message.toJson()));
    
    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: false
    );
    
    return true;
  }
  
  void disconnect() {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.disconnect();
    }
    _isConnected = false;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
