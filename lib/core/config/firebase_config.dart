// lib/core/config/firebase_config.dart
//
// Dynamic Firebase initialization — one APK, all facilities.
//
// Flow:
//   FIRST LAUNCH (setup wizard):
//     1. Admin enters Facility ID + API Key + Gateway URL
//     2. App calls HieApiService.getFacilityFirebaseConfig()
//     3. Gateway returns this facility's Firebase credentials
//     4. Firebase.initializeApp() called with those credentials
//     5. Credentials saved to secure storage
//     6. Facility name/county saved for display
//
//   EVERY SUBSEQUENT COLD START:
//     1. restoreFromStorage() reads saved credentials
//     2. Firebase.initializeApp() called — no network needed
//     3. App is ready immediately
//
//   RESULT: One APK deployed to Hospital A, B, C, or 1000 more.
//   Each enters their facility code once. Firebase connects to
//   the right project automatically. No rebuild ever needed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'facility_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static const _storage = FlutterSecureStorage();

  // Named app — never collides with any default app
  static const _appName = 'clinicconnect_facility';

  // ── Accessors ─────────────────────────────────────────────────────────────

  /// This facility's Firebase app.
  static FirebaseApp get facilityApp => Firebase.app(_appName);

  /// Firestore for this facility's clinical data.
  static FirebaseFirestore get facilityDb =>
      FirebaseFirestore.instanceFor(app: facilityApp);

  /// Firebase Auth for staff login.
  static FirebaseAuth get auth =>
      FirebaseAuth.instanceFor(app: facilityApp);

  /// True if Firebase has been initialized for this session.
  static bool get isInitialized {
    try {
      Firebase.app(_appName);
      return true;
    } on FirebaseException {
      return false;
    }
  }

  // ── Cold-start restore ────────────────────────────────────────────────────
  //
  // Called once in main() before runApp().
  // Reads saved Firebase credentials and re-initializes without any network.
  // Returns false if credentials have never been saved (first launch).

  static Future<bool> restoreFromStorage() async {
    if (isInitialized) return true; // hot restart guard

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

    // If any required credential is missing, setup is needed
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

    // FIX: restore FacilityInfo so FacilityInfo().facilityId is not empty.
    // Without this, every Firestore query filtering by facility_id returns
    // nothing — patients, encounters, referrals all appear missing on restart.
    final facilityId   = await _storage.read(key: StorageKeys.facilityId)   ?? '';
    final facilityName = await _storage.read(key: StorageKeys.facilityName) ?? '';
    if (facilityId.isNotEmpty) {
      FacilityInfo().set(facilityId: facilityId, facilityName: facilityName);
      debugPrint('[Firebase] Restored → project: $projectId | facility: $facilityId');
    } else {
      debugPrint('[Firebase] Restored → project: $projectId (no facility set yet)');
    }
    return true;
  }

  // ── Setup-time init ───────────────────────────────────────────────────────
  //
  // Called from the setup wizard with credentials from the HIE Gateway.
  // Saves credentials and initializes Firebase.
  // Returns null on success, error message string on failure.

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
      // Delete old app if re-configuring
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

      // Persist all credentials for cold-start restore
      await Future.wait([
        _storage.write(key: StorageKeys.firebaseApiKey,           value: apiKey),
        _storage.write(key: StorageKeys.firebaseAppId,            value: appId),
        _storage.write(key: StorageKeys.firebaseProjectId,        value: projectId),
        _storage.write(key: StorageKeys.firebaseMessagingSenderId, value: messagingSenderId ?? ''),
        _storage.write(key: StorageKeys.firebaseStorageBucket,    value: storageBucket     ?? ''),
        _storage.write(key: StorageKeys.firebaseAuthDomain,       value: authDomain        ?? ''),
        _storage.write(key: StorageKeys.facilityId,               value: facilityId),
        _storage.write(key: StorageKeys.facilityName,             value: facilityName),
        _storage.write(key: StorageKeys.facilityCounty,           value: county            ?? ''),
      ]);

      debugPrint('[Firebase] Initialized → $facilityName ($projectId)');
      return null; // success

    } catch (e) {
      return 'Firebase initialization failed: $e';
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  // ── Anonymous auth for Firestore writes ──────────────────────────────────
  // Some sync_manager versions call this before writing to Firestore
  // to ensure an auth session is active even for unauthenticated writes.
  static Future<void> ensureAnonymousAuth() async {
    try {
      final auth = FirebaseAuth.instanceFor(app: facilityApp);
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
        debugPrint('[Firebase] Anonymous auth established for sync');
      }
    } catch (e) {
      // Non-fatal — Firestore security rules may allow unauthenticated writes
      debugPrint('[Firebase] ensureAnonymousAuth skipped: \$e');
    }
  }

  static Future<void> clear() async {
    if (isInitialized) await facilityApp.delete();
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