import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Each facility's own Firebase app (default)
  static FirebaseApp get facilityApp => Firebase.app();

  // Shared index Firebase app (secondary)
  static FirebaseApp? _sharedApp;

  static Future<void> initSharedIndex() async {
    try {
      // Try to get existing app
      _sharedApp = Firebase.app('shared_index');
    } catch (_) {
      // Initialize secondary Firebase app pointing to shared index project
      _sharedApp = await Firebase.initializeApp(
        name: 'shared_index',
        options: const FirebaseOptions(
          // ─── SHARED INDEX PROJECT CREDENTIALS ───
          // Get these from your Firebase Console
          apiKey: 'AIzaSyCQS_NHQY6eM36qz4Q-uabXC9LQ-sjclTU',
          appId: '1:888320148562:android:4084ca8a2dccbc825c8b8b',
          messagingSenderId: '888320148562', // ← FIXED: This is your project number
          projectId: 'clinicconnect-shared-index',
          storageBucket: 'clinicconnect-shared-index.appspot.com', // ← FIXED format
        ),
      );
    }
  }

  // Firestore for THIS facility's own data
  static FirebaseFirestore get facilityDb =>
      FirebaseFirestore.instanceFor(app: facilityApp);

  // Firestore for shared index (facility registry + NUPI index)
  static FirebaseFirestore get sharedDb {
    if (_sharedApp == null) {
      throw Exception(
          'Shared index not initialized. Call initSharedIndex() first.');
    }
    return FirebaseFirestore.instanceFor(app: _sharedApp!);
  }
}