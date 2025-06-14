import 'dart:async';
import 'package:chatapplication/screens/chat/mainui.dart';
import 'package:chatapplication/services/api/directmessage.dart';
import 'package:chatapplication/services/file/file_service.dart';
import 'package:chatapplication/services/mqtt/mqtt_service.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final User otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiDirectMessageService _apiDirectMessageService = ApiDirectMessageService();
  final MQTTService _mqttService = MQTTService();
  final FileService _fileService = FileService();
  
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  late User _currentUser;
  late StreamSubscription<Message> _messageSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription.cancel();
    super.dispose();
  }

  void _subscribeToMessages() {
    _messageSubscription = _mqttService.messageStream.listen((message) {
      // Only add messages from the other user in this chat
      if (message.senderId == widget.otherUser.id && 
          message.receiverId == _currentUser.id) {
        setState(() {
          _messages.add(message);
          _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _apiDirectMessageService.getDirectMessages(
        _currentUser.id,
        widget.otherUser.id,
      );
      print("thats we are getting : ${messages[0].senderId}");
      setState(() {
        _messages = messages;
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoading = false;
      });
      
      _scrollToBottom();
      await _makeMessagesSeen(); 
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    }
  }
  Future<void> _makeMessagesSeen() async {
    try {
      // Filter messages for unread messages received by the current user
      List<String> messageIds = _messages
          .where((msg) => msg.receiverId == _currentUser.id && !msg.isRead)
          .map((msg) => msg.id)
          .toList();
      print("and this is messages : $_messages");
      print("this is messageids that are unseen $messageIds");
      if (messageIds.isEmpty) return;

      final _ = await _apiDirectMessageService.makeMessagesSeen(
        messageIds,
      );
    } catch (e) {
      print("recieved error while sending the api to make message seen");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    bool result = await InternetConnection().hasInternetAccess;
    if (!result){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No Internet! Connect with Internet First')),
      );
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = Message.create(
      senderId: _currentUser.id,
      receiverId: widget.otherUser.id,
      content: text,
      type: MessageType.text,
    );

    _messageController.clear();

    // Add message to local list
    setState(() {
      _messages.insert(0, message);
    });

    // Send message via MQTT
    try {
      await _mqttService.sendMessage(message);
      await _apiDirectMessageService.sendDirectMessage(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
      return mainUI(context, widget, _isLoading, _messages, _scrollController, _currentUser, _isUploading, _messageController, _handleFileAttachment, _sendMessage);
  }
  
Future<void> _handleFileAttachment() async {
    final file = await _fileService.pickFile(context);
    if (file == null) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final fileUrl = await _fileService.uploadFile(file, context);
      if (fileUrl != null && mounted) {
        // Determine message type based on file extension
        MessageType messageType;
        if (_fileService.isImageFile(file.path)) {
          messageType = MessageType.image;
        } else if (_fileService.isVideoFile(file.path)) {
          messageType = MessageType.video;
        } else if (_fileService.isPdfFile(file.path)) {
          messageType = MessageType.pdf;
        } else {
          messageType = MessageType.file;
        }
        
        // Create a file message
        final message = Message.create(
          senderId: _currentUser.id,
          receiverId: widget.otherUser.id,
          content: fileUrl,
          type: messageType,
        );
        
        // Add message to local list
        setState(() {
          _messages.insert(0, message);
        });
        
        // Send message via MQTT and API
        await _mqttService.sendMessage(message);
        await _apiDirectMessageService.sendDirectMessage(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}
