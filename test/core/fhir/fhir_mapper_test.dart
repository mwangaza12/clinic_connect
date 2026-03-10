import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_connect/core/fhir/fhir_mapper.dart';
import 'package:clinic_connect/features/patient/domain/entities/patient.dart';
import 'package:clinic_connect/features/encounter/domain/entities/encounter.dart';

// ─────────────────────────────────────────
// Test fixtures
// ─────────────────────────────────────────

Patient _makePatient() => Patient(
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
      allergies: ['Penicillin'],
      chronicConditions: ['Hypertension'],
      nextOfKinName: 'John Kamau',
      nextOfKinPhone: '0723456789',
      nextOfKinRelationship: 'Spouse',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 10),
    );

Encounter _makeEncounter() => Encounter(
      id: 'enc-001',
      patientId: 'pat-001',
      patientName: 'Amina Kamau',
      patientNupi: 'NUPI-ABC123',
      facilityId: 'FAC-001',
      facilityName: 'Nakuru Clinic',
      clinicianId: 'doc-001',
      clinicianName: 'Dr. Odhiambo',
      type: EncounterType.outpatient,
      status: EncounterStatus.finished,
      vitals: const Vitals(
        systolicBP: 130,
        diastolicBP: 85,
        temperature: 37.2,
        weight: 65.0,
        height: 162.0,
        pulseRate: 78,
      ),
      chiefComplaint: 'Headache and dizziness',
      diagnoses: [
        const Diagnosis(
          code: 'I10',
          description: 'Essential hypertension',
          isPrimary: true,
        ),
      ],
      treatmentPlan: 'Continue antihypertensive medication',
      encounterDate: DateTime(2025, 1, 10),
      createdAt: DateTime(2025, 1, 10),
      updatedAt: DateTime(2025, 1, 10),
    );

void main() {
  group('FhirMapper', () {
    // ─────────────────────────────────────────
    // Patient resource
    // ─────────────────────────────────────────
    group('toFhirPatient', () {
      test('produces a valid FHIR Patient resource', () {
        final patient = _makePatient();
        final fhir = FhirMapper.toFhirPatient(patient);

        expect(fhir['resourceType'], equals('Patient'));
        expect(fhir['id'], equals('pat-001'));
        expect(fhir['active'], isTrue);
      });

      test('contains NUPI as identifier', () {
        final fhir = FhirMapper.toFhirPatient(_makePatient());
        final identifiers = fhir['identifier'] as List;
        expect(identifiers, isNotEmpty);
        expect(identifiers.first['value'], equals('NUPI-ABC123'));
      });

      test('maps gender correctly', () {
        final fhir = FhirMapper.toFhirPatient(_makePatient());
        expect(fhir['gender'], equals('female'));
      });

      test('formats birthDate as YYYY-MM-DD', () {
        final fhir = FhirMapper.toFhirPatient(_makePatient());
        expect(fhir['birthDate'], equals('1990-05-15'));
      });

      test('includes next of kin contact', () {
        final fhir = FhirMapper.toFhirPatient(_makePatient());
        final contacts = fhir['contact'] as List;
        expect(contacts, isNotEmpty);
        expect(contacts.first['name']['text'], equals('John Kamau'));
      });

      test('includes Kenya country code in address', () {
        final fhir = FhirMapper.toFhirPatient(_makePatient());
        final addresses = fhir['address'] as List;
        expect(addresses.first['country'], equals('KE'));
      });
    });

    // ─────────────────────────────────────────
    // Encounter resource
    // ─────────────────────────────────────────
    group('toFhirEncounter', () {
      test('produces a valid FHIR Encounter resource', () {
        final fhir = FhirMapper.toFhirEncounter(_makeEncounter(), 'pat-001');

        expect(fhir['resourceType'], equals('Encounter'));
        expect(fhir['id'], equals('enc-001'));
        expect(fhir['status'], equals('finished'));
      });

      test('maps outpatient type to AMB class code', () {
        final fhir = FhirMapper.toFhirEncounter(_makeEncounter(), 'pat-001');
        expect(fhir['class']['code'], equals('AMB'));
      });

      test('references patient correctly', () {
        final fhir = FhirMapper.toFhirEncounter(_makeEncounter(), 'pat-001');
        expect(fhir['subject']['reference'], equals('Patient/pat-001'));
      });

      test('includes diagnoses', () {
        final fhir = FhirMapper.toFhirEncounter(_makeEncounter(), 'pat-001');
        final diagnoses = fhir['diagnosis'] as List;
        expect(diagnoses, isNotEmpty);
      });
    });

    // ─────────────────────────────────────────
    // Observations (vitals)
    // ─────────────────────────────────────────
    group('toFhirObservations', () {
      test('generates blood pressure observation with two components', () {
        const vitals = Vitals(systolicBP: 130, diastolicBP: 85);
        final observations = FhirMapper.toFhirObservations(
          vitals, 'enc-001', 'pat-001',
        );

        final bp = observations.firstWhere(
          (o) => o['id'] == 'bp-enc-001',
          orElse: () => {},
        );
        expect(bp['resourceType'], equals('Observation'));
        final components = bp['component'] as List;
        expect(components.length, equals(2));
      });

      test('generates separate observations for each vital sign', () {
        const vitals = Vitals(
          systolicBP: 130,
          diastolicBP: 85,
          temperature: 37.2,
          weight: 65.0,
          height: 162.0,
          pulseRate: 78,
        );
        final observations = FhirMapper.toFhirObservations(
          vitals, 'enc-001', 'pat-001',
        );

        // BP, temperature, weight, height, pulse, BMI (auto-calculated) = 6
        expect(observations.length, equals(6));
      });

      test('all observations reference the correct patient', () {
        const vitals = Vitals(temperature: 37.5);
        final observations = FhirMapper.toFhirObservations(
          vitals, 'enc-001', 'pat-001',
        );
        for (final obs in observations) {
          expect(obs['subject']['reference'], equals('Patient/pat-001'));
        }
      });
    });

    // ─────────────────────────────────────────
    // FHIR Bundle
    // ─────────────────────────────────────────
    group('toFhirBundle', () {
      test('produces a Bundle with correct resourceType', () {
        final bundle = FhirMapper.toFhirBundle(patient: _makePatient());
        expect(bundle['resourceType'], equals('Bundle'));
      });

      test('bundle contains at least one Patient entry', () {
        final bundle = FhirMapper.toFhirBundle(patient: _makePatient());
        final entries = bundle['entry'] as List;
        final hasPatient = entries.any(
          (e) => e['resource']['resourceType'] == 'Patient',
        );
        expect(hasPatient, isTrue);
      });

      test('bundle total matches entry count', () {
        final bundle = FhirMapper.toFhirBundle(
          patient: _makePatient(),
          encounters: [_makeEncounter()],
        );
        final entries = bundle['entry'] as List;
        expect(bundle['total'], equals(entries.length));
      });

      test('bundle includes encounter and its observations', () {
        final bundle = FhirMapper.toFhirBundle(
          patient: _makePatient(),
          encounters: [_makeEncounter()],
        );
        final entries = bundle['entry'] as List;

        final hasEncounter = entries.any(
          (e) => e['resource']['resourceType'] == 'Encounter',
        );
        final hasObservation = entries.any(
          (e) => e['resource']['resourceType'] == 'Observation',
        );

        expect(hasEncounter, isTrue);
        expect(hasObservation, isTrue);
      });

      // ─────────────────────────────────────────
      // Bundle validation
      // ─────────────────────────────────────────
      test('validateBundle passes for a complete bundle', () {
        final bundle = FhirMapper.toFhirBundle(patient: _makePatient());
        final errors = FhirMapper.validateBundle(bundle);
        expect(errors, isEmpty);
      });

      test('validateBundle fails when resourceType is wrong', () {
        final bundle = {'resourceType': 'NotABundle', 'entry': []};
        final errors = FhirMapper.validateBundle(bundle);
        expect(errors, isNotEmpty);
      });
    });
  });
}