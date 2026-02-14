import 'dart:convert';
import '../../features/encounter/domain/entities/encounter.dart';
import '../../features/patient/domain/entities/patient.dart';
import '../../features/referral/domain/entities/referral.dart';

/// Maps local entities to FHIR R4 compliant JSON resources
class FhirMapper {
  // ─────────────────────────────────────────
  // FHIR Patient Resource
  // ─────────────────────────────────────────
  static Map<String, dynamic> toFhirPatient(Patient patient) {
    return {
      'resourceType': 'Patient',
      'id': patient.id,
      'meta': {
        'profile': ['http://hl7.org/fhir/StructureDefinition/Patient'],
        'lastUpdated': patient.updatedAt.toIso8601String(),
      },
      'identifier': [
        {
          'system': 'https://khis.uonbi.ac.ke/fhir/NamingSystem/nupi',
          'value': patient.nupi,
          'type': {
            'coding': [
              {
                'system': 'http://terminology.hl7.org/CodeSystem/v2-0203',
                'code': 'NI',
                'display': 'National unique individual identifier',
              },
            ],
          },
        },
      ],
      'active': true,
      'name': [
        {
          'use': 'official',
          'family': patient.lastName,
          'given': [
            patient.firstName,
            if (patient.middleName.isNotEmpty) patient.middleName,
          ],
        },
      ],
      'telecom': [
        {'system': 'phone', 'value': patient.phoneNumber, 'use': 'mobile'},
        if (patient.email != null) {'system': 'email', 'value': patient.email},
      ],
      'gender': _mapGender(patient.gender),
      'birthDate': patient.dateOfBirth.toIso8601String().split('T')[0],
      'address': [
        {
          'use': 'home',
          'text': '${patient.village}, ${patient.ward}, ${patient.subCounty}',
          'district': patient.subCounty,
          'state': patient.county,
          'country': 'KE',
        },
      ],
      'contact': patient.nextOfKinName != null
          ? [
              {
                'relationship': [
                  {
                    'coding': [
                      {
                        'system':
                            'http://terminology.hl7.org/CodeSystem/v2-0131',
                        'code': 'N',
                        'display':
                            patient.nextOfKinRelationship ?? 'Next of kin',
                      },
                    ],
                  },
                ],
                'name': {'text': patient.nextOfKinName},
                'telecom': patient.nextOfKinPhone != null
                    ? [
                        {'system': 'phone', 'value': patient.nextOfKinPhone},
                      ]
                    : [],
              },
            ]
          : [],
      'extension': [
        if (patient.bloodGroup != null)
          {
            'url': 'http://hl7.org/fhir/StructureDefinition/patient-bloodGroup',
            'valueString': patient.bloodGroup,
          },
        {
          'url':
              'https://khis.uonbi.ac.ke/fhir/StructureDefinition/managing-facility',
          'valueString': patient.facilityId,
        },
      ],
    };
  }

  // ─────────────────────────────────────────
  // FHIR Encounter Resource
  // ─────────────────────────────────────────
  static Map<String, dynamic> toFhirEncounter(
    Encounter encounter,
    String patientFhirId,
  ) {
    return {
      'resourceType': 'Encounter',
      'id': encounter.id,
      'meta': {
        'profile': ['http://hl7.org/fhir/StructureDefinition/Encounter'],
        'lastUpdated': encounter.updatedAt.toIso8601String(),
      },
      'status': _mapEncounterStatus(encounter.status),
      'class': {
        'system': 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
        'code': _mapEncounterClass(encounter.type),
        'display': encounter.type.name,
      },
      'type': [
        {
          'coding': [
            {
              'system': 'http://snomed.info/sct',
              'code': '11429006',
              'display': 'Consultation',
            },
          ],
        },
      ],
      'subject': {
        'reference': 'Patient/$patientFhirId',
        'display': encounter.patientName,
      },
      'participant': [
        {
          'individual': {
            'reference': 'Practitioner/${encounter.clinicianId}',
            'display': encounter.clinicianName,
          },
        },
      ],
      'period': {
        'start': encounter.encounterDate.toIso8601String(),
        'end': encounter.updatedAt.toIso8601String(),
      },
      'reasonCode': encounter.chiefComplaint != null
          ? [
              {'text': encounter.chiefComplaint},
            ]
          : [],
      'diagnosis': encounter.diagnoses
          .map(
            (d) => {
              'condition': {
                'reference': 'Condition/${d.code}-${encounter.id}',
                'display': d.description,
              },
              'use': {
                'coding': [
                  {
                    'system':
                        'http://terminology.hl7.org/CodeSystem/diagnosis-role',
                    'code': d.isPrimary ? 'AD' : 'DD',
                    'display': d.isPrimary
                        ? 'Admission diagnosis'
                        : 'Discharge diagnosis',
                  },
                ],
              },
              'rank': d.isPrimary ? 1 : 2,
            },
          )
          .toList(),
      'hospitalization': encounter.disposition != null
          ? {
              'dischargeDisposition': {
                'coding': [
                  {
                    'system':
                        'http://terminology.hl7.org/CodeSystem/ex-dischargeDisposition',
                    'code': _mapDisposition(encounter.disposition!),
                    'display': encounter.disposition!.name,
                  },
                ],
              },
            }
          : null,
      'serviceProvider': {
        'reference': 'Organization/${encounter.facilityId}',
        'display': encounter.facilityName,
      },
      'note': [
        if (encounter.historyOfPresentingIllness != null)
          {'text': 'History: ${encounter.historyOfPresentingIllness}'},
        if (encounter.examinationFindings != null)
          {'text': 'Examination: ${encounter.examinationFindings}'},
        if (encounter.treatmentPlan != null)
          {'text': 'Treatment Plan: ${encounter.treatmentPlan}'},
      ],
    };
  }

  // ─────────────────────────────────────────
  // FHIR Observation Resources (Vitals)
  // ─────────────────────────────────────────
  static List<Map<String, dynamic>> toFhirObservations(
    Vitals vitals,
    String encounterId,
    String patientFhirId,
  ) {
    final observations = <Map<String, dynamic>>[];
    final now = DateTime.now().toIso8601String();

    if (vitals.systolicBP != null && vitals.diastolicBP != null) {
      observations.add({
        'resourceType': 'Observation',
        'id': 'bp-$encounterId',
        'status': 'final',
        'category': [
          {
            'coding': [
              {
                'system':
                    'http://terminology.hl7.org/CodeSystem/observation-category',
                'code': 'vital-signs',
                'display': 'Vital Signs',
              },
            ],
          },
        ],
        'code': {
          'coding': [
            {
              'system': 'http://loinc.org',
              'code': '85354-9',
              'display': 'Blood pressure panel',
            },
          ],
        },
        'subject': {'reference': 'Patient/$patientFhirId'},
        'encounter': {'reference': 'Encounter/$encounterId'},
        'effectiveDateTime': now,
        'component': [
          {
            'code': {
              'coding': [
                {
                  'system': 'http://loinc.org',
                  'code': '8480-6',
                  'display': 'Systolic blood pressure',
                },
              ],
            },
            'valueQuantity': {
              'value': vitals.systolicBP,
              'unit': 'mmHg',
              'system': 'http://unitsofmeasure.org',
              'code': 'mm[Hg]',
            },
          },
          {
            'code': {
              'coding': [
                {
                  'system': 'http://loinc.org',
                  'code': '8462-4',
                  'display': 'Diastolic blood pressure',
                },
              ],
            },
            'valueQuantity': {
              'value': vitals.diastolicBP,
              'unit': 'mmHg',
              'system': 'http://unitsofmeasure.org',
              'code': 'mm[Hg]',
            },
          },
        ],
      });
    }

    if (vitals.temperature != null) {
      observations.add(
        _singleObservation(
          id: 'temp-$encounterId',
          loincCode: '8310-5',
          display: 'Body temperature',
          value: vitals.temperature!,
          unit: 'Cel',
          unitDisplay: '°C',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.weight != null) {
      observations.add(
        _singleObservation(
          id: 'weight-$encounterId',
          loincCode: '29463-7',
          display: 'Body weight',
          value: vitals.weight!,
          unit: 'kg',
          unitDisplay: 'kg',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.height != null) {
      observations.add(
        _singleObservation(
          id: 'height-$encounterId',
          loincCode: '8302-2',
          display: 'Body height',
          value: vitals.height!,
          unit: 'cm',
          unitDisplay: 'cm',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.oxygenSaturation != null) {
      observations.add(
        _singleObservation(
          id: 'o2-$encounterId',
          loincCode: '2708-6',
          display: 'Oxygen saturation',
          value: vitals.oxygenSaturation!,
          unit: '%',
          unitDisplay: '%',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.pulseRate != null) {
      observations.add(
        _singleObservation(
          id: 'pulse-$encounterId',
          loincCode: '8867-4',
          display: 'Heart rate',
          value: vitals.pulseRate!.toDouble(),
          unit: '/min',
          unitDisplay: 'bpm',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.respiratoryRate != null) {
      observations.add(
        _singleObservation(
          id: 'rr-$encounterId',
          loincCode: '9279-1',
          display: 'Respiratory rate',
          value: vitals.respiratoryRate!.toDouble(),
          unit: '/min',
          unitDisplay: 'breaths/min',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.bloodGlucose != null) {
      observations.add(
        _singleObservation(
          id: 'glucose-$encounterId',
          loincCode: '2339-0',
          display: 'Glucose [Mass/volume] in Blood',
          value: vitals.bloodGlucose!,
          unit: 'mmol/L',
          unitDisplay: 'mmol/L',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    if (vitals.bmi != null) {
      observations.add(
        _singleObservation(
          id: 'bmi-$encounterId',
          loincCode: '39156-5',
          display: 'Body mass index (BMI)',
          value: double.parse(vitals.bmi!.toStringAsFixed(1)),
          unit: 'kg/m2',
          unitDisplay: 'kg/m²',
          encounterId: encounterId,
          patientFhirId: patientFhirId,
        ),
      );
    }

    return observations;
  }

  // ─────────────────────────────────────────
  // FHIR Condition Resource (Diagnosis)
  // ─────────────────────────────────────────
  static List<Map<String, dynamic>> toFhirConditions(
    List<Diagnosis> diagnoses,
    String encounterId,
    String patientFhirId,
  ) {
    return diagnoses
        .map(
          (d) => {
            'resourceType': 'Condition',
            'id': '${d.code}-$encounterId',
            'clinicalStatus': {
              'coding': [
                {
                  'system':
                      'http://terminology.hl7.org/CodeSystem/condition-clinical',
                  'code': 'active',
                },
              ],
            },
            'verificationStatus': {
              'coding': [
                {
                  'system':
                      'http://terminology.hl7.org/CodeSystem/condition-ver-status',
                  'code': 'confirmed',
                },
              ],
            },
            'category': [
              {
                'coding': [
                  {
                    'system':
                        'http://terminology.hl7.org/CodeSystem/condition-category',
                    'code': 'encounter-diagnosis',
                    'display': 'Encounter Diagnosis',
                  },
                ],
              },
            ],
            'code': {
              'coding': [
                {
                  'system': 'http://hl7.org/fhir/sid/icd-10',
                  'code': d.code,
                  'display': d.description,
                },
              ],
              'text': d.description,
            },
            'subject': {'reference': 'Patient/$patientFhirId'},
            'encounter': {'reference': 'Encounter/$encounterId'},
          },
        )
        .toList();
  }

  // ─────────────────────────────────────────
  // FHIR ServiceRequest Resource (Referral)
  // ─────────────────────────────────────────
  static Map<String, dynamic> toFhirServiceRequest(
    Referral referral,
    String patientFhirId,
  ) {
    return {
      'resourceType': 'ServiceRequest',
      'id': referral.id,
      'meta': {
        'profile': ['http://hl7.org/fhir/StructureDefinition/ServiceRequest'],
      },
      'status': _mapReferralStatus(referral.status),
      'intent': 'order',
      'priority': _mapReferralPriority(referral.priority),
      'category': [
        {
          'coding': [
            {
              'system': 'http://snomed.info/sct',
              'code': '3457005',
              'display': 'Patient referral',
            },
          ],
        },
      ],
      'code': {
        'coding': [
          {
            'system': 'http://snomed.info/sct',
            'code': '306206005',
            'display': 'Referral to hospital',
          },
        ],
        'text': referral.reason,
      },
      'subject': {
        'reference': 'Patient/$patientFhirId',
        'display': referral.patientName,
      },
      'requester': {
        'reference': 'Practitioner/${referral.createdBy}',
        'display': referral.createdByName,
      },
      'performer': [
        {
          'reference': 'Organization/${referral.toFacilityId}',
          'display': referral.toFacilityName,
        },
      ],
      'locationReference': [
        {
          'reference': 'Location/${referral.fromFacilityId}',
          'display': referral.fromFacilityName,
        },
      ],
      'note': referral.clinicalNotes != null
          ? [
              {'text': referral.clinicalNotes},
            ]
          : [],
      'authoredOn': referral.createdAt.toIso8601String(),
    };
  }

  // ─────────────────────────────────────────
  // FHIR Bundle — wraps everything together
  // ─────────────────────────────────────────
  static Map<String, dynamic> toFhirBundle({
    required Patient patient,
    List<Encounter> encounters = const [],
    List<Referral> referrals = const [],
    String bundleType = 'document',
  }) {
    final entries = <Map<String, dynamic>>[];

    // Patient resource
    entries.add({
      'fullUrl': 'Patient/${patient.id}',
      'resource': toFhirPatient(patient),
    });

    // Encounter resources + their observations and conditions
    for (final encounter in encounters) {
      entries.add({
        'fullUrl': 'Encounter/${encounter.id}',
        'resource': toFhirEncounter(encounter, patient.id),
      });

      // Vitals as Observations
      if (encounter.vitals != null) {
        for (final obs in toFhirObservations(
          encounter.vitals!,
          encounter.id,
          patient.id,
        )) {
          entries.add({'fullUrl': 'Observation/${obs['id']}', 'resource': obs});
        }
      }

      // Diagnoses as Conditions
      if (encounter.diagnoses.isNotEmpty) {
        for (final condition in toFhirConditions(
          encounter.diagnoses,
          encounter.id,
          patient.id,
        )) {
          entries.add({
            'fullUrl': 'Condition/${condition['id']}',
            'resource': condition,
          });
        }
      }
    }

    // Referrals as ServiceRequests
    for (final referral in referrals) {
      entries.add({
        'fullUrl': 'ServiceRequest/${referral.id}',
        'resource': toFhirServiceRequest(referral, patient.id),
      });
    }

    return {
      'resourceType': 'Bundle',
      'id': 'bundle-${patient.nupi}-${DateTime.now().millisecondsSinceEpoch}',
      'meta': {
        'lastUpdated': DateTime.now().toIso8601String(),
        'profile': ['http://hl7.org/fhir/StructureDefinition/Bundle'],
      },
      'type': bundleType,
      'timestamp': DateTime.now().toIso8601String(),
      'total': entries.length,
      'entry': entries,
    };
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────
  static Map<String, dynamic> _singleObservation({
    required String id,
    required String loincCode,
    required String display,
    required double value,
    required String unit,
    required String unitDisplay,
    required String encounterId,
    required String patientFhirId,
  }) {
    return {
      'resourceType': 'Observation',
      'id': id,
      'status': 'final',
      'category': [
        {
          'coding': [
            {
              'system':
                  'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': 'vital-signs',
              'display': 'Vital Signs',
            },
          ],
        },
      ],
      'code': {
        'coding': [
          {'system': 'http://loinc.org', 'code': loincCode, 'display': display},
        ],
      },
      'subject': {'reference': 'Patient/$patientFhirId'},
      'encounter': {'reference': 'Encounter/$encounterId'},
      'effectiveDateTime': DateTime.now().toIso8601String(),
      'valueQuantity': {
        'value': value,
        'unit': unitDisplay,
        'system': 'http://unitsofmeasure.org',
        'code': unit,
      },
    };
  }

  static String _mapGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      default:
        return 'unknown';
    }
  }

  static String _mapEncounterStatus(EncounterStatus status) {
    switch (status) {
      case EncounterStatus.planned:
        return 'planned';
      case EncounterStatus.inProgress:
        return 'in-progress';
      case EncounterStatus.finished:
        return 'finished';
      case EncounterStatus.cancelled:
        return 'cancelled';
    }
  }

  static String _mapEncounterClass(EncounterType type) {
    switch (type) {
      case EncounterType.outpatient:
        return 'AMB';
      case EncounterType.inpatient:
        return 'IMP';
      case EncounterType.emergency:
        return 'EMER';
      case EncounterType.referral:
        return 'REF';
    }
  }

  static String _mapDisposition(Disposition d) {
    switch (d) {
      case Disposition.discharged:
        return 'home';
      case Disposition.admitted:
        return 'inpatient';
      case Disposition.referred:
        return 'other-hcf';
      case Disposition.deceased:
        return 'exp';
      case Disposition.absconded:
        return 'aadvice';
    }
  }

  static String _mapReferralStatus(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return 'active';
      case ReferralStatus.accepted:
        return 'active';
      case ReferralStatus.inTransit:
        return 'active';
      case ReferralStatus.arrived:
        return 'active';
      case ReferralStatus.completed:
        return 'completed';
      case ReferralStatus.cancelled:
        return 'revoked';
      case ReferralStatus.rejected:
        return 'arrived';
    }
  }

  static String _mapReferralPriority(ReferralPriority priority) {
    switch (priority) {
      case ReferralPriority.normal:
        return 'routine';
      case ReferralPriority.urgent:
        return 'urgent';
      case ReferralPriority.emergency:
        return 'stat';
    }
  }

  /// Convert FHIR bundle to formatted JSON string
  static String toJson(Map<String, dynamic> bundle) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(bundle);
  }

  /// Validate minimum FHIR requirements are met
  static List<String> validateBundle(Map<String, dynamic> bundle) {
    final errors = <String>[];

    if (bundle['resourceType'] != 'Bundle') {
      errors.add('Missing resourceType: Bundle');
    }
    if (bundle['entry'] == null || (bundle['entry'] as List).isEmpty) {
      errors.add('Bundle has no entries');
    }

    final entries = bundle['entry'] as List;
    final hasPatient = entries.any(
      (e) => e['resource']?['resourceType'] == 'Patient',
    );
    if (!hasPatient) errors.add('Bundle missing Patient resource');

    return errors;
  }
}
