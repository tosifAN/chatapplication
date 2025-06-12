import 'package:chatapplication/screens/home/chatstab.dart';
import 'package:chatapplication/screens/home/groupstab.dart';
import 'package:chatapplication/services/api/groupmessage.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    print("arrived in home screen");
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double cardPadding = width * 0.03;
        double fontSizeTitle = width * 0.045;
        double fontSizeSubtitle = width * 0.035;
        double iconSize = width * 0.06;
        double avatarRadius = width * 0.07;

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF833ab4), Color(0xFFfd1d1d), Color(0xFFfcb045)], // Instagram gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Chat App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) {
              return {
                'logout': 'Logout',
              }.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicator: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            color: Color(0x44fd1d1d), // Instagram red with opacity
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Chats tab
          ChatsTab(userId: user.id),
          // Groups tab
          GroupsTab(userId: user.id),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0xFFfd1d1d).withOpacity(0.3), // Instagram red shadow
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton(
          onPressed: () {
            if (_currentIndex == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            } else {
              _showCreateGroupDialog(context, user.id);
            }
          },
          backgroundColor: const Color(0xFF833ab4), // Instagram purple
          child: Icon(_currentIndex == 0 ? Icons.chat : Icons.group_add, color: Colors.white),
        ),
      ),
    );
      }
    );
  }

  void _showCreateGroupDialog(BuildContext context, String userId) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final ApiGroupMessageService _apiGroupMessageService = ApiGroupMessageService();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF833ab4), Color(0xFFfd1d1d), Color(0xFFfcb045)], // Instagram gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Text('Create New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final description = descriptionController.text.trim();
                    if (name.isEmpty) return;
                    bool result = await InternetConnection().hasInternetAccess;
                    if (!result){
                      ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('No Internet! Connect with Internet First')),
                    );
                    }
                    await _apiGroupMessageService.createGroup(name, description, [userId]);
                    Navigator.pop(context);
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
      )
    );
  }
}
