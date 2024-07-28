import 'dart:io';
import 'dart:ui';
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
    super.key,
    required this.uuid,
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
    var ref = FirebaseStorage.instance.ref().child('images').child("$filename.jpg");
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
          'status': 'sent',  // Initial status
        });
        _messageController.clear();
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  Future<void> _updateMessageStatus(String messageId, String status) async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).update({
        'status': status,
      });
    } catch (e) {
      print('Error updating message status: $e');
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
          await _firestore.collection('users').doc(user.uid).update({
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
  @override
  void initState() {
    super.initState();
    _markMessagesAsSeen();
  }

  Future<void> _markMessagesAsSeen() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final messages = await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .where('status', isEqualTo: 'sent')
            .get();
        for (var message in messages.docs) {
          if (message['senderId'] != user.uid) {
            _updateMessageStatus(message.id, 'seen');
          }
        }
      } catch (e) {
        print('Error marking messages as seen: $e');
      }
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const CircleAvatar(),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20),
                  ),
                  Text(
                    widget.status,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700], // WhatsApp green
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
            icon: const Icon(Icons.more_vert),
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
                    final messageColor = isCurrentUser ? Colors.green[100] : Colors.white;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final formattedTime = _formatTimestamp(timestamp);
                    final senderName = message['senderName'] ?? 'Unknown';
                    final messageId = message.id;
                    final currentText = message['text'] ?? '';
                    final messageStatus = message['status'];

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
                                          Icon(
                                            messageStatus == 'seen'
                                                ? Icons.done_all
                                                : Icons.check,
                                            size: 14.0,
                                            color: messageStatus == 'seen'
                                                ? Colors.blue
                                                : Colors.black54,
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
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: getImage,
                ),
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
