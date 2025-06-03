import 'package:chatapplication/services/api/api_service.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../chat/chat_screen.dart';

class ChatsTab extends StatelessWidget {
  final String userId;

  ChatsTab({super.key, required this.userId});

  final ApiService _apiService = ApiService();

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
              title: Text(user.username),
              subtitle: const Text('.....'), // Replace with actual last message
              trailing: const Text('*'), // Replace with actual timestamp
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
