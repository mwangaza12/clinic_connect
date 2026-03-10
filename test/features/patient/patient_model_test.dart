import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_connect/features/patient/data/models/patient_model.dart';
import 'package:clinic_connect/features/patient/domain/entities/patient.dart';
import 'dart:convert';

void main() {
  group('PatientModel', () {
    final testPatient = PatientModel(
      id: 'pat-001',
      nupi: 'NUPI-ABC123',
      firstName: 'Amina',
      middleName: 'Wanjiku',
      lastName: 'Kamau',
      gender: 'female',
      dateOfBirth: DateTime(1990, 5, 15),
      phoneNumber: '0712345678',
      email: 'amina@example.com',
      county: 'Nairobi',
      subCounty: 'Westlands',
      ward: 'Parklands',
      village: 'Highridge',
      bloodGroup: 'O+',
      facilityId: 'FAC-001',
      allergies: ['Penicillin', 'Sulfa'],
      chronicConditions: ['Hypertension'],
      nextOfKinName: 'John Kamau',
      nextOfKinPhone: '0723456789',
      nextOfKinRelationship: 'Spouse',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 10),
    );

    // ─────────────────────────────────────────
    // SQLite round-trip
    // ─────────────────────────────────────────
    group('SQLite serialization', () {
      test('toSqlite produces valid map with JSON-encoded lists', () {
        final map = testPatient.toSqlite();

        expect(map['id'], equals('pat-001'));
        expect(map['nupi'], equals('NUPI-ABC123'));
        expect(map['first_name'], equals('Amina'));
        expect(map['gender'], equals('female'));

        // Lists must be JSON strings for SQLite storage
        expect(map['allergies'], isA<String>());
        expect(map['chronic_conditions'], isA<String>());

        // Verify they are valid JSON
        expect(() => jsonDecode(map['allergies'] as String), returnsNormally);
        expect(
          jsonDecode(map['allergies'] as String),
          equals(['Penicillin', 'Sulfa']),
        );
      });

      test('fromSqlite correctly parses JSON list fields', () {
        final map = testPatient.toSqlite();
        final recovered = PatientModel.fromSqlite(map);

        expect(recovered.allergies, equals(['Penicillin', 'Sulfa']));
        expect(recovered.chronicConditions, equals(['Hypertension']));
      });

      test('SQLite round-trip preserves all fields', () {
        final map = testPatient.toSqlite();
        final recovered = PatientModel.fromSqlite(map);

        expect(recovered.id, equals(testPatient.id));
        expect(recovered.nupi, equals(testPatient.nupi));
        expect(recovered.firstName, equals(testPatient.firstName));
        expect(recovered.lastName, equals(testPatient.lastName));
        expect(recovered.dateOfBirth, equals(testPatient.dateOfBirth));
        expect(recovered.phoneNumber, equals(testPatient.phoneNumber));
        expect(recovered.county, equals(testPatient.county));
        expect(recovered.facilityId, equals(testPatient.facilityId));
        expect(recovered.nextOfKinName, equals(testPatient.nextOfKinName));
      });

      test('fromSqlite handles null optional fields gracefully', () {
        final map = testPatient.toSqlite();
        map['email'] = null;
        map['blood_group'] = null;
        map['next_of_kin_name'] = null;
        map['allergies'] = null;

        final recovered = PatientModel.fromSqlite(map);

        expect(recovered.email, isNull);
        expect(recovered.bloodGroup, isNull);
        expect(recovered.nextOfKinName, isNull);
        expect(recovered.allergies, isEmpty);
      });
    });

    // ─────────────────────────────────────────
    // Entity conversion
    // ─────────────────────────────────────────
    group('Entity conversion', () {
      test('fromEntity creates a PatientModel from a Patient entity', () {
        final entity = Patient(
          id: 'pat-002',
          nupi: 'NUPI-XYZ',
          firstName: 'Brian',
          middleName: '',
          lastName: 'Otieno',
          gender: 'male',
          dateOfBirth: DateTime(1985, 3, 20),
          phoneNumber: '0799999999',
          county: 'Kisumu',
          subCounty: 'Kisumu East',
          ward: 'Kolwa Central',
          village: 'Obunga',
          facilityId: 'FAC-002',
          allergies: [],
          chronicConditions: [],
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );

        final model = PatientModel.fromEntity(entity);
        expect(model.id, equals('pat-002'));
        expect(model.nupi, equals('NUPI-XYZ'));
        expect(model.firstName, equals('Brian'));
      });

      test('toEntity produces a Patient from a PatientModel', () {
        final entity = testPatient.toEntity();
        expect(entity, isA<Patient>());
        expect(entity.nupi, equals('NUPI-ABC123'));
      });
    });

    // ─────────────────────────────────────────
    // copyWith
    // ─────────────────────────────────────────
    group('copyWith', () {
      test('copyWith updates only specified fields', () {
        final updated = testPatient.copyWith(firstName: 'Updated');
        expect(updated.firstName, equals('Updated'));
        expect(updated.lastName, equals(testPatient.lastName));
        expect(updated.nupi, equals(testPatient.nupi));
      });
    });
  });
}