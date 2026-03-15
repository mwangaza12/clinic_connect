// lib/features/referral/data/datasources/referral_remote_datasource_impl.dart
//
// OFFLINE-FIRST REFERRAL FLOW:
//
//   createReferral:
//     1. Save to SQLite immediately (always succeeds)
//     2. Enqueue Firestore sync  (SyncEntityType.referral)
//     3. Enqueue HIE/blockchain  (SyncEntityType.hieReferral)
//     Online → both queues are flushed within 500 ms.
//     Offline → both run automatically on reconnect.
//
//   getOutgoingReferrals / getIncomingReferrals:
//     Online  → Firestore / HIE Gateway
//     Offline → SQLite

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/backend_api_service.dart';
import '../../../../core/sync/connectivity_manager.dart';
import '../../../../core/sync/sync_manager.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../../domain/entities/referral.dart';
import '../models/referral_model.dart';
import 'referral_remote_datasource.dart';

class ReferralRemoteDatasourceImpl implements ReferralRemoteDatasource {
  FirebaseFirestore get _facilityDb => FirebaseConfig.facilityDb;
  final _dbHelper  = DatabaseHelper();
  final _conn      = ConnectivityManager();

  // ── CREATE ─────────────────────────────────────────────────────

  @override
  Future<ReferralModel> createReferral(ReferralModel referral) async {
    try {
      // 1. Save to SQLite — always works, even offline
      final db = await _dbHelper.database;
      await db.insert('referrals', _toSqlite(referral),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Enqueue Firestore sync
      await SyncManager().enqueue(
        entityType: SyncEntityType.referral,
        entityId:   referral.id,
        operation:  SyncOperation.create,
        payload:    _toSqlitePayload(referral),
      );

      // 3. Enqueue HIE / AfyaChain sync
      await SyncManager().enqueue(
        entityType: SyncEntityType.hieReferral,
        entityId:   'hie_${referral.id}',
        operation:  SyncOperation.create,
        payload: {
          'referralId':       referral.id,
          'patientNupi':      referral.patientNupi,
          'patientName':      referral.patientName,
          'fromFacilityId':   referral.fromFacilityId,
          'fromFacilityName': referral.fromFacilityName,
          'toFacilityId':     referral.toFacilityId,
          'toFacilityName':   referral.toFacilityName,
          'reason':           referral.reason,
          'priority':         referral.priority.name,
          'clinicalNotes':    referral.clinicalNotes,
          'createdBy':        referral.createdBy,
          'createdByName':    referral.createdByName,
          'accessToken':      '',
        },
      );

      return referral;
    } catch (e) {
      throw ServerException('Failed to create referral: $e');
    }
  }

  // ── OUTGOING ───────────────────────────────────────────────────

  @override
  Future<List<ReferralModel>> getOutgoingReferrals(
      String facilityId) async {
    final online = await _conn.checkConnectivity();
    if (!online) return _getLocalOutgoing(facilityId);

    try {
      // Query via facility backend → HIE chain (source of truth for outgoing referrals).
      // Local Firestore only has referrals created on THIS install;
      // the chain has all of them across reinstalls.
      final backend = await BackendApiService.instanceAsync;
      final result = await backend.getOutgoingReferrals(facilityId: facilityId);

      if (result.success) {
        final list = result.data?['referrals'] as List<dynamic>? ?? [];
        final referrals = list
            .map((r) => ReferralModel.fromGateway(r as Map<String, dynamic>))
            .toList();
        // Cache locally
        for (final r in referrals) {
          try {
            final db = await _dbHelper.database;
            await db.insert('referrals', _toSqlite(r),
                conflictAlgorithm: ConflictAlgorithm.replace);
          } catch (_) {}
        }
        return referrals;
      }
    } catch (_) {}
    return _getLocalOutgoing(facilityId);
  }

  Future<List<ReferralModel>> _getLocalOutgoing(
      String facilityId) async {
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('referrals',
          where:   'from_facility_id = ?',
          whereArgs: [facilityId],
          orderBy: 'created_at DESC');
      return rows.map(_fromSqlite).toList();
    } catch (_) {
      return [];
    }
  }

  // ── INCOMING ───────────────────────────────────────────────────

  @override
  Future<List<ReferralModel>> getIncomingReferrals(
      String facilityId) async {
    final online = await _conn.checkConnectivity();
    if (!online) return _getLocalIncoming(facilityId);

    try {
      final backend = await BackendApiService.instanceAsync;
      final result = await backend.getIncomingReferrals(facilityId: facilityId);

      if (!result.success) {
        debugPrint(
            '[Backend] incoming referrals failed — using local cache');
        return _getLocalIncoming(facilityId);
      }

      final list     = result.data?['referrals'] as List<dynamic>? ?? [];
      final referrals = list
          .map((r) =>
              ReferralModel.fromGateway(r as Map<String, dynamic>))
          .toList();

      // Cache each incoming referral locally for offline access
      for (final r in referrals) {
        try {
          final db = await _dbHelper.database;
          await db.insert('referrals', _toSqlite(r),
              conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      return referrals;
    } catch (e) {
      debugPrint('[HIE] incoming referrals exception: $e — using local');
      return _getLocalIncoming(facilityId);
    }
  }

  Future<List<ReferralModel>> _getLocalIncoming(
      String facilityId) async {
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('referrals',
          where:     'to_facility_id = ?',
          whereArgs: [facilityId],
          orderBy:   'created_at DESC');
      return rows.map(_fromSqlite).toList();
    } catch (_) {
      return [];
    }
  }

  // ── STATUS UPDATE ──────────────────────────────────────────────

  @override
  Future<ReferralModel> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? feedbackNotes,
  }) async {
    final now = DateTime.now();

    // Always update SQLite first
    try {
      final db = await _dbHelper.database;
      await db.update(
        'referrals',
        {
          'status':     status.name,
          'updated_at': now.toIso8601String(),
          if (feedbackNotes != null) 'clinical_notes': feedbackNotes,
          if (status == ReferralStatus.accepted)
            'accepted_at': now.toIso8601String(),
          if (status == ReferralStatus.rejected)
            'rejected_at': now.toIso8601String(),
          if (status == ReferralStatus.completed)
            'completed_at': now.toIso8601String(),
        },
        where:     'id = ?',
        whereArgs: [referralId],
      );
    } catch (_) {}

    // Firestore update — best-effort (local facility only)
    final online = await _conn.checkConnectivity();
    if (online) {
      try {
        final updateData = <String, dynamic>{
          'status':     status.name,
          'updated_at': Timestamp.fromDate(now),
          if (feedbackNotes != null) 'feedback_notes': feedbackNotes,
          if (status == ReferralStatus.accepted)
            'accepted_at': Timestamp.fromDate(now),
          if (status == ReferralStatus.rejected)
            'rejected_at': Timestamp.fromDate(now),
          if (status == ReferralStatus.completed)
            'completed_at': Timestamp.fromDate(now),
        };
        await _facilityDb
            .collection('referrals')
            .doc(referralId)
            .set(updateData, SetOptions(merge: true));
      } catch (_) {}

      // Post status update via backend → HIE chain so the SENDING facility
      // can see it when they next query /api/referrals/outgoing/:id
      try {
        final backend = await BackendApiService.instanceAsync;
        await backend.updateReferralStatus(
          referralId: referralId,
          status:     status.name,
          notes:      feedbackNotes,
        );
        debugPrint('[Referral] Backend status updated → ${status.name}');
      } catch (e) {
        debugPrint('[Referral] Backend status update failed (non-critical): $e');
      }
    }

    return getReferral(referralId);
  }

  // ── GET ONE ────────────────────────────────────────────────────

  @override
  Future<ReferralModel> getReferral(String referralId) async {
    // Try SQLite first — always available
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('referrals',
          where: 'id = ?', whereArgs: [referralId], limit: 1);
      if (rows.isNotEmpty) return _fromSqlite(rows.first);
    } catch (_) {}

    // Firestore fallback
    try {
      final doc = await _facilityDb
          .collection('referrals')
          .doc(referralId)
          .get();
      if (doc.exists) {
        final data = doc.data()!..['id'] = doc.id;
        return ReferralModel.fromFirestore(data);
      }
    } catch (_) {}

    throw ServerException('Referral not found: $referralId');
  }

  // ── SEARCH BY PATIENT ──────────────────────────────────────────

  @override
  Future<List<ReferralModel>> searchReferralsByPatient(
      String patientNupi) async {
    // SQLite first (offline-safe)
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('referrals',
          where:     'patient_nupi = ?',
          whereArgs: [patientNupi],
          orderBy:   'created_at DESC');
      if (rows.isNotEmpty) return rows.map(_fromSqlite).toList();
    } catch (_) {}

    // Firestore fallback when online
    try {
      final query = await _facilityDb
          .collection('referrals')
          .where('patient_nupi', isEqualTo: patientNupi)
          .orderBy('created_at', descending: true)
          .get();
      return query.docs.map((doc) {
        final data = doc.data()..['id'] = doc.id;
        return ReferralModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to search referrals: $e');
    }
  }

  // ── STATS ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getReferralStats(
      String facilityId) async {
    // Read from SQLite for local counts (always available)
    int pending = 0, accepted = 0, rejected = 0, completed = 0,
        total = 0;
    try {
      final db   = await _dbHelper.database;
      final rows = await db.query('referrals',
          where:     'from_facility_id = ?',
          whereArgs: [facilityId]);
      total = rows.length;
      for (final r in rows) {
        switch (r['status'] as String?) {
          case 'pending':   pending++;   break;
          case 'accepted':  accepted++;  break;
          case 'rejected':  rejected++;  break;
          case 'completed': completed++; break;
        }
      }
    } catch (_) {}

    // Incoming count — via backend, best-effort
    int incomingCount = 0;
    try {
      final backend = await BackendApiService.instanceAsync;
      final result = await backend.getIncomingReferrals(facilityId: facilityId);
      if (result.success) {
        incomingCount = (result.data?['count'] as int?) ?? 0;
      }
    } catch (_) {}

    return {
      'total_outgoing': total,
      'total_incoming': incomingCount,
      'pending':   pending,
      'accepted':  accepted,
      'rejected':  rejected,
      'completed': completed,
    };
  }

  // ── SQLite serialisation helpers ───────────────────────────────

  Map<String, dynamic> _toSqlite(ReferralModel r) => {
        'id':                r.id,
        'patient_nupi':      r.patientNupi,
        'patient_name':      r.patientName,
        'from_facility_id':  r.fromFacilityId,
        'from_facility_name': r.fromFacilityName,
        'to_facility_id':    r.toFacilityId,
        'to_facility_name':  r.toFacilityName,
        'reason':            r.reason,
        'priority':          r.priority.name,
        'status':            r.status.name,
        'clinical_notes':    r.clinicalNotes,
        'created_by':        r.createdBy,
        'created_by_name':   r.createdByName,
        'sync_status':       'pending',
        'created_at':        r.createdAt.toIso8601String(),
        'updated_at':        (r.updatedAt ?? r.createdAt).toIso8601String(),
      };

  /// Payload for SyncManager (Firestore path).
  /// Timestamps must be stored as ISO strings in the queue then
  /// converted back to Timestamps by _toFirestorePayload in SyncManager.
  Map<String, dynamic> _toSqlitePayload(ReferralModel r) =>
      _toSqlite(r)..remove('sync_status');

  ReferralModel _fromSqlite(Map<String, dynamic> row) {
    DateTime? _parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v as String);

    return ReferralModel(
      id:              row['id']               as String,
      patientNupi:     row['patient_nupi']     as String,
      patientName:     row['patient_name']     as String,
      fromFacilityId:  row['from_facility_id'] as String,
      fromFacilityName: row['from_facility_name'] as String,
      toFacilityId:    row['to_facility_id']   as String,
      toFacilityName:  row['to_facility_name'] as String,
      reason:          row['reason']           as String,
      priority: ReferralPriority.values.firstWhere(
          (e) => e.name == (row['priority'] as String? ?? 'normal'),
          orElse: () => ReferralPriority.normal),
      status: ReferralStatus.values.firstWhere(
          (e) => e.name == (row['status'] as String? ?? 'pending'),
          orElse: () => ReferralStatus.pending),
      clinicalNotes:   row['clinical_notes']   as String?,
      createdBy:       row['created_by']       as String,
      createdByName:   row['created_by_name']  as String,
      createdAt:       DateTime.parse(row['created_at'] as String),
      updatedAt:       _parseDate(row['updated_at']),
    );
  }
}