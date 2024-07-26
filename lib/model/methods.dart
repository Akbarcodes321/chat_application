import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';

Future<User?> createAccount(String name, String email, String password) async {
  FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    User? user = userCredential.user;
    if (user != null) {
      print('Account Created');

      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'status': 'unavailable'
      });
      user.updateProfile(displayName: name);
      return user;
    } else {
      print('Account Creation Failed');
      return null;
    }
  } catch (e) {
    print(e);
    return null;
  }
}

Future<void> logout(BuildContext context) async {
  FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  try {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'status': 'Offline',
      });
    }
    await _auth.signOut();
    print('Logout Successful');

    // Navigate to login screen
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  } catch (e) {
    print(e);
  }
}
