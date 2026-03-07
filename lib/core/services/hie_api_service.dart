// lib/core/services/hie_api_service.dart
//
// Wraps all calls to ClinicConnect's Node.js backend, which in turn
// talks to the AfyaLink HIE Gateway and the blockchain.
//
// Every method returns a HieResult so callers can show a blockchain
// confirmation or silently swallow errors without crashing the app.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class HieResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final int? blockIndex;
  final String? nupi;

  const HieResult({
    required this.success,
    this.data,
    this.error,
    this.blockIndex,
    this.nupi,
  });
}

class HieApiService {
  static HieApiService? _instance;
  late final Dio _dio;

  HieApiService._({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody:  true,
        responseBody: true,
        logPrint: (o) => debugPrint('[HIE] $o'),
      ));
    }
  }

  /// Call once during app init.  baseUrl = your Render backend URL.
  /// e.g. HieApiService.init('https://clinicconnect-api.onrender.com')
  static void init(String baseUrl) {
    _instance = HieApiService._(baseUrl: baseUrl);
  }

  static HieApiService get instance {
    assert(_instance != null,
        'HieApiService.init() must be called before use');
    return _instance!;
  }

  // ══════════════════════════════════════════════════════════════
  //  PATIENT REGISTRATION
  //  Calls POST /api/patients → gateway derives NUPI from nationalId
  //  + DOB, mints PATIENT_REGISTERED block, returns nupi + blockIndex.
  // ══════════════════════════════════════════════════════════════

  Future<HieResult> registerPatient({
    required String nationalId,
    required String firstName,
    required String lastName,
    String? middleName,
    required String dateOfBirth,  // ISO date string YYYY-MM-DD
    required String gender,
    String? phoneNumber,
    String? email,
    Map<String, String?>? address,
    required String securityQuestion,
    required String securityAnswer,
    required String pin,
  }) async {
    try {
      final response = await _dio.post('/api/patients', data: {
        'nationalId':       nationalId,
        'firstName':        firstName,
        'lastName':         lastName,
        'middleName':       middleName,
        'dateOfBirth':      dateOfBirth,
        'gender':           gender,
        'phoneNumber':      phoneNumber,
        'email':            email,
        'address':          address,
        'securityQuestion': securityQuestion,
        'securityAnswer':   securityAnswer,
        'pin':              pin,
      });

      final body = response.data as Map<String, dynamic>;
      return HieResult(
        success:    true,
        data:       body,
        nupi:       body['nupi']       as String?,
        blockIndex: body['blockIndex'] as int?,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error']?.toString()
                ?? e.message
                ?? 'Network error';
      debugPrint('[HIE] registerPatient error: $msg');
      return HieResult(success: false, error: msg);
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  RECORD ENCOUNTER
  //  Calls POST /api/patients/:nupi/visit
  //  Saves to Firestore + mints ENCOUNTER_RECORDED block.
  //  Requires an access token from a previous verify call.
  // ══════════════════════════════════════════════════════════════

  Future<HieResult> recordEncounter({
    required String nupi,
    required String accessToken,
    required String encounterType,
    required String chiefComplaint,
    String? practitionerName,
    Map<String, dynamic>? vitalSigns,
    List<Map<String, dynamic>>? diagnoses,
    String? notes,
    String? encounterDate,
  }) async {
    try {
      final response = await _dio.post(
        '/api/patients/$nupi/visit',
        data: {
          'encounterType':    encounterType,
          'chiefComplaint':   chiefComplaint,
          'practitionerName': practitionerName,
          'vitalSigns':       vitalSigns,
          'diagnoses':        diagnoses,
          'notes':            notes,
          'encounterDate':    encounterDate ?? DateTime.now().toIso8601String(),
        },
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final body = response.data as Map<String, dynamic>;
      return HieResult(
        success:    true,
        data:       body,
        blockIndex: body['blockIndex'] as int?,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error']?.toString()
                ?? e.message
                ?? 'Network error';
      debugPrint('[HIE] recordEncounter error: $msg');
      return HieResult(success: false, error: msg);
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  CREATE REFERRAL
  //  Calls POST /api/referrals on the gateway directly
  //  (the gateway is the source of truth for cross-facility referrals).
  //  Mints REFERRAL_ISSUED block.
  // ══════════════════════════════════════════════════════════════

  Future<HieResult> createReferral({
    required String referralId,
    required String patientNupi,
    required String patientName,
    required String fromFacilityId,
    required String fromFacilityName,
    required String toFacilityId,
    required String toFacilityName,
    required String reason,
    required String priority,
    String? clinicalNotes,
    required String createdBy,
    required String createdByName,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/api/referrals',
        data: {
          'referralId':      referralId,
          'patientNupi':     patientNupi,
          'patientName':     patientName,
          'fromFacilityId':  fromFacilityId,
          'fromFacilityName':fromFacilityName,
          'toFacilityId':    toFacilityId,
          'toFacilityName':  toFacilityName,
          'reason':          reason,
          'priority':        priority,
          'clinicalNotes':   clinicalNotes,
          'createdBy':       createdBy,
          'createdByName':   createdByName,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      final body = response.data as Map<String, dynamic>;
      return HieResult(
        success:    true,
        data:       body,
        blockIndex: body['blockIndex'] as int?,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error']?.toString()
                ?? e.message
                ?? 'Network error';
      debugPrint('[HIE] createReferral error: $msg');
      return HieResult(success: false, error: msg);
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  VERIFY PATIENT (get access token)
  //  Used before recording an encounter or creating a referral
  //  when no token is already stored.
  // ══════════════════════════════════════════════════════════════

  Future<HieResult> verifyByPin({
    required String nationalId,
    required String dateOfBirth,
    required String pin,
  }) async {
    try {
      final response = await _dio.post('/api/patients/verify/pin', data: {
        'nationalId': nationalId,
        'dob':        dateOfBirth,
        'pin':        pin,
      });
      final body = response.data as Map<String, dynamic>;
      return HieResult(
        success: true,
        data:    body,
        nupi:    body['nupi'] as String?,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error']?.toString()
                ?? e.message ?? 'Verification failed';
      return HieResult(success: false, error: msg);
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }
}