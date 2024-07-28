import 'dart:ui';

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

  Future<void> _editMessage(String messageId, String newText) async {
    try {
      await _firestore.collection('groups').doc(widget.groupid).collection('messages').doc(messageId).update({
        'text': newText,
      });
    } catch (e) {
      print('Error editing message: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _firestore.collection('chats').doc(widget.groupid).collection('messages').doc(messageId).delete();
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  void _showMessageOptions(String messageId, String currentText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  color: Colors.black.withOpacity(
                      0),
                ),
              ),
              // The bottom sheet content
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16.0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit'),
                      onTap: () {
                        Navigator.pop(context);
                        _showEditMessageDialog(messageId, currentText);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Delete'),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessage(messageId);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cancel),
                      title: const Text('Cancel'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  void _showEditMessageDialog(String messageId, String currentText) {
    _messageController.text = currentText;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editMessage(messageId, _messageController.text);
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
        centerTitle: true,
        backgroundColor: Colors.green[700],
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
                    final messageColor = isCurrentUser ? Colors.green[100] : Colors.white;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final formattedTime = _formatTimestamp(timestamp);
                    final senderName = message['senderName'] ?? 'Unknown';
                    final messageId = message.id;
                    final currentText = message['text'] ?? '';

                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(messageId, currentText),
                      child: Container(
                        alignment: messageAlignment,
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isCurrentUser)
                              CircleAvatar(
                                radius: 16.0,
                                backgroundColor: Colors.grey[300],
                                child: Text(senderName[0], style: const TextStyle(color: Colors.black87)),
                              ),
                            const SizedBox(width: 8.0),
                            Flexible(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 280.0, // Fixed width
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
                                decoration: BoxDecoration(
                                  color: messageColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(isCurrentUser ? 12.0 : 0),
                                    topRight: Radius.circular(isCurrentUser ? 0 : 12.0),
                                    bottomLeft: const Radius.circular(12.0),
                                    bottomRight: const Radius.circular(12.0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser)
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    Text(
                                      currentText,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        color: isCurrentUser ? Colors.black87 : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 5.0),
                                    Row(
                                      mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          formattedTime,
                                          style: const TextStyle(
                                            fontSize: 12.0,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(width: 4.0),
                                        if (isCurrentUser)
                                          const Icon(
                                            Icons.check,
                                            size: 14.0,
                                            color: Colors.black54,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
                // IconButton(
                //   icon: const Icon(Icons.image),
                  // onPressed: getImage,
                // ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
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

