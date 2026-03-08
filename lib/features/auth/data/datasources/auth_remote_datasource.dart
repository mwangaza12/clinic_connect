import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/facility_info.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/constants/storage_keys.dart';
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
  final FlutterSecureStorage secureStorage;

  AuthRemoteDatasourceImpl({
    required this.firebaseAuth,
    required this.firestore,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Sign in with Firebase Auth
      final credential =
          await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Fetch user profile from this facility's Firestore
      final userDoc = await FirebaseConfig.facilityDb
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw ServerException('User profile not found');
      }

      final data = userDoc.data()!;
      data['id'] = credential.user!.uid;

      final user = UserModel.fromFirestore(data);

      // 3. Set facility info globally after user is loaded
      FacilityInfo().set(
        facilityId: user.facilityId,
        facilityName: user.facilityName,
        facilityCounty: '',
      );

      // 4. Persist facility credentials so HieApiService can attach
      //    X-Facility-Id + X-Api-Key headers on every gateway request.
      //    The hie_api_key is provisioned by MoH and stored on the user
      //    document in the facility's own Firestore.
      await secureStorage.write(
        key:   StorageKeys.facilityId,
        value: user.facilityId,
      );
      if (user.hieApiKey != null && user.hieApiKey!.isNotEmpty) {
        await secureStorage.write(
          key:   StorageKeys.facilityApiKey,
          value: user.hieApiKey,
        );
      }

      // NOTE: removed sharedDb.facilities write — the facility registry is
      // owned by the HIE Gateway (registered via MoH admin panel). This app
      // should not write to the gateway's Firebase directly.

      return user;
    } on FirebaseAuthException catch (e) {
      throw ServerException(e.message ?? 'Login failed');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Login failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await firebaseAuth.signOut();
      FacilityInfo().clear();
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

      final user = UserModel.fromJson(userData);

      FacilityInfo().set(
        facilityId: user.facilityId,
        facilityName: user.facilityName,
        facilityCounty: '',
      );

      // Refresh credentials in secure storage (handles app restart)
      await secureStorage.write(
        key:   StorageKeys.facilityId,
        value: user.facilityId,
      );
      if (user.hieApiKey != null && user.hieApiKey!.isNotEmpty) {
        await secureStorage.write(
          key:   StorageKeys.facilityApiKey,
          value: user.hieApiKey,
        );
      }

      return user;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
