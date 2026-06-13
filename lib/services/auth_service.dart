import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // 使用使用者提供的正確 Web Client ID
  static const String _webClientId = '937055748879-2ucjkm5k3q552c2c9pqm5el2gh5g88gt.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
  );

  Stream<User?> get userStream => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        DocumentSnapshot userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          AppUser newUser = AppUser(
            uid: user.uid,
            email: user.email ?? "",
            displayName: user.displayName ?? "User",
            friendIds: [],
          );
          await _db.collection('users').doc(user.uid).set(newUser.toMap());
        }
      }
      return result;
    } catch (e) {
      print("Google Sign-In Error: ${e.toString()}");
      return null;
    }
  }

  Future<void> signOut() async {
    if (kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<AppUser?> getUserData(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
