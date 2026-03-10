import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_connect/core/sync/conflict_resolver.dart';

void main() {
  group('ConflictResolver', () {
    // ─────────────────────────────────────────
    // No conflict — local is newer
    // ─────────────────────────────────────────
    test('returns local record when local is newer than server', () {
      final local = {
        'id': 'p1',
        'first_name': 'Jane',
        'updated_at': '2025-01-02T10:00:00.000Z',
      };
      final server = {
        'id': 'p1',
        'first_name': 'Jane',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'patients',
      );

      expect(result.resolvedData['first_name'], equals('Jane'));
      expect(result.requiresReview, isFalse);
    });

    // ─────────────────────────────────────────
    // Patient — clinical fields preserved
    // ─────────────────────────────────────────
    test('patient: preserves local clinical fields when server is newer', () {
      final local = {
        'id': 'p1',
        'first_name': 'Jane',
        'allergies': '["Penicillin"]',
        'chronic_conditions': '["Diabetes"]',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };
      final server = {
        'id': 'p1',
        'first_name': 'Jane Updated',
        'allergies': null,
        'chronic_conditions': null,
        'updated_at': '2025-01-02T10:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'patients',
      );

      // Demographic: server wins
      expect(result.resolvedData['first_name'], equals('Jane Updated'));
      // Clinical: local wins
      expect(result.resolvedData['allergies'], equals('["Penicillin"]'));
      expect(result.resolvedData['chronic_conditions'], equals('["Diabetes"]'));
      // Should flag for review since clinical data differed
      expect(result.requiresReview, isTrue);
    });

    test('patient: no review needed when clinical fields are identical', () {
      final local = {
        'id': 'p1',
        'allergies': '["Penicillin"]',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };
      final server = {
        'id': 'p1',
        'allergies': '["Penicillin"]',
        'updated_at': '2025-01-02T10:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'patients',
      );

      expect(result.requiresReview, isFalse);
    });

    // ─────────────────────────────────────────
    // Encounter — finished status is protected
    // ─────────────────────────────────────────
    test('encounter: flags for review when server is finished but local is not', () {
      final local = {
        'id': 'e1',
        'status': 'in-progress',
        'diagnoses': '[{"code":"J00","description":"Cold"}]',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };
      final server = {
        'id': 'e1',
        'status': 'finished',
        'diagnoses': '[]',
        'updated_at': '2025-01-02T10:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'encounters',
      );

      expect(result.resolvedData['status'], equals('finished'));
      expect(result.requiresReview, isTrue);
    });

    test('encounter: local clinical data fills in empty server fields', () {
      final local = {
        'id': 'e1',
        'status': 'in-progress',
        'diagnoses': '[{"code":"J00","description":"Cold"}]',
        'vitals': '{"temperature":37.5}',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };
      final server = {
        'id': 'e1',
        'status': 'in-progress',
        'diagnoses': '[]',
        'vitals': null,
        'updated_at': '2025-01-02T10:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'encounters',
      );

      expect(
        result.resolvedData['diagnoses'],
        equals('[{"code":"J00","description":"Cold"}]'),
      );
      expect(result.resolvedData['vitals'], equals('{"temperature":37.5}'));
    });

    // ─────────────────────────────────────────
    // Referral — status never goes backwards
    // ─────────────────────────────────────────
    test('referral: keeps higher status when local has progressed further', () {
      final local = {
        'id': 'r1',
        'status': 'accepted',
        'accepted_at': '2025-01-02T09:00:00.000Z',
        'clinical_notes': 'Patient stable',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };
      final server = {
        'id': 'r1',
        'status': 'pending',
        'clinical_notes': '',
        'updated_at': '2025-01-02T10:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'referrals',
      );

      // Status should not go backwards from accepted to pending
      expect(result.resolvedData['status'], equals('accepted'));
      expect(result.resolvedData['accepted_at'], isNotNull);
    });

    test('referral: merges clinical notes from both sides', () {
      final local = {
        'id': 'r1',
        'status': 'pending',
        'clinical_notes': 'Local note added offline',
        'updated_at': '2025-01-01T08:00:00.000Z',
      };
      final server = {
        'id': 'r1',
        'status': 'pending',
        'clinical_notes': 'Server note from another user',
        'updated_at': '2025-01-02T10:00:00.000Z',
      };

      final result = ConflictResolver.resolve(
        localRecord: local,
        serverRecord: server,
        entityType: 'referrals',
      );

      expect(
        result.resolvedData['clinical_notes'],
        contains('Server note from another user'),
      );
      expect(
        result.resolvedData['clinical_notes'],
        contains('Local note added offline'),
      );
    });
  });
}