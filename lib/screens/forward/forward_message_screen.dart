import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api/api_service.dart';
import '../../services/api/directmessage.dart';
import '../../providers/auth_provider.dart';

class ForwardMessageScreen extends StatefulWidget {
  final Message message;

  const ForwardMessageScreen({super.key, required this.message});

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ApiDirectMessageService _directMessageService = ApiDirectMessageService();
  
  List<User> _searchResults = [];
  bool _isLoading = false;
  bool _isForwarding = false;
  String? _errorMessage;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _apiService.searchUsers(query);
      
      // Filter out current user from results
      final filteredResults = results.where((user) => user.id != _currentUser.id).toList();
      
      setState(() {
        _searchResults = filteredResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forwardMessage(User recipient) async {
    setState(() {
      _isForwarding = true;
    });

    try {
      // Create a new message with the same content but new recipient
      final forwardedMessage = Message(
        senderId: _currentUser.id,
        receiverId: recipient.id,
        content: widget.message.content,
        type: widget.message.type,
      );

      await _directMessageService.sendDirectMessage(forwardedMessage);

      setState(() {
        _isForwarding = false;
      });

      // Show success message and pop back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message forwarded to ${recipient.username}'))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isForwarding = false;
        _errorMessage = 'Failed to forward message: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward Message'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search user to forward message',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                if (value.length >= 3) {
                  _searchUsers(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_isForwarding)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Search for users to forward message'
                              : 'No users found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(user.username[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(user.username),
                            subtitle: Text(user.email),
                            trailing: Text(
                              user.isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: user.isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                            onTap: () => _forwardMessage(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}