import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDatasource {
  Future<UserModel> login({
    required String email,
    required String password,
  });
  
  Future<void> logout();
  
  Future<UserModel> getCurrentUser();
}

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final firebase_auth.FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDatasourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc = await FirebaseConfig.facilityDb
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) throw ServerException('User profile not found');

      final user = UserModel.fromFirestore(userDoc.data()!
        ..['id'] = credential.user!.uid);

      // Ensure facility is registered in shared index
      await FirebaseConfig.sharedDb
          .collection('facilities')
          .doc(user.facilityId)
          .set({
        'id': user.facilityId,
        'name': user.facilityName,
        'is_active': true,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));  // merge: true = don't overwrite existing data

      return user;
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? 'Login failed');
    }
  }
  @override
  Future<void> logout() async {
    try {
      await firebaseAuth.signOut();
    } catch (e) {
      throw ServerException('Logout failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final currentUser = firebaseAuth.currentUser;
      
      if (currentUser == null) {
        throw ServerException('No user logged in');
      }

      final userDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw ServerException('User profile not found');
      }

      final userData = userDoc.data()!;
      userData['id'] = currentUser.uid;
      userData['email'] = currentUser.email ?? '';

      return UserModel.fromJson(userData);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}