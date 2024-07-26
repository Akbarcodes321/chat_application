import 'package:chat_application/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat_application/themes/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  bool _switchValue = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _removeUserFromGroups(String userId) async {
    try {
      QuerySnapshot groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();

      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot groupDoc in groupsSnapshot.docs) {
        Map<String, dynamic>? data = groupDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          List<dynamic> members = List.from(data['members'] ?? []);
          if (members.contains(userId)) {
            members.remove(userId);

            batch.update(groupDoc.reference, {
              'members': members,
            });
            batch.delete(groupDoc.reference.collection('members').doc(userId));
          }
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error removing user from groups: $e');
    }
  }

  Future<List<String>> _getUserGroupIds(String userId) async {
    try {
      QuerySnapshot groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();
      List<String> groupIds = groupsSnapshot.docs.map((doc) => doc.id).toList();

      return groupIds;
    } catch (e) {
      print('Error retrieving user group IDs: $e');
      return [];
    }
  }

  Future<void> _deleteUserMessagesFromGroup(String groupId, String userId) async {
    try {
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .get();
      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting user messages from group: $e');
    }
  }

  Future<void> _deleteUserMessagesFromIndividualChats(String userId) async {
    try {
      QuerySnapshot chatsSnapshot = await _firestore
          .collection('chats')
          .where('members', arrayContains: userId)
          .get();

      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot chatDoc in chatsSnapshot.docs) {
        String chatId = chatDoc.id;
        int middleIndex = (chatId.length / 2).floor();
        String firstPart = chatId.substring(0, middleIndex);
        String secondPart = chatId.substring(middleIndex);
        if (userId == firstPart || userId == secondPart) {
          QuerySnapshot messagesSnapshot = await chatDoc.reference
              .collection('messages')
              .get();

          for (QueryDocumentSnapshot messageDoc in messagesSnapshot.docs) {
            batch.delete(messageDoc.reference);
          }
          batch.delete(chatDoc.reference);
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting user messages from individual chats: $e');
    }
  }



  Future<void> _deleteUserAccount() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        List<String> groupIds = await _getUserGroupIds(user.uid);

        await _removeUserFromGroups(user.uid);

        for (String groupId in groupIds) {
          await _deleteUserMessagesFromGroup(groupId, user.uid);
        }

        await _deleteUserMessagesFromIndividualChats(user.uid);

        await _firestore.collection('users').doc(user.uid).delete();
        await _auth.currentUser?.delete();
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(25),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dark Mode'),
                Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
                CupertinoSwitch(
                  value:  _switchValue,
                  onChanged: (value) {
                    setState(() {
                      _switchValue = value;
                      if (kDebugMode) {
                        print('234');
                      }

                    });
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(25),
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete your Account', style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                // Confirm deletion
                bool confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm) {
                  _deleteUserAccount();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
