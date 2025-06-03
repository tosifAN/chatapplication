import 'package:chatapplication/services/api/groupmessage.dart';
import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../group/group_screen.dart';


class GroupsTab extends StatelessWidget {

  final String userId;
  
  GroupsTab({super.key, required this.userId});

  final ApiGroupMessageService _apiGroupMessageService = ApiGroupMessageService();


  @override
  Widget build(BuildContext context) {
    // This will be replaced with actual data from a group provider
    return FutureBuilder<List<Group>>(
      future: _apiGroupMessageService.getUserGroups(userId), // Replace with actual API call
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final groups = snapshot.data ?? [];

        print("this could be number of users : ${groups[0].memberIds}");
        
        if (groups.isEmpty) {
          return const Center(
            child: Text(
              'No groups yet. Create a group to get started!',
              textAlign: TextAlign.center,
            ),
          );
        }
        
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: group.avatarUrl != null
                    ? NetworkImage(group.avatarUrl!)
                    : null,
                child: group.avatarUrl == null
                    ? Text(group.name[0].toUpperCase())
                    : null,
              ),
              title: Text(group.name),
              subtitle: Text(group.description ?? 'No description'),
              trailing: Text('${group.memberIds.length} members'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupScreen(group: group),
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
