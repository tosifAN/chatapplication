import 'package:flutter/material.dart'; 
import 'package:chatapplication/models/user.dart';
import '../../models/group.dart';

void showGroupInfo({
  required BuildContext context,
  required Group group,
  required List<User> members,
  required User currentUser,
  required VoidCallback onLeaveGroup,
  required Future<void> Function() onRefreshMembers,
  required Future<void> Function(User member) onRemoveMember,
  required VoidCallback onDeleteGroup, // <-- Add this line
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
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage: group.avatarUrl != null
                        ? NetworkImage(group.avatarUrl!)
                        : null,
                    child: group.avatarUrl == null
                        ? Text(
                            group.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
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
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
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
                    final isAdmin = currentUser.id == group.creatorId;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.blue[50],
                          backgroundImage: member.avatarUrl != null
                              ? NetworkImage(member.avatarUrl!)
                              : null,
                          child: member.avatarUrl == null
                              ? Text(member.username[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(member.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (isCurrentUser)
                              const Text(' (You)', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)),
                          ],
                        ),
                        subtitle: isCreator
                            ? const Text('Group Admin', style: TextStyle(color: Colors.blue))
                            : null,
                        trailing: isCreator || !isCurrentUser
                            ? (isAdmin && !isCurrentUser && !isCreator ? 
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  tooltip: 'Remove member',
                                  onPressed: () {
                                    _showRemoveMemberDialog(
                                      context,
                                      group,
                                      member,
                                      () async {
                                        await onRemoveMember(member);
                                        await onRefreshMembers();
                                      },
                                    );
                                  },
                                ) : null)
                            : IconButton(
                                icon: const Icon(Icons.exit_to_app),
                                tooltip: 'Leave group',
                                onPressed: () {
                                  Navigator.pop(context);
                                  onLeaveGroup();
                                },
                              ),
                      ),
                    );
                  },
                ),
              ),
              if (currentUser.id == group.creatorId)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onDeleteGroup();
                      },
                      child: const Text('Delete Group'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showRemoveMemberDialog(BuildContext context, Group group, User member, VoidCallback onRemoved) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove Member'),
      content: Text('Are you sure you want to remove ${member.username} from the group?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onRemoved();
            // You should also call your API to remove the member here
          },
          child: const Text('Remove', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}