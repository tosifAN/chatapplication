import 'dart:async';
import 'package:chatapplication/screens/group/adduserdialogbox.dart';
import 'package:chatapplication/screens/group/group_message_bubble.dart';
import 'package:chatapplication/screens/group/infodialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/mqtt_service.dart';
import '../../services/file_service.dart';
import '../../providers/auth_provider.dart';

class GroupScreen extends StatefulWidget {
  final Group group;

  const GroupScreen({super.key, required this.group});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final MQTTService _mqttService = MQTTService();
  final FileService _fileService = FileService();
  
  List<Message> _messages = [];
  List<User> _members = [];
  bool _isLoading = false;
  bool _isUploading = false;
  late User _currentUser;
  late StreamSubscription<Message> _messageSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    _loadMessages();
    _loadGroupMembers();
    _subscribeToGroupMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription.cancel();
    _mqttService.unsubscribeFromGroup(widget.group.id);
    super.dispose();
  }

  void _subscribeToGroupMessages() {
    // Subscribe to group messages via MQTT
    _mqttService.subscribeToGroup(widget.group.id);
    
    _messageSubscription = _mqttService.messageStream.listen((message) {
      // Only add messages for this group and avoid duplicates
      if (message.groupId == widget.group.id) {
        // Skip messages from the current user as they're already added in _sendMessage
        if (message.senderId == _currentUser.id) {
          return; // Skip processing this message
        }
        
        final alreadyExists = _messages.any((m) =>
          m.id == message.id ||
          (m.senderId == message.senderId &&
           m.timestamp == message.timestamp &&
           m.content == message.content)
        );
        if (!alreadyExists) {
          setState(() {
            _messages.add(message);
            _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          });
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _apiService.getGroupMessages(widget.group.id);
      
      setState(() {
        _messages = messages;
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    }
  }

  Future<void> _loadGroupMembers() async {
    try {
      // Fetch group details to get updated member list
      final group = await _apiService.getGroupDetails(widget.group.id);
      // Fetch user details for each member
      final membersFutures = group.memberIds.map((userId) => _apiService.getUserProfile(userId));
      final members = await Future.wait(membersFutures);
      
      setState(() {
        _members = members;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading group members: $e')),
      );
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
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = Message(
      senderId: _currentUser.id,
      groupId: widget.group.id,
      content: text,
      type: MessageType.text,
    );

    _messageController.clear();
    
    // Add message to local state first to avoid duplication
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
    _scrollToBottom();
    
    // Send message via MQTT
    try {
      await _mqttService.sendMessage(message);
      await _apiService.sendInGroupMessages(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.removeUserFromGroup(widget.group.id, _currentUser.id);
                if (!mounted) return;
                Navigator.pop(context); // Go back to home screen
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error leaving group: $e')),
                );
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.group.avatarUrl != null
                  ? NetworkImage(widget.group.avatarUrl!)
                  : null,
              child: widget.group.avatarUrl == null
                  ? Text(widget.group.name[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.group.memberIds.length} members',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add User',
            onPressed: () {
              showAddUserDialog(
                context: context,
                group: widget.group,
                members: _members,
                currentUser: _currentUser,
                apiService: _apiService,
                refreshMembers: _loadGroupMembers,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showGroupInfo(
                context: context,
                group: widget.group,
                members: _members,
                currentUser: _currentUser,
                onLeaveGroup: _showLeaveGroupDialog,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == _currentUser.id;
                          final sender = _members.firstWhere(
                            (member) => member.id == message.senderId,
                            orElse: () => User(
                              id: message.senderId,
                              username: 'Unknown',
                              email: '',
                              lastSeen: DateTime.now(),
                            ),
                          );
                          
                          return GroupMessageBubble(
                            message: message,
                            isMe: isMe,
                            sender: sender,
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _isUploading ? null : _handleFileAttachment,
                ),
                _isUploading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const SizedBox.shrink(),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        // Create a file message
        final message = Message(
          senderId: _currentUser.id,
          groupId: widget.group.id,
          content: fileUrl,
          type: MessageType.file,
        );
        
        // Add message to local state first to avoid duplication
        setState(() {
          _messages.add(message);
          _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
        _scrollToBottom();
        
        // Send message via MQTT and API
        await _mqttService.sendMessage(message);
        await _apiService.sendInGroupMessages(message);
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