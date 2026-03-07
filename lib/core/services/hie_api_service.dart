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
}