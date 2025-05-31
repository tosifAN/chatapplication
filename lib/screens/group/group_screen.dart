import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/mqtt_service.dart';
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
  
  List<Message> _messages = [];
  List<User> _members = [];
  bool _isLoading = false;
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
      // Only add messages for this group
      if (message.groupId == widget.group.id) {
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

    // Add message to local list
    setState(() {
      _messages.insert(0, message);
    });

    // Send message via MQTT
    try {
      await _mqttService.sendMessage(message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: widget.group.avatarUrl != null
                        ? NetworkImage(widget.group.avatarUrl!)
                        : null,
                    child: widget.group.avatarUrl == null
                        ? Text(
                            widget.group.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 30),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    widget.group.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.group.description != null) ...[  
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      widget.group.description!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Members (${_members.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isCreator = member.id == widget.group.creatorId;
                    final isCurrentUser = member.id == _currentUser.id;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member.avatarUrl != null
                            ? NetworkImage(member.avatarUrl!)
                            : null,
                        child: member.avatarUrl == null
                            ? Text(member.username[0].toUpperCase())
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(member.username),
                          if (isCurrentUser)
                            const Text(' (You)', style: TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      subtitle: isCreator
                          ? const Text('Group Admin', style: TextStyle(color: Colors.blue))
                          : null,
                      trailing: isCreator || !isCurrentUser ? null : IconButton(
                        icon: const Icon(Icons.exit_to_app),
                        onPressed: () {
                          // Leave group functionality
                          Navigator.pop(context);
                          _showLeaveGroupDialog();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
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
                  onPressed: () {
                    // Implement file attachment
                  },
                ),
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
}

class GroupMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final User sender;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[  
            CircleAvatar(
              radius: 16,
              backgroundImage: sender.avatarUrl != null
                  ? NetworkImage(sender.avatarUrl!)
                  : null,
              child: sender.avatarUrl == null
                  ? Text(sender.username[0].toUpperCase(), style: const TextStyle(fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                    child: Text(
                      sender.username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).primaryColor.withOpacity(0.8)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white.withOpacity(0.7) : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 24),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    if (messageDate == today) {
      return timeStr;
    } else if (messageDate == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}, $timeStr';
    }
  }
}