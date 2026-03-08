// lib/features/facility/data/datasources/facility_remote_datasource.dart

import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/hie_api_service.dart';
import '../models/facility_model.dart';

abstract class FacilityRemoteDatasource {
  Future<List<FacilityModel>> searchFacilities(String query);
  Future<List<FacilityModel>> getFacilitiesByCounty(String county);
  Future<FacilityModel?> getFacility(String facilityId);
  Future<void> registerFacility(FacilityModel facility);
  Future<void> updateFacility(FacilityModel facility);
  Future<List<FacilityModel>> getAllFacilities({int limit = 100});
}

class FacilityRemoteDatasourceImpl implements FacilityRemoteDatasource {
  @override
  Future<List<FacilityModel>> searchFacilities(String query) async {
    final result = await HieApiService.instance.getFacilities(query: query);
    if (!result.success) {
      throw ServerException(result.error ?? 'Failed to search facilities');
    }
    final list = result.data?['facilities'] as List<dynamic>?;
    if (list == null) throw ServerException('No facilities data returned');
    debugPrint('[HIE] facilities from gateway: ${list.length}');
    return list
        .map((f) => FacilityModel.fromGateway(f as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FacilityModel>> getAllFacilities({int limit = 100}) async {
    final result = await HieApiService.instance.getFacilities();
    if (!result.success) {
      throw ServerException(result.error ?? 'Failed to load facilities');
    }
    final list = result.data?['facilities'] as List<dynamic>?;
    if (list == null) throw ServerException('No facilities data returned');
    debugPrint('[HIE] all facilities from gateway: ${list.length}');
    return list
        .map((f) => FacilityModel.fromGateway(f as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FacilityModel>> getFacilitiesByCounty(String county) async {
    final result = await HieApiService.instance.getFacilities(county: county);
    if (!result.success) {
      throw ServerException(result.error ?? 'Failed to get facilities by county');
    }
    final list = result.data?['facilities'] as List<dynamic>?;
    if (list == null) throw ServerException('No facilities data returned');
    return list
        .map((f) => FacilityModel.fromGateway(f as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FacilityModel?> getFacility(String facilityId) async {
    // The HIE gateway does not currently expose a single-facility lookup,
    // so fetch all and find by id.
    final result = await HieApiService.instance.getFacilities();
    if (!result.success) {
      throw ServerException(result.error ?? 'Failed to get facility');
    }
    final list = result.data?['facilities'] as List<dynamic>?;
    if (list == null) return null;
    final match = list
        .cast<Map<String, dynamic>>()
        .where((f) => f['id']?.toString() == facilityId || f['facilityId']?.toString() == facilityId)
        .map((f) => FacilityModel.fromGateway(f))
        .firstOrNull;
    return match;
  }

  @override
  Future<void> registerFacility(FacilityModel facility) {
    throw UnimplementedError(
      'registerFacility is not supported by the HIE Gateway.',
    );
  }

  @override
  Future<void> updateFacility(FacilityModel facility) {
    throw UnimplementedError(
      'updateFacility is not supported by the HIE Gateway.',
    );
  }
}