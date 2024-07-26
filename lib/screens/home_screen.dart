import 'package:chat_application/screens/group_creation.dart';
import 'package:chat_application/services/chat_room.dart';
import 'package:chat_application/services/group_room.dart';
import 'package:chat_application/widgets/drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _username;
  String? _email;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _fetchUsers();
    WidgetsBinding.instance.addObserver(this);
    setStatus('Online');
  }

  void setStatus(String status) async {
    await _firestore.collection('users').doc(_auth.currentUser?.uid).update({
      "status": status,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setStatus('Online');
    } else {
      setStatus('Offline');
    }
  }

  Future<void> _fetchUsername() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _username = userDoc.data()?['name'];
            _email = userDoc.data()?['email'];
          });
        }
      } catch (e) {
        print('Error fetching username: $e');
      }
    }
  }

  Future<void> _fetchUsers() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final usersSnapshot = await _firestore.collection('users').get();
        final users = usersSnapshot.docs
            .where((doc) => doc.id != user.uid)
            .map((doc) => {
          'uid': doc.id,
          'name': doc.data()['name'],
          'email': doc.data()['email'],
          'status': doc.data()['status'],
        })
            .toList();

        setState(() {
          _users = users;
          _filteredUsers = users;
        });
      } catch (e) {
        print('Error fetching users: $e');
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _users.where((user) {
        return user['name'].toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  String _generateChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  void _navigateToChatScreen(String chatId, String otherUserName, String status,String uuid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          otherUserName: otherUserName,
          status: status,
          uuid: uuid,
        ),
      ),
    );
  }

  void _navigateToGroupChatScreen(String groupId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          groupid: groupId,
          otherUserName: groupName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Application'),
          backgroundColor: Colors.green,
          centerTitle: true,
          bottom: const TabBar(tabs: [
            Text(
              'Chats',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              'Groups',
              style: TextStyle(color: Colors.white),
            ),
          ]),

        ),
        drawer: _username != null
            ? MyDrawer(currentUser: _username!, email: _email!)
            : const MyDrawer(currentUser: 'Loading...', email: 'Loading...'),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _filterUsers,
                  ),
                ),
                Expanded(
                  child: _filteredUsers.isNotEmpty
                      ? ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[600],
                              child: Text(
                                user['name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              user['name'] ?? "Null",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(user['email']),
                            trailing: Text(
                              user['status'],
                              style: TextStyle(
                                color: user['status'] == 'Online'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              final currentUserUid = _auth.currentUser!.uid;
                              final otherUserUid = user['uid'];
                              final chatId = _generateChatId(
                                  currentUserUid, otherUserUid);
                              _navigateToChatScreen(
                                  chatId, user['name'], user['status'],user['uid']);
                            },
                          ),
                        ),
                      );
                    },
                  )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
            // Groups Tab
            Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    // onChanged: _filterGroups, // If you want to filter groups
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('groups')
                        .where('members', arrayContains: _auth.currentUser!.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No groups to be shown'));
                      }
                      final groups = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id;
                        return data;
                      }).toList();
                      return ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  child: Text(
                                    group['groupName'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  group['groupName'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Members: ${group['members'].length}'),
                                onTap: () {
                                  _navigateToGroupChatScreen(group['id'], group['groupName']);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const CreateGroup()),
                            );
                          },
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Create Group',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
