import 'package:clinic_connect/core/config/firebase_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/config/facility_info.dart';

const uuid = Uuid();

FirebaseFirestore get _facilityDb => FirebaseConfig.facilityDb;
FirebaseFirestore get _sharedDb => FirebaseConfig.sharedDb;

// ─────────────────────────────────────────
// FACILITIES — shared index
// ─────────────────────────────────────────
Future<void> seedFacilities() async {
   // ✅ Check if already seeded
  final existing = await _sharedDb
      .collection('facilities')
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) {
    print('⏭️ Facilities already seeded — skipping');
    return;
  }
  print('🏥 Seeding facilities...');

  final facilities = [
    {
      'id': 'facility_knh_001',
      'name': 'Kenyatta National Hospital',
      'type': 'national_referral',
      'county': 'Nairobi',
      'sub_county': 'Starehe',
      'phone': '+254 20 272 6300',
      'email': 'info@knh.or.ke',
      'is_active': true,
      'registered_at': Timestamp.now(),
    },
    {
      'id': 'facility_mtrh_002',
      'name': 'Moi Teaching & Referral Hospital',
      'type': 'national_referral',
      'county': 'Uasin Gishu',
      'sub_county': 'Eldoret East',
      'phone': '+254 53 203 3471',
      'email': 'info@mtrh.go.ke',
      'is_active': true,
      'registered_at': Timestamp.now(),
    },
    {
      'id': 'facility_pumwani_003',
      'name': 'Pumwani Maternity Hospital',
      'type': 'county_referral',
      'county': 'Nairobi',
      'sub_county': 'Kamukunji',
      'phone': '+254 20 221 3349',
      'email': 'pumwani@nairobi.go.ke',
      'is_active': true,
      'registered_at': Timestamp.now(),
    },
    {
      'id': 'facility_kiambu_004',
      'name': 'Kiambu Level 5 Hospital',
      'type': 'county_referral',
      'county': 'Kiambu',
      'sub_county': 'Kiambu Town',
      'phone': '+254 66 202 2395',
      'email': 'kiambu@kiambu.go.ke',
      'is_active': true,
      'registered_at': Timestamp.now(),
    },
    {
      'id': 'facility_nakuru_005',
      'name': 'Nakuru Level 5 Hospital',
      'type': 'county_referral',
      'county': 'Nakuru',
      'sub_county': 'Nakuru East',
      'phone': '+254 51 221 0267',
      'email': 'nakuru@nakuru.go.ke',
      'is_active': true,
      'registered_at': Timestamp.now(),
    },
    {
      'id': 'facility_mathare_006',
      'name': 'Mathare North Health Centre',
      'type': 'health_center',
      'county': 'Nairobi',
      'sub_county': 'Mathare',
      'phone': '+254 722 000 001',
      'email': 'mathare.hc@nairobi.go.ke',
      'is_active': true,
      'registered_at': Timestamp.now(),
    },
  ];

  final batch = _sharedDb.batch();
  for (final f in facilities) {
    final ref = _sharedDb
        .collection('facilities')
        .doc(f['id'] as String);
    batch.set(ref, f, SetOptions(merge: true));
  }
  await batch.commit();
  print('  ✅ ${facilities.length} facilities seeded');
}

// ─────────────────────────────────────────
// PATIENTS — facility DB + shared index
// ─────────────────────────────────────────
Future<List<Map<String, dynamic>>> seedPatients() async {
  // ✅ Check if NUPI already exists
  final existing = await _facilityDb
      .collection('patients')
      .where('nupi', isEqualTo: 'KE-2024-100001')
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) {
    print('⏭️ Patients already seeded — skipping');
    // ✅ Return existing patients so encounters/referrals
    // can still use them
    final all = await _facilityDb
        .collection('patients')
        .get();
    return all.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList();
  }

  print('👥 Seeding patients...');

  const facilityId = 'facility_knh_001';
  const facilityName = 'Kenyatta National Hospital';
  const facilityCounty = 'Nairobi';

  final patients = [
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100001',
      'first_name': 'Amina',
      'middle_name': 'Wanjiru',
      'last_name': 'Odhiambo',
      'gender': 'female',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1990, 3, 15)),
      'phone_number': '+254712345678',
      'email': 'amina.odhiambo@gmail.com',
      'county': 'Nairobi',
      'sub_county': 'Starehe',
      'ward': 'Nairobi Central',
      'village': 'Pangani',
      'blood_group': 'B+',
      'allergies': ['Penicillin'],
      'chronic_conditions': ['Hypertension'],
      'next_of_kin_name': 'John Odhiambo',
      'next_of_kin_phone': '+254722111222',
      'next_of_kin_relationship': 'Spouse',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 1, 10)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100002',
      'first_name': 'Brian',
      'middle_name': 'Kipchoge',
      'last_name': 'Mutai',
      'gender': 'male',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1985, 7, 22)),
      'phone_number': '+254733456789',
      'email': null,
      'county': 'Uasin Gishu',
      'sub_county': 'Eldoret East',
      'ward': 'Huruma',
      'village': 'Huruma Estate',
      'blood_group': 'O+',
      'allergies': <String>[],
      'chronic_conditions': ['Type 2 Diabetes'],
      'next_of_kin_name': 'Grace Mutai',
      'next_of_kin_phone': '+254711222333',
      'next_of_kin_relationship': 'Wife',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 2, 5)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100003',
      'first_name': 'Cynthia',
      'middle_name': 'Achieng',
      'last_name': 'Otieno',
      'gender': 'female',
      'date_of_birth':
          Timestamp.fromDate(DateTime(2000, 11, 8)),
      'phone_number': '+254700567890',
      'email': 'cynthia.otieno@yahoo.com',
      'county': 'Kisumu',
      'sub_county': 'Kisumu Central',
      'ward': 'Market Milimani',
      'village': 'Milimani',
      'blood_group': 'A+',
      'allergies': ['Sulfonamides'],
      'chronic_conditions': <String>[],
      'next_of_kin_name': 'Mary Otieno',
      'next_of_kin_phone': '+254701333444',
      'next_of_kin_relationship': 'Mother',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 3, 18)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100004',
      'first_name': 'David',
      'middle_name': 'Mwangi',
      'last_name': 'Kamau',
      'gender': 'male',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1975, 5, 30)),
      'phone_number': '+254722678901',
      'email': null,
      'county': 'Kiambu',
      'sub_county': 'Kiambu Town',
      'ward': 'Township',
      'village': 'Kiambu Town',
      'blood_group': 'AB+',
      'allergies': <String>[],
      'chronic_conditions': [
        'Hypertension',
        'Type 2 Diabetes'
      ],
      'next_of_kin_name': 'Susan Kamau',
      'next_of_kin_phone': '+254733444555',
      'next_of_kin_relationship': 'Wife',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 4, 2)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100005',
      'first_name': 'Esther',
      'middle_name': 'Njoki',
      'last_name': 'Kariuki',
      'gender': 'female',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1995, 9, 14)),
      'phone_number': '+254744789012',
      'email': 'esther.kariuki@gmail.com',
      'county': 'Nakuru',
      'sub_county': 'Nakuru East',
      'ward': 'Kivumbini',
      'village': 'Kivumbini',
      'blood_group': 'O-',
      'allergies': ['Aspirin'],
      'chronic_conditions': ['Asthma'],
      'next_of_kin_name': 'Peter Kariuki',
      'next_of_kin_phone': '+254755555666',
      'next_of_kin_relationship': 'Father',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 5, 20)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100006',
      'first_name': 'Francis',
      'middle_name': 'Otieno',
      'last_name': 'Auma',
      'gender': 'male',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1968, 12, 3)),
      'phone_number': '+254711890123',
      'email': null,
      'county': 'Siaya',
      'sub_county': 'Siaya',
      'ward': 'Central Sakwa',
      'village': 'Siaya Town',
      'blood_group': 'B-',
      'allergies': <String>[],
      'chronic_conditions': ['HIV/AIDS', 'TB'],
      'next_of_kin_name': 'Agnes Auma',
      'next_of_kin_phone': '+254722666777',
      'next_of_kin_relationship': 'Daughter',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 6, 8)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100007',
      'first_name': 'Grace',
      'middle_name': 'Wambui',
      'last_name': 'Njoroge',
      'gender': 'female',
      'date_of_birth':
          Timestamp.fromDate(DateTime(2003, 4, 25)),
      'phone_number': '+254700901234',
      'email': 'grace.njoroge@student.ku.ac.ke',
      'county': 'Kiambu',
      'sub_county': 'Thika',
      'ward': 'Township',
      'village': 'Thika Town',
      'blood_group': 'A-',
      'allergies': <String>[],
      'chronic_conditions': <String>[],
      'next_of_kin_name': 'James Njoroge',
      'next_of_kin_phone': '+254733777888',
      'next_of_kin_relationship': 'Father',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 7, 14)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100008',
      'first_name': 'Hassan',
      'middle_name': 'Ali',
      'last_name': 'Mohamed',
      'gender': 'male',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1980, 8, 17)),
      'phone_number': '+254722012345',
      'email': 'hassan.mohamed@gmail.com',
      'county': 'Mombasa',
      'sub_county': 'Mvita',
      'ward': 'Tononoka',
      'village': 'Old Town',
      'blood_group': 'O+',
      'allergies': ['Codeine'],
      'chronic_conditions': ['Sickle Cell Disease'],
      'next_of_kin_name': 'Fatuma Mohamed',
      'next_of_kin_phone': '+254711888999',
      'next_of_kin_relationship': 'Sister',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 8, 3)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100009',
      'first_name': 'Irene',
      'middle_name': 'Chebet',
      'last_name': 'Koech',
      'gender': 'female',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1988, 2, 11)),
      'phone_number': '+254733123456',
      'email': 'irene.koech@gmail.com',
      'county': 'Bomet',
      'sub_county': 'Bomet Central',
      'ward': 'Silibwet Township',
      'village': 'Bomet Town',
      'blood_group': 'B+',
      'allergies': <String>[],
      'chronic_conditions': ['Epilepsy'],
      'next_of_kin_name': 'Daniel Koech',
      'next_of_kin_phone': '+254700999000',
      'next_of_kin_relationship': 'Husband',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 9, 22)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100010',
      'first_name': 'Julius',
      'middle_name': 'Baraka',
      'last_name': 'Waweru',
      'gender': 'male',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1960, 6, 5)),
      'phone_number': '+254722234567',
      'email': null,
      'county': "Murang'a",
      'sub_county': "Murang'a South",
      'ward': 'Kigumo',
      'village': 'Kigumo Centre',
      'blood_group': 'AB-',
      'allergies': ['Latex'],
      'chronic_conditions': [
        'Hypertension',
        'Heart Disease'
      ],
      'next_of_kin_name': 'Ruth Waweru',
      'next_of_kin_phone': '+254711000111',
      'next_of_kin_relationship': 'Wife',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 10, 7)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100011',
      'first_name': 'Lilian',
      'middle_name': 'Adhiambo',
      'last_name': 'Owino',
      'gender': 'female',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1993, 10, 28)),
      'phone_number': '+254700345678',
      'email': 'lilian.owino@gmail.com',
      'county': 'Homa Bay',
      'sub_county': 'Homa Bay Town',
      'ward': 'Homa Bay Town',
      'village': 'Homa Bay',
      'blood_group': 'A+',
      'allergies': <String>[],
      'chronic_conditions': ['HIV/AIDS'],
      'next_of_kin_name': 'Tom Owino',
      'next_of_kin_phone': '+254722111222',
      'next_of_kin_relationship': 'Brother',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 11, 1)),
      'updated_at': Timestamp.now(),
    },
    {
      'id': uuid.v4(),
      'nupi': 'KE-2024-100012',
      'first_name': 'Michael',
      'middle_name': 'Njeru',
      'last_name': 'Muthoni',
      'gender': 'male',
      'date_of_birth':
          Timestamp.fromDate(DateTime(1970, 1, 19)),
      'phone_number': '+254733456789',
      'email': null,
      'county': 'Embu',
      'sub_county': 'Manyatta',
      'ward': 'Ruguru Ngandori',
      'village': 'Embu Town',
      'blood_group': 'O+',
      'allergies': <String>[],
      'chronic_conditions': ['Chronic Kidney Disease'],
      'next_of_kin_name': 'Jane Muthoni',
      'next_of_kin_phone': '+254744222333',
      'next_of_kin_relationship': 'Wife',
      'facility_id': facilityId,
      'sync_status': 'synced',
      'created_at':
          Timestamp.fromDate(DateTime(2024, 12, 5)),
      'updated_at': Timestamp.now(),
    },
  ];

  // ✅ Two separate batches — two different DBs
  final facilityBatch = _facilityDb.batch();
  final sharedBatch = _sharedDb.batch();

  for (final p in patients) {
    // Clinical record → facility DB
    final facilityRef = _facilityDb
        .collection('patients')
        .doc(p['id'] as String);
    facilityBatch.set(facilityRef, p);

    // Safe demographics only → shared index
    final sharedRef = _sharedDb
        .collection('patient_index')
        .doc(p['nupi'] as String);
    sharedBatch.set(sharedRef, {
      'nupi': p['nupi'],
      'facility_id': facilityId,
      'facility_name': facilityName,
      'facility_county': facilityCounty,
      'full_name':
          '${p['first_name']} ${p['middle_name']} ${p['last_name']}',
      'gender': p['gender'],
      'date_of_birth': p['date_of_birth'],
      'registered_at': Timestamp.now(),
    });
  }

  await facilityBatch.commit();
  await sharedBatch.commit();
  print('  ✅ ${patients.length} patients seeded');
  return patients;
}

// ─────────────────────────────────────────
// ENCOUNTERS — facility DB only
// ─────────────────────────────────────────
Future<void> seedEncounters(
    List<Map<String, dynamic>> patients) async {
      // ✅ Check if already seeded
  final existing = await _facilityDb
      .collection('encounters')
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) {
    print('⏭️ Encounters already seeded — skipping');
    return;
  }
  print('🩺 Seeding encounters...');

  const facilityId = 'facility_knh_001';
  const facilityName = 'Kenyatta National Hospital';

  final now = Timestamp.now();

  Timestamp daysAgo(int d) => Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: d)));
  Timestamp hoursAgo(int h) => Timestamp.fromDate(
      DateTime.now().subtract(Duration(hours: h)));

  final encounters = [
    {
      'id': uuid.v4(),
      'patient_id': patients[0]['id'],
      'patient_name': 'Amina Wanjiru Odhiambo',
      'patient_nupi': 'KE-2024-100001',
      'facility_id': facilityId,
      'facility_name': facilityName,
      'clinician_id': 'demo_clinician_001',
      'clinician_name': 'Dr. James Kariuki',
      'type': 'outpatient',
      'status': 'finished',
      'vitals': {
        'systolic_bp': 158.0,
        'diastolic_bp': 96.0,
        'temperature': 36.8,
        'weight': 72.0,
        'height': 162.0,
        'oxygen_saturation': 98.0,
        'pulse_rate': 88,
        'respiratory_rate': 18,
        'blood_glucose': null,
      },
      'chief_complaint':
          'Persistent headache and dizziness',
      'history_of_presenting_illness':
          'Known hypertensive on Amlodipine 5mg OD. BP poorly controlled. 3-day history.',
      'examination_findings':
          'BP 158/96 mmHg. Alert and oriented. No focal neurological deficits.',
      'diagnoses': [
        {
          'code': 'I10',
          'description': 'Essential hypertension',
          'is_primary': true,
        }
      ],
      'treatment_plan':
          'Increase Amlodipine to 10mg OD. Add HCT 25mg OD. Review in 2 weeks.',
      'clinical_notes':
          'Counselled on salt restriction and exercise.',
      'disposition': 'discharged',
      'referral_id': null,
      'encounter_date': daysAgo(5),
      'sync_status': 'synced',
      'created_at': daysAgo(5),
      'updated_at': now,
    },
    {
      'id': uuid.v4(),
      'patient_id': patients[1]['id'],
      'patient_name': 'Brian Kipchoge Mutai',
      'patient_nupi': 'KE-2024-100002',
      'facility_id': facilityId,
      'facility_name': facilityName,
      'clinician_id': 'demo_clinician_001',
      'clinician_name': 'Dr. James Kariuki',
      'type': 'outpatient',
      'status': 'finished',
      'vitals': {
        'systolic_bp': 130.0,
        'diastolic_bp': 82.0,
        'temperature': 36.6,
        'weight': 85.0,
        'height': 175.0,
        'oxygen_saturation': 99.0,
        'pulse_rate': 76,
        'respiratory_rate': 16,
        'blood_glucose': 12.4,
      },
      'chief_complaint': 'Routine diabetes review',
      'history_of_presenting_illness':
          'Known Type 2 DM on Metformin 500mg BD. RBS 12.4 mmol/L.',
      'examination_findings':
          'Obese BMI 27.8. No peripheral neuropathy.',
      'diagnoses': [
        {
          'code': 'E11',
          'description': 'Type 2 diabetes mellitus',
          'is_primary': true,
        },
        {
          'code': 'E66',
          'description': 'Obesity',
          'is_primary': false,
        },
      ],
      'treatment_plan':
          'Increase Metformin to 1g BD. Add Glibenclamide 5mg OD. HbA1c in 3 months.',
      'clinical_notes': 'Referred to nutritionist.',
      'disposition': 'discharged',
      'referral_id': null,
      'encounter_date': daysAgo(3),
      'sync_status': 'synced',
      'created_at': daysAgo(3),
      'updated_at': now,
    },
    {
      'id': uuid.v4(),
      'patient_id': patients[4]['id'],
      'patient_name': 'Esther Njoki Kariuki',
      'patient_nupi': 'KE-2024-100005',
      'facility_id': facilityId,
      'facility_name': facilityName,
      'clinician_id': 'demo_clinician_002',
      'clinician_name': 'Dr. Sarah Wangari',
      'type': 'emergency',
      'status': 'finished',
      'vitals': {
        'systolic_bp': 118.0,
        'diastolic_bp': 74.0,
        'temperature': 37.2,
        'weight': 58.0,
        'height': 163.0,
        'oxygen_saturation': 91.0,
        'pulse_rate': 112,
        'respiratory_rate': 28,
        'blood_glucose': null,
      },
      'chief_complaint':
          'Acute shortness of breath — severe wheeze',
      'history_of_presenting_illness':
          'Known asthmatic. Acute exacerbation 2 hours. SpO2 91% on arrival.',
      'examination_findings':
          'Bilateral expiratory wheeze. Accessory muscle use. SpO2 91%.',
      'diagnoses': [
        {
          'code': 'J45.1',
          'description':
              'Persistent asthma — acute exacerbation',
          'is_primary': true,
        },
      ],
      'treatment_plan':
          'Nebulised Salbutamol x3. IV Hydrocortisone 200mg. O2 6L/min. Admit.',
      'clinical_notes':
          'SpO2 improved to 97% post nebulisation.',
      'disposition': 'admitted',
      'referral_id': null,
      'encounter_date': daysAgo(1),
      'sync_status': 'synced',
      'created_at': daysAgo(1),
      'updated_at': now,
    },
    {
      'id': uuid.v4(),
      'patient_id': patients[9]['id'],
      'patient_name': 'Julius Baraka Waweru',
      'patient_nupi': 'KE-2024-100010',
      'facility_id': facilityId,
      'facility_name': facilityName,
      'clinician_id': 'demo_clinician_001',
      'clinician_name': 'Dr. James Kariuki',
      'type': 'emergency',
      'status': 'finished',
      'vitals': {
        'systolic_bp': 168.0,
        'diastolic_bp': 102.0,
        'temperature': 36.9,
        'weight': 90.0,
        'height': 170.0,
        'oxygen_saturation': 95.0,
        'pulse_rate': 98,
        'respiratory_rate': 22,
        'blood_glucose': null,
      },
      'chief_complaint':
          'Chest pain radiating to left arm',
      'history_of_presenting_illness':
          'Sudden onset chest pain 1 hour. ECG: ST elevation leads II, III, aVF.',
      'examination_findings':
          'BP 168/102. Diaphoretic. Basal crepitations. ST elevation inferior leads.',
      'diagnoses': [
        {
          'code': 'I21.1',
          'description':
              'ST elevation MI — inferior wall',
          'is_primary': true,
        },
        {
          'code': 'I10',
          'description': 'Essential hypertension',
          'is_primary': false,
        },
      ],
      'treatment_plan':
          'Aspirin 300mg. Clopidogrel 300mg loading. IV Morphine. Urgent cardiology PCI.',
      'clinical_notes':
          'Referred urgently to cardiology.',
      'disposition': 'referred',
      'referral_id': null,
      'encounter_date': hoursAgo(6),
      'sync_status': 'synced',
      'created_at': hoursAgo(6),
      'updated_at': now,
    },
    {
      'id': uuid.v4(),
      'patient_id': patients[6]['id'],
      'patient_name': 'Grace Wambui Njoroge',
      'patient_nupi': 'KE-2024-100007',
      'facility_id': facilityId,
      'facility_name': facilityName,
      'clinician_id': 'demo_clinician_002',
      'clinician_name': 'Dr. Sarah Wangari',
      'type': 'outpatient',
      'status': 'finished',
      'vitals': {
        'systolic_bp': 110.0,
        'diastolic_bp': 70.0,
        'temperature': 38.5,
        'weight': 55.0,
        'height': 160.0,
        'oxygen_saturation': 98.0,
        'pulse_rate': 92,
        'respiratory_rate': 18,
        'blood_glucose': null,
      },
      'chief_complaint':
          'Fever, chills and headache — 3 days',
      'history_of_presenting_illness':
          '3-day high-grade fever. RDT positive P. falciparum.',
      'examination_findings':
          'Temp 38.5°C. Pallor++. Mild splenomegaly. RDT positive.',
      'diagnoses': [
        {
          'code': 'B50',
          'description':
              'Plasmodium falciparum malaria',
          'is_primary': true,
        },
      ],
      'treatment_plan':
          'Artemether-Lumefantrine BD x3 days. Paracetamol 1g TDS PRN.',
      'clinical_notes':
          'Counselled on completing antimalarials and net use.',
      'disposition': 'discharged',
      'referral_id': null,
      'encounter_date': Timestamp.fromDate(
          DateTime.now()),
      'sync_status': 'synced',
      'created_at': Timestamp.fromDate(
          DateTime.now()),
      'updated_at': now,
    },
  ];

  // ✅ Encounters → facility DB only
  final batch = _facilityDb.batch();
  for (final e in encounters) {
    final ref = _facilityDb
        .collection('encounters')
        .doc(e['id'] as String);
    batch.set(ref, e);
  }
  await batch.commit();
  print('  ✅ ${encounters.length} encounters seeded');
}

// ─────────────────────────────────────────
// REFERRALS — facility DB + shared notifications
// ─────────────────────────────────────────
Future<void> seedReferrals(
    List<Map<String, dynamic>> patients) async {
      // ✅ Check if already seeded
  final existing = await _facilityDb
      .collection('referrals')
      .where('from_facility_id',
          isEqualTo: 'facility_knh_001')
      .limit(1)
      .get();
  if (existing.docs.isNotEmpty) {
    print('⏭️ Referrals already seeded — skipping');
    return;
  }
  print('📤 Seeding referrals...');

  final now = Timestamp.now();

  Timestamp daysAgo(int d) => Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: d)));
  Timestamp hoursAgo(int h) => Timestamp.fromDate(
      DateTime.now().subtract(Duration(hours: h)));

  final referrals = [
    {
      'id': uuid.v4(),
      'patient_nupi': 'KE-2024-100010',
      'patient_name': 'Julius Baraka Waweru',
      'from_facility_id': 'facility_knh_001',
      'from_facility_name':
          'Kenyatta National Hospital',
      'to_facility_id': 'facility_knh_001',
      'to_facility_name':
          'Kenyatta National Hospital',
      'reason':
          'Urgent cardiology review — inferior STEMI. Requires PCI.',
      'priority': 'emergency',
      'status': 'accepted',
      'clinical_notes':
          'ST elevation MI inferior wall. On aspirin and clopidogrel.',
      'created_by': 'demo_clinician_001',
      'created_by_name': 'Dr. James Kariuki',
      'sync_status': 'synced',
      'created_at': hoursAgo(6),
      'updated_at': now,
    },
    {
      'id': uuid.v4(),
      'patient_nupi': 'KE-2024-100001',
      'patient_name': 'Amina Wanjiru Odhiambo',
      'from_facility_id': 'facility_mathare_006',
      'from_facility_name':
          'Mathare North Health Centre',
      'to_facility_id': 'facility_knh_001',
      'to_facility_name':
          'Kenyatta National Hospital',
      'reason':
          'Uncontrolled hypertension. BP 172/104 despite maximum oral therapy.',
      'priority': 'urgent',
      'status': 'completed',
      'clinical_notes':
          'On Amlodipine 10mg + HCT 25mg. Renal function normal.',
      'created_by': 'demo_clinician_003',
      'created_by_name': 'Nurse Jane Mwangi',
      'sync_status': 'synced',
      'created_at': daysAgo(7),
      'updated_at': daysAgo(5),
    },
    {
      'id': uuid.v4(),
      'patient_nupi': 'KE-2024-100006',
      'patient_name': 'Francis Otieno Auma',
      'from_facility_id': 'facility_knh_001',
      'from_facility_name':
          'Kenyatta National Hospital',
      'to_facility_id': 'facility_mtrh_002',
      'to_facility_name':
          'Moi Teaching & Referral Hospital',
      'reason':
          'HIV/TB co-infection. GeneXpert positive for Rifampicin resistance.',
      'priority': 'urgent',
      'status': 'pending',
      'clinical_notes':
          'On ARTs: TDF/3TC/EFV. Started TB treatment 2 weeks ago.',
      'created_by': 'demo_clinician_001',
      'created_by_name': 'Dr. James Kariuki',
      'sync_status': 'synced',
      'created_at': daysAgo(2),
      'updated_at': daysAgo(2),
    },
    {
      'id': uuid.v4(),
      'patient_nupi': 'KE-2024-100012',
      'patient_name': 'Michael Njeru Muthoni',
      'from_facility_id': 'facility_kiambu_004',
      'from_facility_name':
          'Kiambu Level 5 Hospital',
      'to_facility_id': 'facility_knh_001',
      'to_facility_name':
          'Kenyatta National Hospital',
      'reason':
          'CKD Stage 4. Creatinine 380 umol/L. Requires nephrology assessment.',
      'priority': 'urgent',
      'status': 'inTransit',
      'clinical_notes':
          'On erythropoietin. BP controlled. Potassium 5.8 mEq/L.',
      'created_by': 'demo_clinician_004',
      'created_by_name': 'Dr. Paul Ochieng',
      'sync_status': 'synced',
      'created_at': daysAgo(1),
      'updated_at': hoursAgo(2),
    },
  ];

  // ✅ Two separate batches — two different DBs
  final facilityBatch = _facilityDb.batch();
  final sharedBatch = _sharedDb.batch();

  for (final r in referrals) {
    // Clinical referral → facility DB
    final facilityRef = _facilityDb
        .collection('referrals')
        .doc(r['id'] as String);
    facilityBatch.set(facilityRef, r);

    // Notification only → shared index
    final sharedRef = _sharedDb
        .collection('referral_notifications')
        .doc(r['id'] as String);
    sharedBatch.set(sharedRef, {
      'id': r['id'],
      'to_facility_id': r['to_facility_id'],
      'from_facility_id': r['from_facility_id'],
      'patient_nupi': r['patient_nupi'],
      'priority': r['priority'],
      'status': r['status'],
      'created_at': r['created_at'],
    });
  }

  await facilityBatch.commit();
  await sharedBatch.commit();
  print('  ✅ ${referrals.length} referrals seeded');
}

Future<void> seedIncomingReferral() async {
  print('📨 Seeding incoming referral...');

  final facilityId = FacilityInfo().facilityId;
  final facilityName = FacilityInfo().facilityName;

  final referralId = uuid.v4();
  final now = Timestamp.now();

  final patients = [
    {
      'nupi': 'KE-2024-100003',
      'name': 'Cynthia Achieng Otieno',
      'condition':
          'Severe anaemia — Hb 6.2 g/dL. Requires transfusion and specialist review.',
      'priority': 'urgent',
    },
    {
      'nupi': 'KE-2024-100008',
      'name': 'Hassan Ali Mohamed',
      'condition':
          'Sickle cell crisis. Severe pain, dehydrated. Requires IV fluids and haematology review.',
      'priority': 'emergency',
    },
    {
      'nupi': 'KE-2024-100009',
      'name': 'Irene Chebet Koech',
      'condition':
          'Breakthrough seizures on Phenobarbitone. Requires neurology review.',
      'priority': 'urgent',
    },
  ];

  final patient =
      patients[DateTime.now().second % patients.length];

  // ✅ Full referral data — used by both copies
  final referralData = {
    'id': referralId,
    'patient_nupi': patient['nupi'],
    'patient_name': patient['name'],
    'from_facility_id': 'facility_mathare_006',
    'from_facility_name': 'Mathare North Health Centre',
    'to_facility_id': facilityId,
    'to_facility_name': facilityName,
    'reason': patient['condition'],
    'priority': patient['priority'],
    'status': 'pending',
    'clinical_notes':
        'Patient stable for transfer. Vitals attached. Please review urgently upon arrival.',
    'created_by': 'sim_clinician_001',
    'created_by_name': 'Dr. Mercy Wanjiku',
    'sync_status': 'synced',
    'created_at': now,
    'updated_at': now,
  };

  // ✅ 1. Write to facility DB so getReferral() finds it
  await _facilityDb
      .collection('referrals')
      .doc(referralId)
      .set(referralData);

  // ✅ 2. Write to referral_copies in shared DB
  // so getIncomingReferrals() finds the full data
  await _sharedDb
      .collection('referral_copies')
      .doc(referralId)
      .set(referralData);

  // ✅ 3. Write notification to shared DB
  // referral_id field must match what getIncomingReferrals() reads
  await _sharedDb
      .collection('referral_notifications')
      .doc(referralId)
      .set({
    'referral_id': referralId, // ✅ KEY — datasource reads this
    'from_facility_id': 'facility_mathare_006',
    'from_facility_name': 'Mathare North Health Centre',
    'to_facility_id': facilityId,
    'to_facility_name': facilityName,
    'patient_nupi': patient['nupi'],
    'patient_name': patient['name'],
    'priority': patient['priority'],
    'status': 'pending',
    'reason': patient['condition'],
    'created_at': now,
    'updated_at': now,
  });

  print(
      '  ✅ Incoming referral seeded for ${patient['name']}');
}
