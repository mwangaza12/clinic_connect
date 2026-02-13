// lib/features/referral/data/datasources/referral_remote_datasource_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/referral.dart';
import '../models/referral_model.dart';
import 'referral_remote_datasource.dart';

class ReferralRemoteDatasourceImpl implements ReferralRemoteDatasource {
  // Uses facility's OWN Firestore for referral records
  FirebaseFirestore get _facilityDb => FirebaseConfig.facilityDb;

  // Uses SHARED index for cross-facility communication
  FirebaseFirestore get _sharedDb => FirebaseConfig.sharedDb;

  @override
  Future<ReferralModel> createReferral(ReferralModel referral) async {
    try {
      // 1. Save full referral in OWN facility DB
      await _facilityDb
          .collection('referrals')
          .doc(referral.id)
          .set(referral.toFirestore());

      // 2. Save copy in shared index for receiving facility
      await _sharedDb
          .collection('referral_copies')
          .doc(referral.id)
          .set(referral.toFirestore());

      // 3. Post a lightweight notification in SHARED index
      await _sharedDb.collection('referral_notifications').doc(referral.id).set(
        {
          'referral_id': referral.id,
          'from_facility_id': referral.fromFacilityId,
          'from_facility_name': referral.fromFacilityName,
          'to_facility_id': referral.toFacilityId,
          'to_facility_name': referral.toFacilityName,
          'patient_nupi': referral.patientNupi,
          'patient_name': referral.patientName,
          'priority': referral.priority.name,
          'status': referral.status.name,
          'reason': referral.reason, // Now works!
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        },
      );

      return referral;
    } catch (e) {
      throw ServerException('Failed to create referral: $e');
    }
  }

  @override
  Future<List<ReferralModel>> getOutgoingReferrals(String facilityId) async {
    try {
      final query = await _facilityDb
          .collection('referrals')
          .where('from_facility_id', isEqualTo: facilityId)
          .orderBy('created_at', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReferralModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to get outgoing referrals: $e');
    }
  }

  @override
  Future<List<ReferralModel>> getIncomingReferrals(String facilityId) async {
    try {
      final notifications = await _sharedDb
          .collection('referral_notifications')
          .where('to_facility_id', isEqualTo: facilityId)
          .orderBy('created_at', descending: true)
          .get();

      if (notifications.docs.isEmpty) return [];

      final referrals = <ReferralModel>[];
      for (final doc in notifications.docs) {
        final notificationData = doc.data();
        final referralId = notificationData['referral_id'] as String;

        final copyDoc = await _sharedDb
            .collection('referral_copies')
            .doc(referralId)
            .get();

        if (copyDoc.exists) {
          final data = copyDoc.data()!;
          data['id'] = copyDoc.id;
          referrals.add(ReferralModel.fromFirestore(data));
        } else {
          referrals.add(
            ReferralModel.fromNotification(notificationData),
          ); // Now works!
        }
      }

      return referrals;
    } catch (e) {
      throw ServerException('Failed to get incoming referrals: $e');
    }
  }

  @override
  Future<ReferralModel> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? feedbackNotes,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'status': status.name,
        'updated_at': Timestamp.fromDate(now),
        'feedback_notes': ?feedbackNotes,
        if (status == ReferralStatus.accepted)
          'accepted_at': Timestamp.fromDate(now),
        if (status == ReferralStatus.rejected)
          'rejected_at': Timestamp.fromDate(now), // Now works!
        if (status == ReferralStatus.completed)
          'completed_at': Timestamp.fromDate(now),
      };

      // Update in own DB
      try {
        await _facilityDb
            .collection('referrals')
            .doc(referralId)
            .update(updateData);
      } catch (_) {}

      // Update in shared index
      await _sharedDb
          .collection('referral_copies')
          .doc(referralId)
          .update(updateData);

      await _sharedDb
          .collection('referral_notifications')
          .doc(referralId)
          .update({
            'status': status.name,
            'updated_at': Timestamp.fromDate(now),
          });

      if (status == ReferralStatus.accepted) {
        final referralDoc = await _sharedDb
            .collection('referral_copies')
            .doc(referralId)
            .get();

        if (referralDoc.exists) {
          await _facilityDb
              .collection('referrals')
              .doc(referralId)
              .set(referralDoc.data()!);
        }
      }

      return getReferral(referralId);
    } catch (e) {
      throw ServerException('Failed to update referral: $e');
    }
  }

  @override
  Future<ReferralModel> getReferral(String referralId) async {
    try {
      final localDoc = await _facilityDb
          .collection('referrals')
          .doc(referralId)
          .get();

      if (localDoc.exists) {
        final data = localDoc.data()!;
        data['id'] = localDoc.id;
        return ReferralModel.fromFirestore(data);
      }

      final sharedDoc = await _sharedDb
          .collection('referral_copies')
          .doc(referralId)
          .get();

      if (!sharedDoc.exists) {
        throw ServerException('Referral not found');
      }

      final data = sharedDoc.data()!;
      data['id'] = sharedDoc.id;
      return ReferralModel.fromFirestore(data);
    } catch (e) {
      throw ServerException('Failed to get referral: $e');
    }
  }

  @override
  Future<List<ReferralModel>> searchReferralsByPatient(
    String patientNupi,
  ) async {
    try {
      final query = await _facilityDb
          .collection('referrals')
          .where('patient_nupi', isEqualTo: patientNupi)
          .orderBy('created_at', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReferralModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to search referrals: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getReferralStats(String facilityId) async {
    try {
      final outgoingQuery = await _facilityDb
          .collection('referrals')
          .where('from_facility_id', isEqualTo: facilityId)
          .get();

      final incomingQuery = await _sharedDb
          .collection('referral_notifications')
          .where('to_facility_id', isEqualTo: facilityId)
          .get();

      int pending = 0;
      int accepted = 0;
      int rejected = 0;
      int completed = 0;

      for (final doc in outgoingQuery.docs) {
        final status = doc.data()['status'];
        if (status == 'pending') {
          pending++;
        } else if (status == 'accepted') {
          accepted++;
        } else if (status == 'rejected')
          {rejected++;}
        else if (status == 'completed')
          {completed++;}
      }

      return {
        'total_outgoing': outgoingQuery.docs.length,
        'total_incoming': incomingQuery.docs.length,
        'pending': pending,
        'accepted': accepted,
        'rejected': rejected,
        'completed': completed,
      };
    } catch (e) {
      throw ServerException('Failed to get referral stats: $e');
    }
  }
}
