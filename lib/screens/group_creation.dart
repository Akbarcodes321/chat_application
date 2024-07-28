import 'package:chat_application/screens/home_screen.dart';
import 'package:chat_application/widgets/custombutton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateGroup extends StatefulWidget {
  const CreateGroup({super.key});

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _groupUsers = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _memberNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _memberNameController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberNameController.removeListener(_filterUsers);
    _memberNameController.dispose();
    super.dispose();
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

  String _generateGroupId(String currentUserUid, List<String> memberUids) {
    String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    List<String> uidsWithCurrentUser = [currentUserUid] + memberUids;
    uidsWithCurrentUser.sort();
    return uidsWithCurrentUser.join('_') + '_' + timestamp;
  }


  void _filterUsers() {
    final query = _memberNameController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        return user['name'].toLowerCase().contains(query);
      }).toList();
    });
  }

  void _addUserToGroup(Map<String, dynamic> user) {
    setState(() {
      _groupUsers.add(user);
      _filteredUsers.remove(user);
      _memberNameController.clear();
    });
  }

  void _createGroup() async {
    final groupName = _groupNameController.text;

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_groupUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one member')),
      );
      return;
    }

    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current user not found')),
      );
      return;
    }

    List<String> memberUids = _groupUsers.map((user) => user['uid'] as String).toList();

    String groupId = _generateGroupId(currentUserUid, memberUids);

    print('Group Name: $groupName');
    print('Group ID: $groupId');
    print('Group Members: ${_groupUsers.map((user) => user['name']).join(', ')}');
    print('Current User UID: $currentUserUid');
    print('Member UIDs: $memberUids');

    try {
      await _firestore.collection('groups').doc(groupId).set({
        'groupName': groupName,
        'createdBy': currentUserUid,
        'members': [currentUserUid, ...memberUids],
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (String memberUid in [currentUserUid, ...memberUids]) {
        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(memberUid)
            .set({
          'uid': memberUid,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Group created successfully!')),
      );

      _groupNameController.clear();
      _groupUsers.clear();
      setState(() {
        _filteredUsers = _users;
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
            (route) => false,
      );
    } catch (e) {
      print('Error creating group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Create Group Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Group Name'),
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                hintText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Members'),
            TextField(
              controller: _memberNameController,
              decoration: const InputDecoration(
                hintText: 'Enter name',
                border: OutlineInputBorder(),
              ),
            ),
            if (_memberNameController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: _filteredUsers.isEmpty
                      ? [const ListTile(title: Text('No users found'))]
                      : _filteredUsers.map((user) {
                    return ListTile(
                      title: Text(user['name']),
                      subtitle: Text(user['email']),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addUserToGroup(user),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            SizedBox(
              height: 100,
              child: ListView.builder(
                itemCount: _groupUsers.length,
                itemBuilder: (context, index) {
                  final user = _groupUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user['name'][0]),
                    ),
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _createGroup,
              child: const CustomButton(name: 'Create', color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
