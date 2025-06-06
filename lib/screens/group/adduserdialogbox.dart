import 'package:chatapplication/services/api/groupmessage.dart';
import 'package:flutter/material.dart'; 
import 'package:chatapplication/models/user.dart';
import 'dart:async';
import '../../models/group.dart';
import '../../services/api/api_service.dart';

void showAddUserDialog({
  required BuildContext context,
  required Group group,
  required List<User> members,
  required User currentUser,
  required ApiService apiService,
  required ApiGroupMessageService apiGroupMessageService,
  required Future<void> Function() refreshMembers,
}) {
  final TextEditingController _addUserSearchController = TextEditingController();
  List<User> _addUserSearchResults = [];
  bool _isAddUserLoading = false;
  String? _addUserError;
  bool dialogActive = true;

  // Ensure dialog is marked as inactive when dismissed
  void closeDialog() {
    dialogActive = false;
    Navigator.pop(context);
  }

  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final isAdmin = currentUser.id == group.creatorId;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add User to Group',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          closeDialog();
                          _addUserSearchController.clear();
                        },
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: isAdmin
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search field
                              TextField(
                                controller: _addUserSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by username or email',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  suffixIcon: _addUserSearchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _addUserSearchController.clear();
                                            setState(() {
                                              _addUserSearchResults = [];
                                              _addUserError = null;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) async {
                                  if (value.length >= 3) {
                                    setState(() {
                                      _isAddUserLoading = true;
                                      _addUserError = null;
                                    });

                                    try {
                                      final results = await apiService.searchUsers(value);

                                      final filtered = results.where((user) =>
                                        !members.any((m) => m.id == user.id) &&
                                        user.id != currentUser.id
                                      ).toList();

                                      if (dialogActive) {
                                        setState(() {
                                          _addUserSearchResults = filtered;
                                          _isAddUserLoading = false;
                                        });
                                      }
                                    } catch (e) {
                                      if (dialogActive) {
                                        setState(() {
                                          _addUserError = e.toString();
                                          _isAddUserLoading = false;
                                        });
                                      }
                                    }
                                  } else if (value.isEmpty) {
                                    setState(() {
                                      _addUserSearchResults = [];
                                      _addUserError = null;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              // Error message
                              if (_addUserError != null)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _addUserError!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Loading indicator
                              if (_isAddUserLoading)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              // No results message
                              if (!_isAddUserLoading &&
                                  _addUserSearchResults.isEmpty &&
                                  _addUserSearchController.text.length >= 3)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.person_search, 
                                          size: 48, 
                                          color: Colors.grey.withOpacity(0.5)
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No users found',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Search results
                              if (_addUserSearchResults.isNotEmpty)
                                Expanded(
                                  child: Material(
                                    // Wrap with Material to avoid intrinsic dimension issues
                                    child: MediaQuery.removePadding(
                                      // Remove padding to avoid intrinsic dimension issues
                                      context: context,
                                      removeTop: true,
                                      child: ListView.separated(
                                        shrinkWrap: true, // Important to avoid intrinsic dimension issues
                                        separatorBuilder: (context, index) => const Divider(height: 1),
                                        itemCount: _addUserSearchResults.length,
                                        itemBuilder: (context, index) {
                                          final user = _addUserSearchResults[index];
                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                                radius: 24,
                                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                                backgroundImage: user.avatarUrl != null
                                                    ? NetworkImage(user.avatarUrl!)
                                                    : null,
                                                child: user.avatarUrl == null
                                                    ? Text(
                                                        user.username[0].toUpperCase(),
                                                        style: TextStyle(
                                                          color: Theme.of(context).primaryColor,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            title: Text(
                                              user.username,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text(user.email),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: user.isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                user.isOnline ? 'Online' : 'Offline',
                                                style: TextStyle(
                                                  color: user.isOnline ? Colors.green : Colors.grey,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            onTap: () async {
                                              closeDialog(); // Close dialog
                                              try {
                                                await apiGroupMessageService.addUserToGroup(group.id, user.id);
                                                await refreshMembers();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(Icons.check_circle, color: Colors.white),
                                                        const SizedBox(width: 8),
                                                        Text('${user.username} added to group'),
                                                      ],
                                                    ),
                                                    backgroundColor: Colors.green,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(Icons.error_outline, color: Colors.white),
                                                        const SizedBox(width: 8),
                                                        Expanded(child: Text('Error adding user: $e')),
                                                      ],
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Only the group admin can add users.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: closeDialog,
                                child: const Text('Close'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                // Actions for admin view
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            closeDialog();
                            _addUserSearchController.clear();
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  // Set dialogActive to false when the dialog is dismissed
  Future.delayed(Duration.zero, () {
    if (context.mounted) {
      Navigator.of(context).popUntil((route) {
        if (route.isActive) return true;
        dialogActive = false;
        return true;
      });
    }
  });
}
