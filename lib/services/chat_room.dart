import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String status;
  final String uuid;
  const ChatScreen({
    required this.chatId,
    required this.otherUserName,
    required this.status,
    super.key, required this.uuid,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  File? imagefile;

  Future getImage() async {
    ImagePicker _picker = ImagePicker();
    await _picker.pickImage(source: ImageSource.gallery).then((xFile) {
      if (xFile != null) {
        imagefile = File(xFile.path);
        uploadImage();
      }
    });
  }

  Future uploadImage() async {
    String filename = const Uuid().v1();
    var ref = FirebaseStorage.instance.ref().child('image').child("$filename.jpg");
    var uploadTask = await ref.putFile(imagefile!);
    String imageurl = await uploadTask.ref.getDownloadURL();
    print(imageurl);
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userName = userDoc['name'];
        await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
          'text': _messageController.text.trim(),
          'senderId': user.uid,
          'senderName': userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
        if (chatDoc.exists) {
          await _firestore.collection('chats').doc(widget.chatId).update({
            'members': FieldValue.arrayUnion([user.uid])
          });
        } else {
          await _firestore.collection('chats').doc(widget.chatId).set({
            'members': [user.uid]
          });
        }

        _messageController.clear();
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).delete();
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  Future<void> _editMessage(String messageId, String newText) async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).update({
        'text': newText,
      });
    } catch (e) {
      print('Error editing message: $e');
    }
  }

  Future<void> _blockUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final otherUserDoc = await _firestore
            .collection('users')
            .where('name', isEqualTo: widget.otherUserName)
            .limit(1)
            .get();
        if (otherUserDoc.docs.isNotEmpty) {
          await _firestore.collection('users') .doc(user.uid).update({
            'blockedUsers': FieldValue.arrayUnion([{
              'uid': widget.uuid,
              'name': widget.otherUserName
            }])
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.otherUserName} has been blocked.')),
          );
          Navigator.pop(context);
        } else {
          print('Error: User not found.');
        }
      } catch (e) {
        print('Error blocking user: $e');
      }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Text(
              widget.status,
              style: const TextStyle(
                fontSize: 12.0,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xffDEDEDE),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _blockUser();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User'),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
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
                              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(message['text']),
                                          ),
                                          const SizedBox(width: 5.0),
                                          if (isCurrentUser)
                                            PopupMenuButton<String>(
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      final editController = TextEditingController(text: message['text']);
                                                      return AlertDialog(
                                                        title: const Text('Edit Message'),
                                                        content: TextField(
                                                          controller: editController,
                                                          decoration: const InputDecoration(hintText: 'Edit your message'),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                            child: const Text('Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              _editMessage(message.id, editController.text.trim());
                                                              Navigator.of(context).pop();
                                                            },
                                                            child: const Text('Save'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                } else if (value == 'delete') {
                                                  _deleteMessage(message.id);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete'),
                                                ),
                                              ],
                                              icon: Icon(
                                                Icons.more_vert,
                                                color: isCurrentUser ? Colors.white : Colors.black,
                                              ),
                                            ),
                                        ],
                                      ),
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
                          getImage();
                        },
                        icon: const Icon(Icons.photo),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
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
