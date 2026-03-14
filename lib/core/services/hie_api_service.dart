import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

// Add this extension at the top
extension FirstOrNullExtension<E> on List<E> {
  /// Returns the first element, or null if the list is empty.
  E? get firstOrNull => isEmpty ? null : first;
}

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
  Map<String, dynamic>? get patientData =>
      (data?['patient'] as Map?)?.cast<String, dynamic>() ?? data;
}

class HieApiService {
  static HieApiService? _instance;
  late final Dio _dio;

  static const _storage = FlutterSecureStorage();

  HieApiService._({required String baseUrl}) {
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
          final facilityId = await _storage.read(key: StorageKeys.facilityId);
          final apiKey = await _storage.read(key: StorageKeys.facilityApiKey);
          if (facilityId != null && facilityId.isNotEmpty) {
            options.headers['X-Facility-Id'] = facilityId;
          }
          if (apiKey != null && apiKey.isNotEmpty) {
            options.headers['X-Api-Key'] = apiKey;
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
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

  Future<void> _wakeUp() async {
    try {
      await _dio.get('/health',
          options: Options(receiveTimeout: const Duration(seconds: 20)));
    } catch (_) {}
  }

  bool _ok(Response r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  /// Helper method to handle rate limiting with retries
  Future<HieResult> _requestWithRetry(
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

        // Handle rate limiting (429)
        if (response.statusCode == 429) {
          retryCount++;
          if (retryCount >= maxRetries) {
            return HieResult(
              success: false,
              error: 'Rate limited after $maxRetries retries. Please try again later.',
            );
          }
          debugPrint('⏳ Rate limited (429), retrying in ${currentDelay.inMilliseconds}ms... (Attempt $retryCount/$maxRetries)');
          await Future.delayed(currentDelay);
          currentDelay *= 2; // Exponential backoff
          continue;
        }

        // Handle gateway wrapping a 429 as 500
        if (response.statusCode == 500) {
          final diagnostics = body?['issue']?[0]?['diagnostics']?.toString() ?? '';
          if (diagnostics.contains('429')) {
            retryCount++;
            if (retryCount >= maxRetries) {
              return HieResult(
                success: false,
                error: 'Rate limited (upstream). Please wait a moment and try again.',
              );
            }
            debugPrint('⏳ Upstream rate limited (500/429), retrying in ${currentDelay.inMilliseconds}ms... (Attempt $retryCount/$maxRetries)');
            await Future.delayed(currentDelay);
            currentDelay *= 2;
            continue;
          }
        }

        if (_ok(response)) {
          return HieResult(
            success: true,
            data: body,
            nupi: nupi ?? body?['nupi'] as String?,
          );
        }
        return HieResult(success: false, error: _errorMsg(response, null));
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          retryCount++;
          if (retryCount >= maxRetries) {
            return HieResult(
              success: false,
              error: 'Rate limited after $maxRetries retries. Please try again later.',
            );
          }
          debugPrint('⏳ Rate limited (429), retrying in ${currentDelay.inMilliseconds}ms... (Attempt $retryCount/$maxRetries)');
          await Future.delayed(currentDelay);
          currentDelay *= 2;
          continue;
        }
        return HieResult(success: false, error: _errorMsg(e.response, e));
      }
    }

    return HieResult(success: false, error: 'Max retries exceeded');
  }

  // ════════════════════════════════════════════════════════════════
  //  PATIENT REGISTRATION  →  POST /api/patients/register
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

      return await _requestWithRetry(() => _dio.post('/api/patients/register', data: {
        'nationalId': nationalId,
        'dob': dateOfBirth,
        'name': '$firstName $lastName'.trim(),
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
        'pin': pin,
      }));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  RECORD ENCOUNTER  →  POST /api/patients/encounter
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
      return await _requestWithRetry(
        () => _dio.post(
          '/api/patients/encounter',
          data: {
            'nupi': nupi,
            'encounterId': encounterId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            'encounterType': encounterType,
            'encounterDate': encounterDate ?? DateTime.now().toIso8601String(),
            'chiefComplaint': chiefComplaint,
            'practitionerName': practitionerName,
          },
          options: Options(headers: {
            if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
          }),
        ),
        nupi: nupi,
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  CREATE REFERRAL  →  POST /api/referrals
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
    required String priority,
    String? clinicalNotes,
    required String createdBy,
    required String createdByName,
    required String accessToken,
  }) async {
    try {
      return await _requestWithRetry(
        () => _dio.post(
          '/api/referrals',
          data: {
            'nupi': patientNupi,
            'toFacility': toFacilityId,
            'reason': reason,
            'urgency': priority,
            'issuedBy': createdByName,
            'patientName': patientName,
            'fromFacilityName': fromFacilityName,
            'toFacilityName': toFacilityName,
            'clinicalNotes': clinicalNotes,
          },
          options: Options(headers: {
            if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
          }),
        ),
        nupi: patientNupi,
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  VERIFY BY PIN  →  POST /api/verify/pin
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> verifyByPin({
    required String nationalId,
    required String dateOfBirth,
    required String pin,
  }) async {
    try {
      return await _requestWithRetry(() => _dio.post('/api/verify/pin', data: {
        'nationalId': nationalId,
        'dob': dateOfBirth,
        'pin': pin,
      }));
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
      if (query != null && query.isNotEmpty) params['q'] = query;
      if (county != null && county.isNotEmpty) params['county'] = county;

      return await _requestWithRetry(() => _dio.get(
            '/api/facilities',
            queryParameters: params.isEmpty ? null : params,
          ));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  GET SECURITY QUESTION  →  GET /api/verify/question
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getSecurityQuestion({
    required String nationalId,
    required String dob,
  }) async {
    try {
      return await _requestWithRetry(() => _dio.get(
            '/api/verify/question',
            queryParameters: {'nationalId': nationalId, 'dob': dob},
          ));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  VERIFY SECURITY ANSWER  →  POST /api/verify/answer
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> verifySecurityAnswer({
    required String nationalId,
    required String dob,
    required String answer,
    String? facilityId, // Kept for compatibility but not used in body
  }) async {
    try {
      return await _requestWithRetry(() => _dio.post('/api/verify/answer', data: {
        'nationalId': nationalId,
        'dob': dob,
        'answer': answer,
      }));
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  LOOKUP PATIENT  →  GET /api/patients/:nupi
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> lookupPatient({required String nupi}) async {
    try {
      return await _requestWithRetry(
        () => _dio.get('/api/patients/$nupi'),
        nupi: nupi,
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  FETCH EVERYTHING BUNDLE  →  GET /api/fhir/Patient/:nupi/$everything
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> fetchEverything({
    required String nupi,
    required String accessToken,
    String? registeredFacilityId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (registeredFacilityId != null && registeredFacilityId.isNotEmpty) {
        queryParams['registeredFacility'] = registeredFacilityId;
      }

      return await _requestWithRetry(
        () => _dio.get(
          '/api/fhir/Patient/$nupi/\$everything',
          queryParameters: queryParams.isEmpty ? null : queryParams,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
        nupi: nupi,
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  FETCH DEMOGRAPHICS  →  GET /api/fhir/Patient/:nupi
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> fetchDemographics({
    required String nupi,
    required String accessToken,
    String? facilityId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (facilityId != null && facilityId.isNotEmpty) {
        queryParams['facility'] = facilityId;
      }

      final result = await _requestWithRetry(
        () => _dio.get(
          '/api/fhir/Patient/$nupi',
          queryParameters: queryParams.isEmpty ? null : queryParams,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
        nupi: nupi,
      );

      if (!result.success || result.data == null) {
        return result;
      }

      final body = result.data!;

      // Handle OperationOutcome errors
      if (body['resourceType'] == 'OperationOutcome') {
        return HieResult(
          success: false,
          error: body['issue']?[0]?['diagnostics'] ?? 'Unknown error',
        );
      }

      final nameObj = (body['name'] as List?)?.firstOrNull as Map?;
      final given = (nameObj?['given'] as List?)?.join(' ') ?? '';
      final family = nameObj?['family']?.toString() ?? '';
      final fullName = nameObj?['text']?.toString() ?? '$given $family'.trim();

      final telecom = body['telecom'] as List? ?? [];
      String phone = '';
      for (var t in telecom) {
        if (t['system'] == 'phone') {
          phone = t['value']?.toString() ?? '';
          break;
        }
      }

      final addresses = body['address'] as List? ?? [];
      final addr = addresses.isNotEmpty
          ? (addresses.first as Map)
          : <String, dynamic>{};

      final extensions = body['extension'] as List? ?? [];
      String bloodGroup = '';
      for (var ext in extensions) {
        if (ext['url']?.toString().contains('blood-group') == true) {
          bloodGroup = ext['valueString']?.toString() ?? '';
          break;
        }
      }

      final identifiers = body['identifier'] as List? ?? [];
      String nationalId = '';
      for (var id in identifiers) {
        if (id['system']?.toString().contains('national') == true ||
            id['type']?['coding']?[0]?['code'] == 'NI') {
          nationalId = id['value']?.toString() ?? '';
          break;
        }
      }
      if (nationalId.isEmpty && identifiers.isNotEmpty) {
        nationalId = identifiers.first['value']?.toString() ?? '';
      }

      final meta = (body['meta'] as Map?) ?? {};

      return HieResult(
        success: true,
        nupi: nupi,
        data: {
          'nupi': nupi,
          'name': fullName,
          'gender': body['gender']?.toString() ?? '',
          'dateOfBirth': body['birthDate']?.toString() ?? '',
          'phoneNumber': phone,
          'nationalId': nationalId,
          'county': addr['district']?.toString() ?? '',
          'subCounty': addr['city']?.toString() ?? '',
          'village': addr['line']?.isNotEmpty == true
              ? addr['line'][0]?.toString() ?? ''
              : '',
          'bloodGroup': bloodGroup,
          'registeredFacility': meta['sourceName']?.toString() ?? '',
          'registeredFacilityId': meta['source']?.toString() ?? '',
        },
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  FETCH ENCOUNTERS  →  GET /api/fhir/Patient/:nupi/Encounter
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> fetchEncounters({
    required String nupi,
    required String accessToken,
    String? facilityId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (facilityId != null && facilityId.isNotEmpty) {
        queryParams['facility'] = facilityId;
      }

      final result = await _requestWithRetry(
        () => _dio.get(
          '/api/fhir/Patient/$nupi/Encounter',
          queryParameters: queryParams.isEmpty ? null : queryParams,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
        nupi: nupi,
      );

      // Handle OperationOutcome errors
      if (!result.success && result.data != null) {
        final body = result.data;
        if (body?['resourceType'] == 'OperationOutcome') {
          if (body?['issue']?[0]?['code'] == 'not-found') {
            return HieResult(
              success: true,
              data: {'resourceType': 'Bundle', 'entry': []},
            );
          }
        }
      }

      // 404 = no encounters at this facility — treat as empty bundle
      if (!result.success && result.error?.contains('404') == true) {
        return HieResult(
          success: true,
          data: {'resourceType': 'Bundle', 'entry': []},
        );
      }

      return result;
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  GET ENCOUNTER BY ID  →  GET /api/fhir/Encounter/:id
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getFhirEncounter({
    required String encounterId,
    required String accessToken,
    String? facilityId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (facilityId != null && facilityId.isNotEmpty) {
        queryParams['facility'] = facilityId;
      }

      return await _requestWithRetry(
        () => _dio.get(
          '/api/fhir/Encounter/$encounterId',
          queryParameters: queryParams.isEmpty ? null : queryParams,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  GET REFERRALS  →  GET /api/referrals/incoming/:id  or  /outgoing/:id
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getReferrals({
    required String direction,
    required String facilityId,
  }) async {
    try {
      return await _requestWithRetry(
        () => _dio.get('/api/referrals/$direction/$facilityId'),
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  GET REFERRAL BY ID  →  GET /api/referrals/:referralId
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getReferralById({required String referralId}) async {
    try {
      return await _requestWithRetry(
        () => _dio.get('/api/referrals/$referralId'),
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  PARSE ENCOUNTERS FROM VERIFICATION DATA
  // ════════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> parseEncountersFromVerification(
    Map<String, dynamic> verifyData, {
    required String facilityName,
  }) {
    final encounterIndex = verifyData['encounterIndex'] as List? ?? [];

    return encounterIndex.map((e) {
      return {
        'id': e['encounterId'],
        'class': {'display': e['encounterType']},
        'type': [
          {'text': e['encounterType']}
        ],
        'period': {'start': e['encounterDate']},
        'meta': {
          'source': e['facilityId'],
          'sourceName': facilityName,
          'lastUpdated': e['encounterDate'],
        },
        'resourceType': 'Encounter',
        'status': 'finished',
      };
    }).toList();
  }

  // ════════════════════════════════════════════════════════════════
  //  PARSE PATIENT FROM VERIFICATION DATA
  //  FIXED: Now maps all demographic fields, not just facility meta
  // ════════════════════════════════════════════════════════════════

  Map<String, dynamic> parsePatientFromVerification(
    Map<String, dynamic> verifyData,
  ) {
    final patientMeta =
        (verifyData['patient'] as Map?)?.cast<String, dynamic>() ?? {};
    final nupi = verifyData['nupi'] as String? ?? '';

    return {
      'nupi': nupi,
      'name': patientMeta['name'] ?? 'Unknown',
      // Map all possible demographic field names the API might return
      'gender': patientMeta['gender'] ?? patientMeta['sex'] ?? '',
      'dateOfBirth': patientMeta['dob'] ??
          patientMeta['dateOfBirth'] ??
          patientMeta['birthDate'] ??
          '',
      'phoneNumber': patientMeta['phone'] ??
          patientMeta['phoneNumber'] ??
          patientMeta['msisdn'] ??
          '',
      'county': patientMeta['county'] ?? '',
      'subCounty': patientMeta['subCounty'] ?? patientMeta['sub_county'] ?? '',
      'village': patientMeta['village'] ?? patientMeta['ward'] ?? '',
      'bloodGroup': patientMeta['bloodGroup'] ?? patientMeta['blood_group'] ?? '',
      'nationalId': patientMeta['nationalId'] ?? patientMeta['national_id'] ?? '',
      'registeredFacility': patientMeta['registeredFacility'] ?? '',
      'registeredFacilityId': patientMeta['registeredFacilityId'] ?? '',
      'facilityCounty': patientMeta['facilityCounty'] ?? '',
      'isCurrentFacility': patientMeta['isCurrentFacility'] ?? false,
      'isFederatedRecord': true,
    };
  }

  // ════════════════════════════════════════════════════════════════
  //  GET FACILITY FIREBASE CONFIG  →  GET /api/facilities/:id/firebase-config
  //
  //  Called once during setup wizard to fetch this facility's
  //  Firebase credentials from the HIE Gateway.
  //  Protected by X-Api-Key — only a registered facility can fetch
  //  its own config.
  // ════════════════════════════════════════════════════════════════

  Future<HieResult> getFacilityFirebaseConfig({
    required String facilityId,
    required String apiKey,
  }) async {
    try {
      return await _requestWithRetry(
        () => _dio.get(
          '/api/facilities/$facilityId/firebase-config',
          options: Options(headers: {'X-Api-Key': apiKey}),
        ),
      );
    } catch (e) {
      return HieResult(success: false, error: e.toString());
    }
  }
}