// lib/core/config/firebase_config.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static const _storage = FlutterSecureStorage();
  static const _appName = 'clinicconnect_facility';

  // ── Accessors ─────────────────────────────────────────────────────────────

  static FirebaseApp get facilityApp => Firebase.app(_appName);

  static FirebaseFirestore get facilityDb =>
      FirebaseFirestore.instanceFor(app: facilityApp);

  static FirebaseAuth get auth =>
      FirebaseAuth.instanceFor(app: facilityApp);

  static bool get isInitialized {
    try {
      Firebase.app(_appName);
      return true;
    } on FirebaseException {
      return false;
    }
  }

  // ── Anonymous sign-in (PUBLIC) ────────────────────────────────────────────
  //
  // Public so SyncManager can call it before every Firestore write batch,
  // ensuring auth is valid even if the cold-start sign-in failed due to
  // the device not having network yet at that point.
  //
  // Safe to call multiple times — returns immediately if already signed in.

  static Future<void> ensureAnonymousAuth() async {
    if (!isInitialized) return; // Firebase not ready yet — skip silently
    try {
      final firebaseAuth = auth;
      if (firebaseAuth.currentUser != null) {
        debugPrint('[Firebase] Auth already active: '
            '${firebaseAuth.currentUser!.uid}');
        return;
      }
      final credential = await firebaseAuth.signInAnonymously();
      debugPrint('[Firebase] Anonymous sign-in → uid: '
          '${credential.user?.uid}');
    } catch (e) {
      // Non-fatal — Firestore writes will be retried by the sync manager.
      debugPrint('[Firebase] Anonymous sign-in failed (will retry): $e');
    }
  }

  // ── Cold-start restore ────────────────────────────────────────────────────

  static Future<bool> restoreFromStorage() async {
    if (isInitialized) {
      await ensureAnonymousAuth();
      return true;
    }

    final values = await Future.wait([
      _storage.read(key: StorageKeys.firebaseApiKey),
      _storage.read(key: StorageKeys.firebaseProjectId),
      _storage.read(key: StorageKeys.firebaseAppId),
      _storage.read(key: StorageKeys.firebaseMessagingSenderId),
      _storage.read(key: StorageKeys.firebaseStorageBucket),
      _storage.read(key: StorageKeys.firebaseAuthDomain),
    ]);

    final apiKey    = values[0];
    final projectId = values[1];
    final appId     = values[2];

    if (apiKey == null    || apiKey.isEmpty    ||
        projectId == null || projectId.isEmpty ||
        appId == null     || appId.isEmpty) {
      return false;
    }

    await Firebase.initializeApp(
      name: _appName,
      options: FirebaseOptions(
        apiKey:            apiKey,
        appId:             appId,
        messagingSenderId: values[3] ?? '',
        projectId:         projectId,
        storageBucket:     values[4],
        authDomain:        values[5],
      ),
    );

    debugPrint('[Firebase] Restored → project: $projectId');
    await ensureAnonymousAuth();
    return true;
  }

  // ── Setup-time init ───────────────────────────────────────────────────────

  static Future<String?> initFromCredentials({
    required String apiKey,
    required String appId,
    required String projectId,
    required String facilityId,
    required String facilityName,
    String? messagingSenderId,
    String? storageBucket,
    String? authDomain,
    String? county,
    String? subCounty,
  }) async {
    try {
      if (isInitialized) await facilityApp.delete();

      await Firebase.initializeApp(
        name: _appName,
        options: FirebaseOptions(
          apiKey:            apiKey,
          appId:             appId,
          messagingSenderId: messagingSenderId ?? '',
          projectId:         projectId,
          storageBucket:     storageBucket,
          authDomain:        authDomain,
        ),
      );

      await ensureAnonymousAuth();

      await Future.wait([
        _storage.write(key: StorageKeys.firebaseApiKey,            value: apiKey),
        _storage.write(key: StorageKeys.firebaseAppId,             value: appId),
        _storage.write(key: StorageKeys.firebaseProjectId,         value: projectId),
        _storage.write(key: StorageKeys.firebaseMessagingSenderId, value: messagingSenderId ?? ''),
        _storage.write(key: StorageKeys.firebaseStorageBucket,     value: storageBucket     ?? ''),
        _storage.write(key: StorageKeys.firebaseAuthDomain,        value: authDomain        ?? ''),
        _storage.write(key: StorageKeys.facilityId,                value: facilityId),
        _storage.write(key: StorageKeys.facilityName,              value: facilityName),
        _storage.write(key: StorageKeys.facilityCounty,            value: county            ?? ''),
      ]);

      debugPrint('[Firebase] Initialized → $facilityName ($projectId)');
      return null;

    } catch (e) {
      return 'Firebase initialization failed: $e';
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  static Future<void> clear() async {
    if (isInitialized) {
      try { await auth.signOut(); } catch (_) {}
      await facilityApp.delete();
    }
    await Future.wait([
      _storage.delete(key: StorageKeys.firebaseApiKey),
      _storage.delete(key: StorageKeys.firebaseAppId),
      _storage.delete(key: StorageKeys.firebaseProjectId),
      _storage.delete(key: StorageKeys.firebaseMessagingSenderId),
      _storage.delete(key: StorageKeys.firebaseStorageBucket),
      _storage.delete(key: StorageKeys.firebaseAuthDomain),
      _storage.delete(key: StorageKeys.facilityId),
      _storage.delete(key: StorageKeys.facilityName),
      _storage.delete(key: StorageKeys.facilityCounty),
    ]);
  }
}