import 'dart:async';
import 'dart:io';
import 'package:chatapplication/screens/group/adduserdialogbox.dart';
import 'package:chatapplication/screens/group/group_message_bubble.dart';
import 'package:chatapplication/screens/group/infodialog.dart';
import 'package:chatapplication/services/api/groupmessage.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api/api_service.dart';
import '../../services/mqtt/mqtt_service.dart';
import '../../services/file/file_service.dart';
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
  final ApiGroupMessageService _apiGroupMessageService =
      ApiGroupMessageService();
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
    _currentUser =
        Provider.of<AuthProvider>(context, listen: false).currentUser!;
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

        final alreadyExists = _messages.any(
          (m) =>
              m.id == message.id ||
              (m.senderId == message.senderId &&
                  m.timestamp == message.timestamp &&
                  m.content == message.content),
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
      final messages = await _apiGroupMessageService.getGroupMessages(
        widget.group.id,
      );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
    }
  }

  Future<void> _loadGroupMembers() async {
    try {
      // Fetch group details to get updated member list
      final group = await _apiGroupMessageService.getGroupDetails(
        widget.group.id,
      );
      // Fetch user details for each member
      final membersFutures = group.memberIds.map(
        (userId) => _apiService.getUserProfile(userId),
      );
      final members = await Future.wait(membersFutures);

      setState(() {
        _members = members;
      });
    } on SocketException catch (e) {
      if (_members.isEmpty) {
        // Only show error if we don't have any cached members
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Showing cached data if available.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // We have cached members, just notify user they're seeing cached data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Using cached data.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connection timed out. Using cached data if available.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading group members: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 4),
        ),
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
    bool result = await InternetConnection().hasInternetAccess;
    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No Internet! Connect with Internet First')),
      );
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = Message.create(
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
      await _apiGroupMessageService.sendInGroupMessages(message);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    }
  }

  void _showLeaveGroupDialog() {
    final bool isAdmin = _currentUser.id == widget.group.creatorId;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isAdmin ? 'Leave or Delete Group' : 'Leave Group'),
            content: Text(
              isAdmin
                  ? 'As the admin, you can leave the group or delete it entirely.'
                  : 'Are you sure you want to leave this group?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _apiGroupMessageService.removeUserFromGroup(
                      widget.group.id,
                      _currentUser.id,
                    );
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
              if (isAdmin)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteGroupDialog();
                  },
                  child: const Text(
                    'Delete Group',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group'),
            content: const Text(
              'Are you sure you want to delete this group? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _apiGroupMessageService.deleteGroup(widget.group.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Group deleted successfully'),
                      ),
                    );
                    Navigator.pop(context); // Go back to home screen
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting group: $e')),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double avatarRadius = width * 0.07;
        double fontSizeTitle = width * 0.045;
        double fontSizeSubtitle = width * 0.035;
        double iconSize = width * 0.06;
        double cardPadding = width * 0.03;
        double cardRadius = width * 0.045;
        return Scaffold(
          appBar: AppBar(
            elevation: 2,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF833ab4),
                    Color(0xFFfd1d1d),
                    Color(0xFFfcb045),
                  ], // Instagram gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage:
                        widget.group.avatarUrl != null
                            ? NetworkImage(widget.group.avatarUrl!)
                            : null,
                    child:
                        widget.group.avatarUrl == null
                            ? Text(
                              widget.group.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.group,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.group.memberIds.length} members',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
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
                    apiGroupMessageService: _apiGroupMessageService,
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
                    onRefreshMembers: _loadGroupMembers,
                    onRemoveMember: (User member) async {
                      try {
                        await _apiGroupMessageService.removeUserFromGroup(
                          widget.group.id,
                          member.id,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${member.username} removed from group',
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error removing member: $e')),
                        );
                      }
                    },
                    onDeleteGroup: _showDeleteGroupDialog,
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child:
                    _isLoading
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
                              orElse:
                                  () => User.create(
                                    id: message.senderId,
                                    username: 'Unknown',
                                    email: '',
                                    lastSeen: DateTime.now(),
                                  ),
                            );
                            print("this is group message ${message.timestamp}");
                            return GroupMessageBubble(
                              message: message,
                              isMe: isMe,
                              sender: sender,
                            );
                          },
                        ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF232526),
                      Color(0xFF414345),
                    ], // Subtle dark gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: Colors.blueAccent,
                      tooltip: 'Attach file',
                      onPressed: _isUploading ? null : _handleFileAttachment,
                    ),
                    _isUploading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const SizedBox.shrink(),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 0,
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                          if (_messageController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _messageController.clear(),
                              splashRadius: 16,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF833ab4), // Instagram purple
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Color(0xFFfd1d1d),
                        ), // Instagram red
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          groupId: widget.group.id,
          content: fileUrl,
          type: messageType,
        );

        // Add message to local state first to avoid duplication
        setState(() {
          _messages.add(message);
          _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
        _scrollToBottom();

        // Send message via MQTT and API
        await _mqttService.sendMessage(message);
        await _apiGroupMessageService.sendInGroupMessages(message);
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
