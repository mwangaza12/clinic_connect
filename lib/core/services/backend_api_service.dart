// lib/core/services/backend_api_service.dart
//
// The CORRECT call chain:
//   Flutter → Facility Backend (clinic-connect-sxct.onrender.com) → HIE Gateway
//
// This service replaces direct HieApiService calls everywhere EXCEPT
// the setup wizard (which still talks to the gateway to fetch Firebase config).
//
// The facility backend URL is saved during setup (StorageKeys.facilityBackendUrl)
// from the apiUrl field in the firebase-config response.
//
// The backend holds the facility API key in its env vars — so the mobile
// app never needs to send credentials on every request.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

class BackendApiService {
  static BackendApiService? _instance;
  late final Dio _dio;

  static const _storage = FlutterSecureStorage();

  BackendApiService._({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (_) => true,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: StorageKeys.accessToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint('[Backend] $o'),
      ));
    }
  }

  /// Initialise from a known base URL (called after setup wizard saves it).
  static void init(String backendUrl) {
    _instance = BackendApiService._(baseUrl: backendUrl);
  }

  /// Lazy-init from secure storage — safe to call at any point after setup.
  static Future<BackendApiService> get instanceAsync async {
    if (_instance != null) return _instance!;
    final url = await _storage.read(key: StorageKeys.facilityBackendUrl);
    if (url == null || url.isEmpty) {
      throw StateError(
        'BackendApiService: facilityBackendUrl not set. '
        'Run the setup wizard first.',
      );
    }
    _instance = BackendApiService._(baseUrl: url);
    return _instance!;
  }

  static BackendApiService get instance {
    assert(
      _instance != null,
      'BackendApiService.init() must be called before use, '
      'or use BackendApiService.instanceAsync.',
    );
    return _instance!;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

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

  bool _ok(Response r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  /// Returns true for DioException types that represent a connectivity failure
  /// (no network, DNS failure, timeout) as opposed to a real server response.
  ///
  /// These should be RETHROWN so the caller (e.g. patient registration page)
  /// can handle them as offline conditions and save locally.
  bool _isConnectivityError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:   // Failed host lookup, refused
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return false;
    }
  }

  Future<BackendResult> _requestWithRetry(
    Future<Response> Function() requestFn, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    String? nupi,
  }) async {
    int retryCount = 0;
    Duration currentDelay = initialDelay;

    while (retryCount < maxRetries) {
      try {
        final response = await requestFn();
        final body = _parseBody(response.data);

        if (response.statusCode == 429) {
          retryCount++;
          if (retryCount >= maxRetries) {
            return BackendResult(
              success: false,
              error: 'Rate limited after $maxRetries retries. Please try again later.',
            );
          }
          await Future.delayed(currentDelay);
          currentDelay *= 2;
          continue;
        }

        if (response.statusCode == 500) {
          final diagnostics =
              body?['issue']?[0]?['diagnostics']?.toString() ?? '';
          if (diagnostics.contains('429')) {
            retryCount++;
            if (retryCount >= maxRetries) {
              return BackendResult(
                success: false,
                error: 'Rate limited (upstream). Please wait and try again.',
              );
            }
            await Future.delayed(currentDelay);
            currentDelay *= 2;
            continue;
          }
        }

        if (_ok(response)) {
          return BackendResult(
            success: true,
            data: body,
            nupi: nupi ?? body?['nupi'] as String?,
          );
        }
        return BackendResult(success: false, error: _errorMsg(response, null));

      } on DioException catch (e) {
        // ── FIX ───────────────────────────────────────────────────────────
        // Connectivity errors (no network, DNS failure, timeout) must be
        // RETHROWN so the caller can detect offline mode and save locally.
        //
        // Previously ALL DioExceptions were caught and converted into a
        // BackendResult(success: false), so the registration page never saw
        // the exception and its offline-save path was never triggered.
        //
        // Only rate-limit errors (429) are retried here; everything else
        // that isn't a connectivity error becomes a BackendResult as before.
        if (_isConnectivityError(e)) {
          debugPrint('[Backend] Connectivity error — rethrowing for offline handling: ${e.type}');
          rethrow; // ← lets patient_registration_page catch it and save locally
        }

        if (e.response?.statusCode == 429) {
          retryCount++;
          if (retryCount >= maxRetries) {
            return BackendResult(
              success: false,
              error: 'Rate limited. Please try again later.',
            );
          }
          await Future.delayed(currentDelay);
          currentDelay *= 2;
          continue;
        }

        return BackendResult(success: false, error: _errorMsg(e.response, e));
      }
    }

    return BackendResult(success: false, error: 'Max retries exceeded');
  }

  // ══════════════════════════════════════════════════════════════════
  //  PATIENT — POST /api/patients
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> registerPatient({
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
    return _requestWithRetry(() => _dio.post('/api/patients', data: {
          'nationalId':       nationalId,
          'firstName':        firstName,
          'lastName':         lastName,
          if (middleName != null && middleName.isNotEmpty)
            'middleName':     middleName,
          'dateOfBirth':      dateOfBirth,
          'gender':           gender,
          'securityQuestion': securityQuestion,
          'securityAnswer':   securityAnswer,
          'pin':              pin,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber':    phoneNumber,
          if (email != null && email.isNotEmpty)
            'email':          email,
          'address': {
            'county':    address?['county']    ?? '',
            'subCounty': address?['subCounty'] ?? '',
            'ward':      address?['ward']      ?? '',
            'village':   address?['village']   ?? '',
          },
        }));
  }

  // ══════════════════════════════════════════════════════════════════
  //  VERIFY — GET /api/patients/verify/question
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getSecurityQuestion({
    required String nationalId,
    required String dob,
  }) async {
    return _requestWithRetry(() => _dio.get(
          '/api/patients/verify/question',
          queryParameters: {'nationalId': nationalId, 'dob': dob},
        ));
  }

  // ══════════════════════════════════════════════════════════════════
  //  VERIFY — POST /api/patients/verify/answer
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> verifySecurityAnswer({
    required String nationalId,
    required String dob,
    required String answer,
  }) async {
    return _requestWithRetry(() => _dio.post('/api/patients/verify/answer', data: {
          'nationalId': nationalId,
          'dob': dob,
          'answer': answer,
        }));
  }

  // ══════════════════════════════════════════════════════════════════
  //  ENCOUNTER — POST /api/patients/:nupi/visit
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> recordEncounter({
    required String nupi,
    required String encounterType,
    required String chiefComplaint,
    String? practitionerName,
    Map<String, dynamic>? vitalSigns,
    List<Map<String, dynamic>>? diagnoses,
    String? notes,
    String? encounterDate,
    String? encounterId,
  }) async {
    return _requestWithRetry(
      () => _dio.post('/api/patients/$nupi/visit', data: {
        'encounterId': encounterId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'encounterType': encounterType,
        'encounterDate':
            encounterDate ?? DateTime.now().toIso8601String(),
        'chiefComplaint': chiefComplaint,
        'practitionerName': practitionerName,
        if (vitalSigns != null) 'vitalSigns': vitalSigns,
        if (diagnoses != null && diagnoses.isNotEmpty)
          'diagnoses': diagnoses,
        if (notes != null) 'notes': notes,
      }),
      nupi: nupi,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  FEDERATED — GET /api/patients/:nupi/federated
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getFederatedData({required String nupi}) async {
    return _requestWithRetry(
      () => _dio.get('/api/patients/$nupi/federated'),
      nupi: nupi,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  FACILITIES — GET /api/facilities
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getFacilities({
    String? query,
    String? county,
  }) async {
    final params = <String, dynamic>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (county != null && county.isNotEmpty) params['county'] = county;

    return _requestWithRetry(() => _dio.get(
          '/api/facilities',
          queryParameters: params.isEmpty ? null : params,
        ));
  }

  // ══════════════════════════════════════════════════════════════════
  //  REFERRALS — POST /api/referrals
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> createReferral({
    required String patientNupi,
    required String toFacilityId,
    required String reason,
    required String priority,
    String? issuedBy,
    String? patientName,
    String? fromFacilityName,
    String? toFacilityName,
    String? clinicalNotes,
  }) async {
    return _requestWithRetry(() => _dio.post('/api/referrals', data: {
          'nupi': patientNupi,
          'toFacility': toFacilityId,
          'reason': reason,
          'urgency': priority,
          'issuedBy': issuedBy,
          'patientName': patientName,
          'fromFacilityName': fromFacilityName,
          'toFacilityName': toFacilityName,
          'clinicalNotes': clinicalNotes,
        }));
  }

  // ══════════════════════════════════════════════════════════════════
  //  REFERRALS — GET /api/referrals/incoming/:facilityId
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getIncomingReferrals({
    required String facilityId,
  }) async {
    return _requestWithRetry(
      () => _dio.get('/api/referrals/incoming/$facilityId'),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  REFERRALS — GET /api/referrals/outgoing/:facilityId
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getOutgoingReferrals({
    required String facilityId,
  }) async {
    return _requestWithRetry(
      () => _dio.get('/api/referrals/outgoing/$facilityId'),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  REFERRALS — PATCH /api/referrals/:referralId/status
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> updateReferralStatus({
    required String referralId,
    required String status,
    String? notes,
  }) async {
    return _requestWithRetry(
      () => _dio.patch('/api/referrals/$referralId/status', data: {
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  PATIENT LOOKUP — GET /api/patients/nupi/:nupi
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> lookupPatient({required String nupi}) async {
    return _requestWithRetry(
      () => _dio.get('/api/patients/nupi/$nupi'),
      nupi: nupi,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  FHIR ENCOUNTER — GET /fhir/Encounter/:encounterId
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getFhirEncounter({
    required String encounterId,
    String? facilityId,
  }) async {
    final params = <String, dynamic>{};
    if (facilityId != null && facilityId.isNotEmpty) {
      params['facility'] = facilityId;
    }
    return _requestWithRetry(
      () => _dio.get(
        '/fhir/Encounter/$encounterId',
        queryParameters: params.isEmpty ? null : params,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  REFERRALS — GET /api/referrals/:referralId
  // ══════════════════════════════════════════════════════════════════

  Future<BackendResult> getReferralById({
    required String referralId,
  }) async {
    return _requestWithRetry(
      () => _dio.get('/api/referrals/$referralId'),
    );
  }
}

// ── Result type ───────────────────────────────────────────────────────────────

class BackendResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final String? nupi;

  const BackendResult({
    required this.success,
    this.data,
    this.error,
    this.nupi,
  });

  String? get question =>
      data?['question'] as String? ??
      data?['securityQuestion'] as String?;

  Map<String, dynamic>? get patientData =>
      (data?['patient'] as Map?)?.cast<String, dynamic>() ?? data;
}