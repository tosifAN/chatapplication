import 'package:flutter/material.dart'; 
import 'package:chatapplication/models/user.dart';
import '../../models/group.dart';

void showGroupInfo({
  required BuildContext context,
  required Group group,
  required List<User> members,
  required User currentUser,
  required VoidCallback onLeaveGroup,
}) {
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
                  backgroundImage: group.avatarUrl != null
                      ? NetworkImage(group.avatarUrl!)
                      : null,
                  child: group.avatarUrl == null
                      ? Text(
                          group.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 30),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (group.description != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    group.description!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Members (${members.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isCreator = member.id == group.creatorId;
                    final isCurrentUser = member.id == currentUser.id;

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
                      trailing: isCreator || !isCurrentUser
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.exit_to_app),
                              onPressed: () {
                                Navigator.pop(context);
                                onLeaveGroup();
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}