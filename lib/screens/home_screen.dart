import 'package:chat_application/screens/group_creation.dart';
import 'package:chat_application/services/chat_room.dart';
import 'package:chat_application/services/group_room.dart';
import 'package:chat_application/widgets/drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _filteredGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchUsername();
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
            _username = userDoc.data()?['name'] ?? 'Unknown User';
            _email = userDoc.data()?['email'] ?? 'No email provided';
          });
        }
      } catch (e) {
        print('Error fetching username: $e');
      }
    }
  }

  String _generateChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  void _navigateToChatScreen(String chatId, String otherUserName, String status, String uuid) {
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    if (timestamp.isAfter(today)) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (timestamp.isAfter(yesterday)) {
      return 'Yesterday';
    } else if (timestamp.isAfter(twoDaysAgo)) {
      return DateFormat('EEEE').format(timestamp);
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }


  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredUsers = _searchQuery.isEmpty
          ? []
          : _filteredUsers.where((user) {
        final nameLower = user['name'].toString().toLowerCase();
        final queryLower = _searchQuery.toLowerCase();
        return nameLower.contains(queryLower);
      }).toList();
    });
  }

  void _filterGroups(String query) {
    setState(() {
      _searchQuery = query;
      _filteredGroups = _searchQuery.isEmpty
          ? []
          : _filteredGroups.where((group) {
        final groupNameLower = group['groupName'].toString().toLowerCase();
        final queryLower = _searchQuery.toLowerCase();
        return groupNameLower.contains(queryLower);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserName = _username;
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
            // Chats Tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      color: Colors.grey[100],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search users...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10), // Adjust padding to align hint text
                      ),
                      onChanged: _filterUsers,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No users found'));
                      }

                      final userDocs = snapshot.data!.docs;
                      final currentUserUid = _auth.currentUser!.uid;

                      if (_filteredUsers.isEmpty) {
                        _filteredUsers = userDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          data['id'] = doc.id;
                          return data;
                        }).toList();
                      }

                      final filteredUsers = _searchQuery.isEmpty
                          ? _filteredUsers
                          : _filteredUsers.where((user) {
                        final nameLower = user['name'].toString().toLowerCase();
                        final queryLower = _searchQuery.toLowerCase();
                        return nameLower.contains(queryLower);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          if (user['id'] == currentUserUid) return const SizedBox.shrink();

                          final chatId = _generateChatId(currentUserUid, user['id']);

                          return StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('chats')
                                .doc(chatId)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .snapshots(),
                            builder: (context, messageSnapshot) {
                              String latestMessage = 'No messages yet';
                              String senderName = '';
                              String messageTime = '';
                              if (messageSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                                final messageDoc = messageSnapshot.data!.docs.first;
                                latestMessage = messageDoc['text'] ?? 'No message text';
                                senderName = (messageDoc['senderName'] == currentUserName) ? 'You: ' : '${messageDoc['senderName']}: ';
                                final timestamp = (messageDoc['timestamp'] as Timestamp?)?.toDate();
                                if (timestamp != null) {
                                  messageTime = _formatTimestamp(timestamp);
                                }
                                final messageStatus = messageDoc['status'];
                              }

                              return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
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
                                      radius: 25,
                                      backgroundColor: Colors.grey[600],
                                      child: Text(
                                        (user['name'] ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          user['name'] ?? 'Unknown User',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.circle,color: (user['status'] ?? 'Offline') == 'Online' ? Colors.green : Colors.red,size: 10,),
                                        const SizedBox(width: 4.0), // Space between the circle and the status text
                                        Text(
                                          user['status'] ?? 'Unknown status',
                                          style: TextStyle(
                                            color: (user['status'] ?? 'Offline') == 'Online' ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 20,),
                                        Row(
                                          children: [

                                            Text(
                                              '$senderName',
                                              style: const TextStyle(color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Expanded(
                                              child: Text(
                                                latestMessage,
                                                style: const TextStyle(color: Colors.grey),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              messageTime,
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () => _navigateToChatScreen(
                                      chatId,
                                      user['name'] ?? 'Unknown User',
                                      user['status'] ?? 'Unknown',
                                      user['id'] ?? 'Unknown',
                                    ),
                                  ),
                                );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            // Groups Tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search groups...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _filterGroups,
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('groups').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No groups found'));
                      }

                      final groupDocs = snapshot.data!.docs;
                      if (_filteredGroups.isEmpty) {
                        _filteredGroups = groupDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          data['id'] = doc.id;
                          return data;
                        }).toList();
                      }

                      final filteredGroups = _searchQuery.isEmpty
                          ? _filteredGroups
                          : _filteredGroups.where((group) {
                        final groupNameLower = group['groupName'].toString().toLowerCase();
                        final queryLower = _searchQuery.toLowerCase();
                        return groupNameLower.contains(queryLower);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredGroups.length,
                        itemBuilder: (context, index) {
                          final group = filteredGroups[index];

                          return StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('groups')
                                .doc(group['id'])
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .snapshots(),
                            builder: (context, messageSnapshot) {
                              String latestMessage = 'No messages yet';
                              String senderName = '';
                              String messageTime = '';
                              if (messageSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                                final messageDoc = messageSnapshot.data!.docs.first;
                                latestMessage = messageDoc['text'] ?? 'No message text';
                                senderName = (messageDoc['senderName'] == currentUserName) ? 'You: ' : '${messageDoc['senderName']}: ';
                                final timestamp = (messageDoc['timestamp'] as Timestamp?)?.toDate();
                                if (timestamp != null) {
                                  messageTime = _formatTimestamp(timestamp);
                                }
                              }

                              return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
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
                                        (group['groupName'] ?? 'G')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      group['groupName'] ?? 'Unknown Group',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 15,),
                                        Row(
                                          children: [
                                            Text(
                                              '$senderName',
                                              style: const TextStyle(color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Expanded(
                                              child: Text(
                                                latestMessage,
                                                style: const TextStyle(color: Colors.grey),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              messageTime,
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () => _navigateToGroupChatScreen(
                                      group['id'] ?? 'Unknown Group',
                                      group['groupName'] ?? 'Unknown Group',
                                    ),
                                  ),
                                );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateGroup()),
            );
          },
          child: const Icon(Icons.group_add),
        ),
      ),
    );
  }
}
