import 'package:chatapplication/services/api/api_service.dart';
import 'package:chatapplication/services/api/directmessage.dart'; // <-- Add this import
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../chat/chat_screen.dart';

class ChatsTab extends StatelessWidget {
  final String userId;

  ChatsTab({super.key, required this.userId});

  final ApiService _apiService = ApiService();
  final ApiDirectMessageService _directMessageService = ApiDirectMessageService(); // <-- Add this

  @override
  Widget build(BuildContext context) {
    // This will be replaced with actual data from a chat provider
    return FutureBuilder<List<User>>(
      // Correctly pass the Future returned by the API call
      future: _apiService.getRecentChats(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // snapshot.data is now directly List<User>
        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No chats yet. Search for users to start chatting!',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(user.username[0].toUpperCase())
                    : null,
              ),
              // --- Keep only the new subtitle and trailing widgets ---
              subtitle: FutureBuilder<int>(
                future: _directMessageService.getUnseenMessageCountBTUser(userId, user.id),
                builder: (context, countSnapshot) {
                  if (countSnapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading...');
                  }
                  if (countSnapshot.hasError) {
                    return const Text('Error');
                  }
                  final unseenCount = countSnapshot.data ?? 0;
                  return Text(
                    unseenCount > 0
                        ? 'You have $unseenCount unread message${unseenCount > 1 ? 's' : ''}'
                        : 'No unread messages',
                    style: TextStyle(
                      fontWeight: unseenCount > 0 ? FontWeight.bold : FontWeight.normal,
                      color: unseenCount > 0 ? Colors.red : null,
                    ),
                  );
                },
              ),
              trailing: FutureBuilder<int>(
                future: _directMessageService.getUnseenMessageCountBTUser(userId, user.id),
                builder: (context, countSnapshot) {
                  if (countSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (countSnapshot.hasError) {
                    return const Icon(Icons.error, color: Colors.red);
                  }
                  final unseenCount = countSnapshot.data ?? 0;
                  return unseenCount > 0
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Text(
                            unseenCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
              title: Text(user.username),
              // REMOVE the following lines:
              // subtitle: const Text('.....'), // Replace with actual last message
              // trailing: const Text('*'), // Replace with actual timestamp
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      otherUser: user,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
