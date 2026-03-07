// lib/core/services/hie_api_service.dart
//
// FIXES applied:
//  1. registerPatient  → POST /api/patients/register  (was /api/patients)
//  2. recordEncounter  → POST /api/patients/encounter  (was /api/patients/:nupi/visit)
//                        nupi now in body, not in URL path
//  3. getSecurityQuestion → GET /api/verify/question   (was /api/patients/verify/question)
//  4. verifySecurityAnswer→ POST /api/verify/answer    (was /api/patients/verify/answer)
//  5. verifyByPin         → POST /api/verify/pin       (was /api/patients/verify/pin)
//  6. createReferral → field names aligned: toFacility/fromFacility/urgency
//                      (were toFacilityId/fromFacilityId/priority)

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

  /// Security question string from GET /api/verify/question.
  String? get question =>
      data?['question'] as String? ??
      data?['securityQuestion'] as String?;

  /// Full patient demographics map from POST /api/verify/answer.
  /// Gateway wraps it in data['patient']; falls back to the whole map.
  Map<String, dynamic>? get patientData =>
      (data?['patient'] as Map?)?.cast<String, dynamic>() ?? data;
}

class HieApiService {
  static HieApiService? _instance;
  late final Dio _dio;

  HieApiService._({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
      headers:        {'Content-Type': 'application/json'},
      // Never throw on non-2xx — we handle status codes manually
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

  // ── Safe body parser ──────────────────────────────────────────
  // Render returns plain-text "Not Found" on cold-start 404s — never throws.
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
    if (response?.data is String && (response!.data as String).isNotEmpty) {
      return response.data as String;
    }
    return e?.message ?? 'Network error';
  }

  // Wake Render free-tier before first real call (fire-and-forget)
  Future<void> _wakeUp() async {
    try {
      await _dio.get('/health',
          options: Options(receiveTimeout: const Duration(seconds: 20)));
    } catch (_) {}
  }

  bool _ok(Response r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  // ════════════════════════════════════════════════════════════════
  //  PATIENT REGISTRATION
  //  FIX: was POST /api/patients — correct is POST /api/patients/register
  // ════════════════════════════════════════════════════════════════

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

      final response = await _dio.post('/api/patients/register', data: {
        'nationalId':       nationalId,
        'dob':              dateOfBirth,  // gateway expects 'dob', not 'dateOfBirth'
        'name':             '$firstName $lastName'.trim(),
        'securityQuestion': securityQuestion,
        'securityAnswer':   securityAnswer,
        'pin':              pin,
      });

      final body = _parseBody(response.data);
      if (!_ok(response)) {
        return HieResult(success: false, error: _errorMsg(response, null));
      }

      return HieResult(
        success:    true,
        data:       body,
        nupi:       body?['nupi']       as String?,
        blockIndex: body?['blockIndex'] as int?,
      );
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  RECORD ENCOUNTER
  //  FIX: was POST /api/patients/:nupi/visit
  //       correct is POST /api/patients/encounter  (nupi in body)
  // ════════════════════════════════════════════════════════════════

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
    String? encounterId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/patients/encounter',
        data: {
          'nupi':             nupi,
          'encounterId':      encounterId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'encounterType':    encounterType,
          'encounterDate':    encounterDate ?? DateTime.now().toIso8601String(),
          'chiefComplaint':   chiefComplaint,
          'practitionerName': practitionerName,
        },
        options: Options(headers: {
          if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
        }),
      );

      final body = _parseBody(response.data);
      if (_ok(response)) {
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

  // ════════════════════════════════════════════════════════════════
  //  CREATE REFERRAL
  //  FIX: field names aligned with gateway schema:
  //    toFacilityId   → toFacility
  //    fromFacilityId → fromFacility  (gateway reads req.facilityId from auth header)
  //    priority       → urgency
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> createReferral({
    required String referralId,
    required String patientNupi,
    required String patientName,
    required String fromFacilityId,
    required String fromFacilityName,
    required String toFacilityId,
    required String toFacilityName,
    required String reason,
    required String priority,       // caller still passes "priority" — mapped to "urgency" below
    String? clinicalNotes,
    required String createdBy,
    required String createdByName,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/api/referrals',
        data: {
          'nupi':       patientNupi,
          'toFacility': toFacilityId,   // FIX: was toFacilityId
          'reason':     reason,
          'urgency':    priority,        // FIX: was priority
          'issuedBy':   createdByName,
          // Extra context fields — gateway ignores unknown keys
          'patientName':      patientName,
          'fromFacilityName': fromFacilityName,
          'toFacilityName':   toFacilityName,
          'clinicalNotes':    clinicalNotes,
        },
        options: Options(headers: {
          if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
        }),
      );

      final body = _parseBody(response.data);
      if (_ok(response)) {
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

  // ════════════════════════════════════════════════════════════════
  //  VERIFY BY PIN
  //  FIX: was POST /api/patients/verify/pin
  //       correct is POST /api/verify/pin
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> verifyByPin({
    required String nationalId,
    required String dateOfBirth,
    required String pin,
  }) async {
    try {
      final response = await _dio.post('/api/verify/pin', data: {
        'nationalId': nationalId,
        'dob':        dateOfBirth,
        'pin':        pin,
      });
      final body = _parseBody(response.data);
      if (_ok(response)) {
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

  // ════════════════════════════════════════════════════════════════
  //  FACILITY DIRECTORY  →  GET /api/facilities
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getFacilities({String? query, String? county}) async {
    try {
      final params = <String, dynamic>{};
      if (query  != null && query.isNotEmpty)  params['q']      = query;
      if (county != null && county.isNotEmpty) params['county'] = county;

      final response = await _dio.get('/api/facilities',
          queryParameters: params.isEmpty ? null : params);

      final body = _parseBody(response.data);
      if (_ok(response)) return HieResult(success: true, data: body);
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  GET SECURITY QUESTION
  //  FIX: was GET /api/patients/verify/question
  //       correct is GET /api/verify/question
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getSecurityQuestion({
    required String nationalId,
    required String dob,
  }) async {
    try {
      final response = await _dio.get(
        '/api/verify/question',
        queryParameters: {'nationalId': nationalId, 'dob': dob},
      );
      final body = _parseBody(response.data);
      if (_ok(response)) return HieResult(success: true, data: body);
      return HieResult(success: false, error: _errorMsg(response, null));
    } on DioException catch (e) {
      return HieResult(success: false, error: _errorMsg(e.response, e));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  VERIFY SECURITY ANSWER
  //  FIX: was POST /api/patients/verify/answer
  //       correct is POST /api/verify/answer
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> verifySecurityAnswer({
    required String nationalId,
    required String dob,
    required String answer,
    String? facilityId,
  }) async {
    try {
      final response = await _dio.post('/api/verify/answer', data: {
        'nationalId': nationalId,
        'dob':        dob,
        'answer':     answer,
        if (facilityId != null) 'facilityId': facilityId,
      });
      final body = _parseBody(response.data);
      if (_ok(response)) {
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