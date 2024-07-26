import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/home_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupid;
  final String otherUserName;

  const GroupChatScreen({
    super.key,
    required this.groupid,
    required this.otherUserName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();

  late String _creatorUid;

  @override
  void initState() {
    super.initState();
    _fetchGroupCreator();
  }

  Future<void> _fetchGroupCreator() async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(widget.groupid).get();
      setState(() {
        _creatorUid = groupDoc['createdBy'] as String;
      });
    } catch (e) {
      print('Error fetching group creator: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userName = userDoc['name'];

        await _firestore.collection('groups').doc(widget.groupid).collection('messages').add({
          'text': _messageController.text.trim(),
          'senderId': user.uid,
          'senderName': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _editGroupName() async {
    final groupRef = _firestore.collection('groups').doc(widget.groupid);

    try {

      final groupDoc = await groupRef.get();
      final currentGroupName = groupDoc['groupName'] as String;
      final newGroupName = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          final _nameController = TextEditingController(text: currentGroupName);

          return AlertDialog(
            title: const Text('Edit Group Name'),
            content: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter new group name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(_nameController.text);
                },
                child: const Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (newGroupName != null && newGroupName.trim().isNotEmpty) {
        await groupRef.update({'groupName': newGroupName.trim()});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name updated successfully')),
        );
      } else if (newGroupName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update canceled')),
        );
      }
    } catch (e) {
      print('Error updating group name: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating group name: $e')),
      );
    }
  }

  Future<void> _deleteGroup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final groupRef = _firestore.collection('groups').doc(widget.groupid);

      final membersSnapshot = await groupRef.collection('members').get();
      for (final memberDoc in membersSnapshot.docs) {
        await memberDoc.reference.delete();
      }

      final messagesSnapshot = await groupRef.collection('messages').get();
      for (final messageDoc in messagesSnapshot.docs) {
        await messageDoc.reference.delete();
      }

      await groupRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted successfully')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      print('Error deleting group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting group: $e')),
      );
    }
  }

  Future<void> _leaveGroup(String groupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leaving group...'), duration: Duration(seconds: 2)),
      );

      final groupRef = _firestore.collection('groups').doc(groupId);

      await groupRef.update({
        'members': FieldValue.arrayRemove([user.uid]),
      });

      await groupRef.collection('members').doc(user.uid).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group successfully')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      print('Error leaving group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving group: $e')),
      );
    }
  }


  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final DateTime dateTime = timestamp.toDate();
    return DateFormat('hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('groups').doc(widget.groupid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Text('No data');
            }
            final groupName = snapshot.data?.get('groupName') ?? 'No Name';
            return Text(groupName);
          },
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _editGroupName();
              } else if (value == 'delete') {
                await _deleteGroup();
              } else if (value == 'leave') {
                await _leaveGroup(widget.groupid);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                if (_auth.currentUser!.uid == _creatorUid) ...[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit Group Name'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete Group'),
                  ),
                ],
                const PopupMenuItem<String>(
                  value: 'leave',
                  child: Text('Leave Group'),
                ),
              ];
            },
            icon: const Icon(Icons.more_vert_outlined),
          ),
        ],
        backgroundColor: const Color(0xffDEDEDE),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(widget.groupid)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message['senderId'] == _auth.currentUser!.uid;
                    final messageAlignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
                    final messageColor = isCurrentUser ? Colors.green : Colors.grey.shade300;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final formattedTime = _formatTimestamp(timestamp);
                    final senderName = message['senderName'] ?? 'Unknown';
                    return Container(
                      alignment: messageAlignment,
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isCurrentUser)
                            CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Text(senderName[0]),
                            ),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                                  decoration: BoxDecoration(
                                    color: messageColor,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isCurrentUser)
                                        Text(
                                          senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isCurrentUser ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      const SizedBox(height: 5.0),
                                      Text(message['text']),
                                      const SizedBox(height: 5.0),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          color: isCurrentUser ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          // getImage();
                        },
                        icon: const Icon(Icons.photo),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
