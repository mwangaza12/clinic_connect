import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// ClinicConnect uses ONE Firebase project (clinic-connect-kenya):
//   - Firebase Auth  → staff login / logout
//   - Firestore      → local clinical data: patients, encounters, referrals, users
//
// The shared cross-facility index (patient NUPI registry, facility registry,
// cross-facility referral routing) is provided by the AfyaLink HIE Gateway
// Express API (HieApiService). The second Firebase project
// "clinicconnect-shared-index" has been removed — all those queries now go
// through the gateway instead of a secondary Firestore instance.

class FirebaseConfig {
  // The facility's own Firebase app (the only app — primary + default)
  static FirebaseApp get facilityApp => Firebase.app();

  // Firestore for THIS facility's own clinical data
  static FirebaseFirestore get facilityDb =>
      FirebaseFirestore.instanceFor(app: facilityApp);
}