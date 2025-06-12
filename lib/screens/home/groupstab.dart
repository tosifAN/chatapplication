import 'package:chatapplication/services/api/groupmessage.dart';
import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../group/group_screen.dart';

class GroupsTab extends StatelessWidget {
  final String userId;

  GroupsTab({super.key, required this.userId});

  final ApiGroupMessageService _apiGroupMessageService =
      ApiGroupMessageService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Group>>(
      future: _apiGroupMessageService.getUserGroups(
        userId,
      ), // Replace with actual API call
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'No groups yet. Create a group to get started!',
              textAlign: TextAlign.center,
            ),
          );
        }

        print("this could be number of users : ${groups[0].memberIds}");

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
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
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
                            group.avatarUrl != null
                                ? NetworkImage(group.avatarUrl!)
                                : null,
                        child:
                            group.avatarUrl == null
                                ? Text(
                                  group.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                                : null,
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      group.description ?? 'No description',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.group,
                            size: 16,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberIds.length} members',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupScreen(group: group),
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
