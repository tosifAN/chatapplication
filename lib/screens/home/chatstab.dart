import 'package:chatapplication/services/api/api_service.dart';
import 'package:chatapplication/services/api/directmessage.dart'; // <-- Add this import
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../chat/chat_screen.dart';

class ChatsTab extends StatelessWidget {
  final String userId;

  ChatsTab({super.key, required this.userId});

  final ApiService _apiService = ApiService();
  final ApiDirectMessageService _directMessageService =
      ApiDirectMessageService(); // <-- Add this

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

        return LayoutBuilder(
          builder: (context, constraints) {
            double width = constraints.maxWidth;
            double cardPadding = width * 0.03;
            double cardRadius = width * 0.045;
            double avatarRadius = width * 0.07;
            double fontSizeTitle = width * 0.045;
            double fontSizeSubtitle = width * 0.035;
            double iconSize = width * 0.06;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: cardPadding,
                    vertical: cardPadding / 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x88232526), // ~53% opacity
                        Color(0x88414345), // ~53% opacity
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: cardPadding * 1.3,
                      vertical: cardPadding,
                    ),
                    leading: Container(
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
                        radius: 26,
                        backgroundImage:
                            user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                        child:
                            user.avatarUrl == null
                                ? Text(
                                  user.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                                : null,
                      ),
                    ),
                    title: Text(
                      user.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: FutureBuilder<int>(
                      future: _directMessageService.getUnseenMessageCountBTUser(
                        userId,
                        user.id,
                      ),
                      builder: (context, countSnapshot) {
                        if (countSnapshot.connectionState ==
                            ConnectionState.waiting) {
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
                            fontWeight:
                                unseenCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                unseenCount > 0 ? Colors.red : Colors.grey[600],
                          ),
                        );
                      },
                    ),
                    trailing: FutureBuilder<int>(
                      future: _directMessageService.getUnseenMessageCountBTUser(
                        userId,
                        user.id,
                      ),
                      builder: (context, countSnapshot) {
                        if (countSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            : const SizedBox.shrink();
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(otherUser: user),
                        ),
                      );
                    },
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
