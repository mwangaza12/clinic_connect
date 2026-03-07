// lib/core/services/hie_api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HieResult — generic result wrapper for all gateway calls
// ─────────────────────────────────────────────────────────────────────────────
class HieResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final int? blockIndex;
  final String? nupi;

  // ── Lookup-specific fields ────────────────────────────────────────
  /// The security question returned by GET /verify/question
  final String? question;

  /// Full patient demographics returned by POST /verify/answer
  final Map<String, dynamic>? patientData;

  /// Short-lived access token returned by POST /verify/answer
  final String? accessToken;

  const HieResult({
    required this.success,
    this.data,
    this.error,
    this.blockIndex,
    this.nupi,
    this.question,
    this.patientData,
    this.accessToken,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HieApiService
// ─────────────────────────────────────────────────────────────────────────────
class HieApiService {
  static HieApiService? _instance;
  late final Dio _dio;

  HieApiService._({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
      headers:        {'Content-Type': 'application/json'},
      // Never throw on non-2xx — we inspect status codes manually
      validateStatus: (_) => true,
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody:  true,
        responseBody: true,
        logPrint: (o) => debugPrint('[HIE] $o'),
      ));
    }
  }

  static void init(String baseUrl) {
    _instance = HieApiService._(baseUrl: baseUrl);
  }

  static HieApiService get instance {
    assert(_instance != null, 'HieApiService.init() must be called before use');
    return _instance!;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Safely parses response body regardless of type.
  /// Render sometimes returns plain-text on cold-start 404s.
  Map<String, dynamic>? _parseBody(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  String _errorMsg(Response? response, DioException? e) {
    final body = _parseBody(response?.data);
    if (body != null) {
      return body['error']?.toString() ??
             body['message']?.toString() ??
             'Server error ${response?.statusCode}';
    }
    if (response?.data is String &&
        (response!.data as String).isNotEmpty) {
      return response.data as String;
    }
    return e?.message ?? 'Network error';
  }

  bool _isOk(Response r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  /// Pings /health to wake Render free-tier before a real call.
  Future<void> _wakeUp() async {
    try {
      await _dio.get('/health',
          options: Options(receiveTimeout: const Duration(seconds: 20)));
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════
  //  PATIENT REGISTRATION  →  POST /api/patients
  // ══════════════════════════════════════════════════════════════════

  Future<HieResult> registerPatient({
    required String nationalId,
    required String firstName,
    required String lastName,
    String? middleName,
    required String dateOfBirth,
    required String gender,
    String? phoneNumber,
    String? email,
    Map<String, String?>? address,
    required String securityQuestion,
    required String securityAnswer,
    required String pin,
  }) async {
    try {
      await _wakeUp();

      final response = await _dio.post('/api/patients', data: {
        'nationalId':       nationalId,
        'firstName':        firstName,
        'lastName':         lastName,
        if (middleName != null) 'middleName': middleName,
        'dateOfBirth':      dateOfBirth,
        'gender':           gender,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        'securityQuestion': securityQuestion,
        'securityAnswer':   securityAnswer,
        'pin':              pin,
      });

      final body = _parseBody(response.data);

      if (!_isOk(response)) {
        final msg = _errorMsg(response, null);
        debugPrint('[HIE] registerPatient failed (${response.statusCode}): $msg');
        return HieResult(success: false, error: msg);
      }

      return HieResult(
        success:    true,
        data:       body,
        nupi:       body?['nupi']       as String?,
        blockIndex: body?['blockIndex'] as int?,
      );
    } on DioException catch (e) {
      final msg = _errorMsg(e.response, e);
      debugPrint('[HIE] registerPatient DioException: $msg');
      return HieResult(success: false, error: msg);
    } catch (e) {
      debugPrint('[HIE] registerPatient unexpected: $e');
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  STEP 1 — GET SECURITY QUESTION
  //  GET /api/patients/verify/question?nationalId=X&dob=Y
  // ══════════════════════════════════════════════════════════════════

  Future<HieResult> getSecurityQuestion({
    required String nationalId,
    required String dob,
  }) async {
    try {
      final response = await _dio.get(
        '/api/patients/verify/question',
        queryParameters: {'nationalId': nationalId, 'dob': dob},
      );

      final body = _parseBody(response.data);

      if (!_isOk(response)) {
        return HieResult(success: false, error: _errorMsg(response, null));
      }

      // Gateway returns: { success: true, question: "..." }
      final question = body?['question'] as String?;
      if (question == null || question.isEmpty) {
        return HieResult(
          success: false,
          error:   'No security question returned for this patient',
        );
      }

      return HieResult(success: true, data: body, question: question);
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  STEP 2 — VERIFY SECURITY ANSWER → FULL DEMOGRAPHICS + TOKEN
  //  POST /api/patients/verify/answer
  //  { nationalId, dob, answer }
  //  ← { token, nupi, patient: { ...demographics... },
  //       facilitiesVisited, encounterIndex }
  // ══════════════════════════════════════════════════════════════════

  Future<HieResult> verifySecurityAnswer({
    required String nationalId,
    required String dob,
    required String answer,
    required String facilityId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/patients/verify/answer',
        data: {
          'nationalId': nationalId,
          'dob':        dob,
          'answer':     answer,
          'facilityId': facilityId,
        },
      );

      final body = _parseBody(response.data);

      if (!_isOk(response)) {
        return HieResult(success: false, error: _errorMsg(response, null));
      }

      // Gateway returns:
      // { token, nupi, facilitiesVisited, encounterIndex,
      //   patient: { name, gender, dateOfBirth, phoneNumber,
      //              county, subCounty, bloodGroup,
      //              registeredFacility, facilityCounty,
      //              isCurrentFacility } }
      final token   = body?['token']  as String?;
      final nupi    = body?['nupi']   as String?;
      final patient = body?['patient'] as Map<String, dynamic>?;

      if (patient == null) {
        return HieResult(
          success: false,
          error:   'No patient data returned — check gateway /verify/answer response',
        );
      }

      // Flatten the token and nupi into the patientData map so
      // PatientLookupPage and CreateEncounterPage have everything in one place.
      final patientData = {
        ...patient,
        'nupi':             nupi,
        'isCurrentFacility': body?['isCurrentFacility'] ?? false,
        'facilitiesVisited': body?['facilitiesVisited'],
        'encounterIndex':    body?['encounterIndex'],
      };

      return HieResult(
        success:     true,
        data:        body,
        nupi:        nupi,
        accessToken: token,
        patientData: patientData,
      );
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  RECORD ENCOUNTER  →  POST /api/patients/:nupi/visit
  //  Requires Bearer token obtained from verifySecurityAnswer()
  // ══════════════════════════════════════════════════════════════════

  Future<HieResult> recordEncounter({
    required String nupi,
    required String accessToken,   // token from verifySecurityAnswer
    required String encounterType,
    required String chiefComplaint,
    String? encounterId,           // local UUID — stored as externalId on chain
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
          if (encounterId != null)      'encounterId':      encounterId,
          if (practitionerName != null) 'practitionerName': practitionerName,
          if (vitalSigns != null)       'vitalSigns':       vitalSigns,
          if (diagnoses != null)        'diagnoses':        diagnoses,
          if (notes != null)            'notes':            notes,
          'encounterDate': encounterDate ?? DateTime.now().toIso8601String(),
        },
        options: Options(
          headers: {
            if (accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final body = _parseBody(response.data);
      if (_isOk(response)) {
        return HieResult(
          success:    true,
          data:       body,
          blockIndex: body?['blockIndex'] as int?,
        );
      }
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  CREATE REFERRAL  →  POST /api/referrals
  // ══════════════════════════════════════════════════════════════════

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
          'referralId':       referralId,
          'patientNupi':      patientNupi,
          'patientName':      patientName,
          'fromFacilityId':   fromFacilityId,
          'fromFacilityName': fromFacilityName,
          'toFacilityId':     toFacilityId,
          'toFacilityName':   toFacilityName,
          'reason':           reason,
          'priority':         priority,
          if (clinicalNotes != null) 'clinicalNotes': clinicalNotes,
          'createdBy':        createdBy,
          'createdByName':    createdByName,
        },
        options: Options(
          headers: {
            if (accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final body = _parseBody(response.data);
      if (_isOk(response)) {
        return HieResult(
          success:    true,
          data:       body,
          blockIndex: body?['blockIndex'] as int?,
        );
      }
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  VERIFY BY PIN  →  POST /api/patients/verify/pin
  // ══════════════════════════════════════════════════════════════════

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
      final body = _parseBody(response.data);
      if (_isOk(response)) {
        return HieResult(
          success:     true,
          data:        body,
          nupi:        body?['nupi']  as String?,
          accessToken: body?['token'] as String?,
        );
      }
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }
}