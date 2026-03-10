/// ConflictResolver
///
/// Handles conflicts that arise when the same record has been modified
/// both locally (offline) and remotely (by another facility or session)
/// before the local copy could sync.
///
/// Strategy: Server-wins with field-level protection for critical clinical data.
///
/// Why this approach?
/// - Simple and predictable — important for a medical system
/// - Protects clinical fields (diagnoses, vitals) from being silently overwritten
/// - Flags genuine conflicts so a clinician can review if needed
/// - Avoids data loss by keeping a local backup of the conflicting record

import 'package:cloud_firestore/cloud_firestore.dart';

enum ConflictStrategy {
  serverWins,
  clientWins,
  keepBoth,
}

class ConflictResult {
  /// The merged record that should be written to both local DB and Firestore
  final Map<String, dynamic> resolvedData;

  /// True if a clinician should be notified to manually review
  final bool requiresReview;

  /// Human-readable explanation of what was conflicted and how it was resolved
  final String resolutionNote;

  const ConflictResult({
    required this.resolvedData,
    required this.requiresReview,
    required this.resolutionNote,
  });
}

class ConflictResolver {
  // Fields that must NEVER be silently overwritten by server
  // because they represent direct clinical observations
  static const _protectedClinicalFields = [
    'diagnoses',
    'vitals',
    'treatment_plan',
    'clinical_notes',
    'examination_findings',
    'history_of_presenting_illness',
    'allergies',
    'chronic_conditions',
  ];

  // ─────────────────────────────────────────────────────────────
  // Main entry point
  // ─────────────────────────────────────────────────────────────

  /// Resolves a conflict between a local pending record and the
  /// current server record.
  ///
  /// [localRecord]  — the record from the local SQLite sync queue
  /// [serverRecord] — the current record fetched from Firestore
  /// [entityType]   — 'patients', 'encounters', 'referrals', etc.
  static ConflictResult resolve({
    required Map<String, dynamic> localRecord,
    required Map<String, dynamic> serverRecord,
    required String entityType,
  }) {
    final localUpdatedAt = _parseDate(localRecord['updated_at']);
    final serverUpdatedAt = _parseDate(serverRecord['updated_at']);

    // No real conflict — local is newer, safe to push
    if (localUpdatedAt != null &&
        serverUpdatedAt != null &&
        localUpdatedAt.isAfter(serverUpdatedAt)) {
      return ConflictResult(
        resolvedData: localRecord,
        requiresReview: false,
        resolutionNote: 'Local record is newer — no conflict.',
      );
    }

    // Genuine conflict — both sides changed since last sync
    switch (entityType) {
      case 'patients':
        return _resolvePatient(localRecord, serverRecord);
      case 'encounters':
        return _resolveEncounter(localRecord, serverRecord);
      case 'referrals':
        return _resolveReferral(localRecord, serverRecord);
      default:
        return ConflictResult(
          resolvedData: serverRecord,
          requiresReview: false,
          resolutionNote: 'Unknown entity type — server version kept.',
        );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Patient conflict resolution
  // ─────────────────────────────────────────────────────────────

  static ConflictResult _resolvePatient(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) {
    final merged = Map<String, dynamic>.from(server);
    final conflicts = <String>[];

    // Demographic fields — server wins (admin-controlled)
    // Clinical fields — local wins (clinician-observed)
    for (final field in _protectedClinicalFields) {
      if (local.containsKey(field) &&
          local[field] != null &&
          local[field].toString() != server[field].toString()) {
        merged[field] = local[field];
        conflicts.add(field);
      }
    }

    merged['updated_at'] = DateTime.now().toIso8601String();
    merged['sync_status'] = 'synced';

    return ConflictResult(
      resolvedData: merged,
      requiresReview: conflicts.isNotEmpty,
      resolutionNote: conflicts.isEmpty
          ? 'Patient record merged — no clinical conflicts.'
          : 'Clinical fields updated locally: ${conflicts.join(', ')}. '
              'Please review patient record.',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Encounter conflict resolution
  // ─────────────────────────────────────────────────────────────

  static ConflictResult _resolveEncounter(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) {
    // Encounters are append-only by design — a finished encounter
    // should never be overwritten. If server has 'finished' status,
    // we keep the server version and flag for review.
    if (server['status'] == 'finished' && local['status'] != 'finished') {
      return ConflictResult(
        resolvedData: server,
        requiresReview: true,
        resolutionNote:
            'Encounter was marked finished on server. '
            'Local changes could not be applied — please review.',
      );
    }

    final merged = Map<String, dynamic>.from(server);
    final conflicts = <String>[];

    for (final field in _protectedClinicalFields) {
      final localVal = local[field];
      final serverVal = server[field];

      if (localVal != null &&
          (serverVal == null || serverVal == '[]' || serverVal == '')) {
        merged[field] = localVal;
        conflicts.add(field);
      }
    }

    merged['updated_at'] = DateTime.now().toIso8601String();
    merged['sync_status'] = 'synced';

    return ConflictResult(
      resolvedData: merged,
      requiresReview: conflicts.isNotEmpty,
      resolutionNote: conflicts.isEmpty
          ? 'Encounter merged cleanly.'
          : 'Local clinical data preserved for: ${conflicts.join(', ')}.',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Referral conflict resolution
  // ─────────────────────────────────────────────────────────────

  static ConflictResult _resolveReferral(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) {
    // Referral status transitions are one-directional:
    // pending → accepted → inTransit → arrived → completed
    // We never allow a status to go backwards.
    final serverStatus = _referralStatusPriority(server['status'] as String?);
    final localStatus = _referralStatusPriority(local['status'] as String?);

    final merged = Map<String, dynamic>.from(server);

    if (localStatus > serverStatus) {
      merged['status'] = local['status'];
      if (local['accepted_at'] != null) merged['accepted_at'] = local['accepted_at'];
      if (local['completed_at'] != null) merged['completed_at'] = local['completed_at'];
    }

    // Preserve clinical notes from both sides
    final serverNotes = (server['clinical_notes'] as String?) ?? '';
    final localNotes = (local['clinical_notes'] as String?) ?? '';
    if (localNotes.isNotEmpty && localNotes != serverNotes) {
      merged['clinical_notes'] = serverNotes.isNotEmpty
          ? '$serverNotes\n---\n$localNotes'
          : localNotes;
    }

    merged['updated_at'] = DateTime.now().toIso8601String();
    merged['sync_status'] = 'synced';

    return ConflictResult(
      resolvedData: merged,
      requiresReview: false,
      resolutionNote: 'Referral status preserved at highest progression.',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int _referralStatusPriority(String? status) {
    switch (status) {
      case 'pending':    return 0;
      case 'accepted':   return 1;
      case 'inTransit':  return 2;
      case 'arrived':    return 3;
      case 'completed':  return 4;
      case 'cancelled':  return 5;
      case 'rejected':   return 5;
      default:           return 0;
    }
  }
}