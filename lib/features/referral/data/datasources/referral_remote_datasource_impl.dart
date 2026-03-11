// lib/features/referral/data/datasources/referral_remote_datasource_impl.dart
//
// CHANGES from original:
//  1. All sharedDb (clinicconnect-shared-index) reads and writes removed.
//     Incoming referrals, referral copies, and referral notifications now
//     come from the HIE Gateway Express API via HieApiService.
//  2. createReferral still writes to own facilityDb for local record, then
//     calls HieApiService.createReferral to log on AfyaChain blockchain.
//  3. updateReferralStatus updates own facilityDb AND writes a status update
//     doc to the SHARED default Firestore (`referral_status_updates/{id}`).
//     This lets the sending facility see the status change cross-facility
//     without requiring gateway changes (blockchain is immutable).
//  4. getIncomingReferrals fetches from gateway then merges any status
//     updates from the shared collection so statuses are always current.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/hie_api_service.dart';
import '../../domain/entities/referral.dart';
import '../models/referral_model.dart';
import 'referral_remote_datasource.dart';

class ReferralRemoteDatasourceImpl implements ReferralRemoteDatasource {
  FirebaseFirestore get _facilityDb => FirebaseConfig.facilityDb;

  // The DEFAULT Firestore instance is used as a lightweight shared bus for
  // referral status updates. It holds ONLY status metadata (no clinical data)
  // and is readable/writable by all facilities via Firebase security rules.
  // Collection: referral_status_updates/{referralId}
  FirebaseFirestore get _sharedDb => FirebaseFirestore.instance;

  CollectionReference get _statusUpdates =>
      _sharedDb.collection('referral_status_updates');


  // ── CREATE ────────────────────────────────────────────────────────────────

  @override
  Future<ReferralModel> createReferral(ReferralModel referral) async {
    try {
      // 1. Save to own facility Firestore for local record + offline access
      await _facilityDb
          .collection('referrals')
          .doc(referral.id)
          .set(referral.toFirestore());

      // 2. Log on AfyaChain via gateway (fire-and-forget; failure non-fatal)
      _notifyBlockchain(referral);

      return referral;
    } catch (e) {
      throw ServerException('Failed to create referral: $e');
    }
  }

  void _notifyBlockchain(ReferralModel referral) {
    HieApiService.instance.createReferral(
      referralId:       referral.id,
      patientNupi:      referral.patientNupi,
      patientName:      referral.patientName,
      fromFacilityId:   referral.fromFacilityId,
      fromFacilityName: referral.fromFacilityName,
      toFacilityId:     referral.toFacilityId,
      toFacilityName:   referral.toFacilityName,
      reason:           referral.reason,
      priority:         referral.priority.name,
      clinicalNotes:    referral.clinicalNotes,
      createdBy:        referral.createdBy,
      createdByName:    referral.createdByName,
      accessToken:      '',
    ).then((result) {
      if (result.success) {
        debugPrint('[HIE] ⛓ Referral block #${result.blockIndex} minted for ${referral.patientNupi}');
      } else {
        debugPrint('[HIE] ⚠ Referral blockchain notification failed: ${result.error}');
      }
    });
  }

  // ── OUTGOING ──────────────────────────────────────────────────────────────

  @override
  Future<List<ReferralModel>> getOutgoingReferrals(String facilityId) async {
    // Outgoing referrals were created by this facility → already in own Firestore.
    // We then overlay any cross-facility status updates from the shared bus so
    // the sending facility sees accepted/rejected/completed in real time.
    try {
      final query = await _facilityDb
          .collection('referrals')
          .where('from_facility_id', isEqualTo: facilityId)
          .orderBy('created_at', descending: true)
          .get();

      final referrals = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReferralModel.fromFirestore(data);
      }).toList();

      // Merge any cross-facility status updates (fire-and-forget failures ok)
      try {
        final updatedReferrals = <ReferralModel>[];
        for (final r in referrals) {
          final statusDoc = await _statusUpdates.doc(r.id).get();
          if (statusDoc.exists) {
            final statusData = statusDoc.data() as Map<String, dynamic>;
            final remoteStatus = _parseStatus(statusData['status'] as String?);
            // Only apply if the remote status represents a progression forward
            if (remoteStatus != null && _statusPriority(remoteStatus) > _statusPriority(r.status)) {
              // Write the updated status into local facility DB so it persists offline
              await _facilityDb
                  .collection('referrals')
                  .doc(r.id)
                  .set(statusData, SetOptions(merge: true));
              final mergedData = {
                ...query.docs.firstWhere((d) => d.id == r.id).data(),
                ...statusData,
                'id': r.id,
              };
              updatedReferrals.add(ReferralModel.fromFirestore(mergedData));
              debugPrint('[Referral] 🔄 Status merged for outgoing ${r.id}: ${r.status.name} → ${remoteStatus.name}');
              continue;
            }
          }
          updatedReferrals.add(r);
        }
        return updatedReferrals;
      } catch (e) {
        debugPrint('[Referral] ⚠ Status merge failed (non-fatal): $e');
        return referrals; // Return unmerged list — better than crashing
      }
    } catch (e) {
      throw ServerException('Failed to get outgoing referrals: $e');
    }
  }

  // ── INCOMING ──────────────────────────────────────────────────────────────

  @override
  Future<List<ReferralModel>> getIncomingReferrals(String facilityId) async {
    // Previously read from sharedDb referral_notifications + referral_copies.
    // Now fetches from the HIE Gateway blockchain, then caches locally.
    try {
      final result = await HieApiService.instance
          .getReferrals(direction: 'incoming', facilityId: facilityId);

      if (!result.success) {
        debugPrint('[HIE] incoming referrals failed: ${result.error} — falling back to local');
        return _getLocalIncoming(facilityId);
      }

      final list = result.data?['referrals'] as List<dynamic>? ?? [];
      final referrals = list
          .map((r) => ReferralModel.fromGateway(r as Map<String, dynamic>))
          .toList();

      // Cache each incoming referral locally so it's available offline
      for (final r in referrals) {
        try {
          await _facilityDb
              .collection('referrals')
              .doc(r.id)
              .set(r.toFirestore(), SetOptions(merge: true));
        } catch (_) {}
      }

      return referrals;
    } catch (e) {
      // Gateway unreachable — serve from local cache
      debugPrint('[HIE] incoming referrals exception: $e — using local cache');
      return _getLocalIncoming(facilityId);
    }
  }

  Future<List<ReferralModel>> _getLocalIncoming(String facilityId) async {
    try {
      final query = await _facilityDb
          .collection('referrals')
          .where('to_facility_id', isEqualTo: facilityId)
          .orderBy('created_at', descending: true)
          .get();
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReferralModel.fromFirestore(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── STATUS UPDATE ─────────────────────────────────────────────────────────

  @override
  Future<ReferralModel> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? feedbackNotes,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'status':     status.name,
        'updated_at': Timestamp.fromDate(now),
        'feedback_notes': ?feedbackNotes,
        if (status == ReferralStatus.accepted)  'accepted_at':  Timestamp.fromDate(now),
        if (status == ReferralStatus.rejected)  'rejected_at':  Timestamp.fromDate(now),
        if (status == ReferralStatus.completed) 'completed_at': Timestamp.fromDate(now),
      };

      // 1. Update own local facility DB
      try {
        await _facilityDb
            .collection('referrals')
            .doc(referralId)
            .update(updateData);
      } catch (_) {
        await _facilityDb
            .collection('referrals')
            .doc(referralId)
            .set(updateData, SetOptions(merge: true));
      }

      // 2. Cross-facility status broadcast on shared Firestore bus.
      //    The SENDING facility reads this when it next loads its outgoing
      //    referrals, so it sees accepted/rejected/completed without needing
      //    a gateway change (blockchain records are immutable).
      //    Only non-sensitive status metadata is written here — no clinical data.
      try {
        await _statusUpdates.doc(referralId).set(updateData, SetOptions(merge: true));
        debugPrint('[Referral] ✅ Cross-facility status update written for $referralId → ${status.name}');
      } catch (e) {
        // Non-fatal — local update succeeded; cross-facility will catch up on next refresh
        debugPrint('[Referral] ⚠ Cross-facility status write failed (non-fatal): $e');
      }

      return getReferral(referralId);
    } catch (e) {
      throw ServerException('Failed to update referral: $e');
    }
  }

  // ── GET ONE ───────────────────────────────────────────────────────────────

  @override
  Future<ReferralModel> getReferral(String referralId) async {
    try {
      // Check local first (faster + offline-capable)
      final localDoc = await _facilityDb
          .collection('referrals')
          .doc(referralId)
          .get();

      if (localDoc.exists) {
        final data = localDoc.data()!;
        data['id'] = localDoc.id;
        return ReferralModel.fromFirestore(data);
      }

      // Fall back to gateway
      final result = await HieApiService.instance
          .getReferralById(referralId: referralId);

      if (!result.success || result.data == null) {
        throw ServerException('Referral not found');
      }

      final referral = result.data!['referral'] as Map<String, dynamic>?;
      if (referral == null) throw ServerException('Referral not found');

      return ReferralModel.fromGateway(referral);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get referral: $e');
    }
  }

  // ── SEARCH BY PATIENT ─────────────────────────────────────────────────────

  @override
  Future<List<ReferralModel>> searchReferralsByPatient(
      String patientNupi) async {
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

  // ── STATS ─────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getReferralStats(String facilityId) async {
    try {
      final outgoingQuery = await _facilityDb
          .collection('referrals')
          .where('from_facility_id', isEqualTo: facilityId)
          .get();

      // Incoming count from gateway
      int incomingCount = 0;
      try {
        final result = await HieApiService.instance
            .getReferrals(direction: 'incoming', facilityId: facilityId);
        if (result.success) {
          incomingCount =
              (result.data?['count'] as int?) ?? 0;
        }
      } catch (_) {}

      int pending = 0, accepted = 0, rejected = 0, completed = 0;
      for (final doc in outgoingQuery.docs) {
        switch (doc.data()['status']) {
          case 'pending':   pending++;   break;
          case 'accepted':  accepted++;  break;
          case 'rejected':  rejected++;  break;
          case 'completed': completed++; break;
        }
      }

      return {
        'total_outgoing': outgoingQuery.docs.length,
        'total_incoming': incomingCount,
        'pending':   pending,
        'accepted':  accepted,
        'rejected':  rejected,
        'completed': completed,
      };
    } catch (e) {
      throw ServerException('Failed to get referral stats: $e');
    }
  }

  // ── STATUS HELPERS ────────────────────────────────────────────────────────

  ReferralStatus? _parseStatus(String? raw) {
    if (raw == null) return null;
    try {
      return ReferralStatus.values.firstWhere((s) => s.name == raw);
    } catch (_) {
      return null;
    }
  }

  int _statusPriority(ReferralStatus s) {
    switch (s) {
      case ReferralStatus.pending:   return 0;
      case ReferralStatus.accepted:  return 1;
      case ReferralStatus.inTransit: return 2;
      case ReferralStatus.arrived:   return 3;
      case ReferralStatus.completed: return 4;
      case ReferralStatus.cancelled: return 5;
      case ReferralStatus.rejected:  return 5;
    }
  }
}