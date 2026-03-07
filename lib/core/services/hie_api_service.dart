// lib/core/services/hie_api_service.dart

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

  /// The security question string returned by GET /verify/question.
  /// Reads data['question'] or data['securityQuestion'].
  String? get question =>
      data?['question'] as String? ??
      data?['securityQuestion'] as String?;

  /// Full patient demographics map returned by POST /verify/answer.
  /// Reads data['patient'] if present, otherwise the whole data map.
  Map<String, dynamic>? get patientData =>
      (data?['patient'] as Map?)?.cast<String, dynamic>() ?? data;
}

class HieApiService {
  static HieApiService? _instance;
  late final Dio _dio;

  HieApiService._({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 60), // longer for Render cold start
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Content-Type': 'application/json'},
      // Don't throw on non-2xx — we handle errors manually so no cast crashes
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

  // ── Safe response body parser ─────────────────────────────────────────────
  // Render returns plain-text "Not Found" on cold-start 404s.
  // This never throws a cast exception regardless of body type.
  Map<String, dynamic>? _parseBody(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null; // plain string / null — treat as no body
  }

  String _errorMsg(Response? response, DioException? e) {
    final body = _parseBody(response?.data);
    if (body != null) {
      return body['error']?.toString() ??
             body['message']?.toString() ??
             'Server error ${response?.statusCode}';
    }
    if (response?.data is String && (response!.data as String).isNotEmpty) {
      return response.data as String;
    }
    return e?.message ?? 'Network error';
  }

  // ── Wake the Render service before the first real call ───────────────────
  // Render free-tier spins down after 15 min idle. This ping happens
  // in the background; if it fails we still proceed with the real call.
  Future<void> _wakeUp() async {
    try {
      await _dio.get('/health',
        options: Options(receiveTimeout: const Duration(seconds: 20)));
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PATIENT REGISTRATION  →  POST /api/patients
  // ══════════════════════════════════════════════════════════════════════════

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
      // Wake Render first (fire-and-forget style — doesn't delay if already up)
      await _wakeUp();

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

      final body = _parseBody(response.data);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
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

  // ══════════════════════════════════════════════════════════════════════════
  //  RECORD ENCOUNTER  →  POST /api/patients/:nupi/visit
  // ══════════════════════════════════════════════════════════════════════════

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
    String? encounterId,  // alias — same as nupi in this context, kept for compatibility
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
          headers: {
            if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final body = _parseBody(response.data);
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
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

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE REFERRAL  →  POST /api/referrals
  // ══════════════════════════════════════════════════════════════════════════

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
          'clinicalNotes':    clinicalNotes,
          'createdBy':        createdBy,
          'createdByName':    createdByName,
        },
        options: Options(
          headers: {
            if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final body = _parseBody(response.data);
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
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

  // ══════════════════════════════════════════════════════════════════════════
  //  VERIFY BY PIN  →  POST /api/patients/verify/pin
  // ══════════════════════════════════════════════════════════════════════════

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
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return HieResult(
          success: true,
          data:    body,
          nupi:    body?['nupi'] as String?,
        );
      }
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FACILITY DIRECTORY  →  GET /api/facilities
  //  Returns all active facilities registered on AfyaChain.
  //  Used by the referral form to populate the facility picker.
  // ══════════════════════════════════════════════════════════════════════════

  Future<HieResult> getFacilities({String? query, String? county}) async {
    try {
      final params = <String, dynamic>{};
      if (query  != null && query.isNotEmpty)  params['q']      = query;
      if (county != null && county.isNotEmpty) params['county'] = county;

      final response = await _dio.get('/api/facilities',
          queryParameters: params.isEmpty ? null : params);

      final body = _parseBody(response.data);
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return HieResult(success: true, data: body);
      }
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }
  // ══════════════════════════════════════════════════════════════════════════
  //  GET SECURITY QUESTION  →  GET /api/patients/verify/question
  //  Step 1 of the 2-step patient identity verification flow.
  //  Returns the security question registered for this patient.
  // ══════════════════════════════════════════════════════════════════════════

  Future<HieResult> getSecurityQuestion({
    required String nationalId,
    required String dob, // YYYY-MM-DD
  }) async {
    try {
      final response = await _dio.get(
        '/api/patients/verify/question',
        queryParameters: {'nationalId': nationalId, 'dob': dob},
      );
      final body = _parseBody(response.data);
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return HieResult(success: true, data: body);
      }
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERIFY SECURITY ANSWER  →  POST /api/patients/verify/answer
  //  Step 2 of the 2-step verification flow.
  //  Returns accessToken + nupi + patient on success.
  // ══════════════════════════════════════════════════════════════════════════

  Future<HieResult> verifySecurityAnswer({
    required String nationalId,
    required String dob, // YYYY-MM-DD
    required String answer,
    String? facilityId, // optional — sent to backend for audit logging
  }) async {
    try {
      final response = await _dio.post('/api/patients/verify/answer', data: {
        'nationalId': nationalId,
        'dob':        dob,
        'answer':     answer,
        if (facilityId != null) 'facilityId': facilityId,
      });
      final body = _parseBody(response.data);
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return HieResult(
          success: true,
          data:    body,
          nupi:    body?['nupi'] as String?,
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