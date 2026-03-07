// lib/features/facility/data/datasources/facility_remote_datasource.dart
//
// CHANGED: searchFacilities and getAllFacilities now fetch from the
// HIE Gateway via HieApiService first.  Firestore (shared index) is
// used as a fallback so the app still works offline or if the gateway
// is unreachable.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/firebase_config.dart';
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
  // Shared Firestore index — used as fallback
  FirebaseFirestore get _db => FirebaseConfig.sharedDb;

  // ── Gateway → Firestore fallback ─────────────────────────────────────────

  @override
  Future<List<FacilityModel>> searchFacilities(String query) async {
    // 1. Try gateway
    try {
      final result = await HieApiService.instance.getFacilities(query: query);
      if (result.success) {
        final list = result.data?['facilities'] as List<dynamic>?;
        if (list != null) {
          debugPrint('[HIE] facilities from gateway: ${list.length}');
          return list
              .map((f) => FacilityModel.fromGateway(f as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[HIE] gateway facility search failed, falling back: $e');
    }

    // 2. Firestore fallback
    return _searchFirestore(query);
  }

  @override
  Future<List<FacilityModel>> getAllFacilities({int limit = 100}) async {
    // 1. Try gateway
    try {
      final result = await HieApiService.instance.getFacilities();
      if (result.success) {
        final list = result.data?['facilities'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          debugPrint('[HIE] all facilities from gateway: ${list.length}');
          return list
              .map((f) => FacilityModel.fromGateway(f as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[HIE] gateway getAllFacilities failed, falling back: $e');
    }

    // 2. Firestore fallback
    try {
      final snap = await _db
          .collection('facilities')
          .where('is_active', isEqualTo: true)
          .limit(limit)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FacilityModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to load facilities: $e');
    }
  }

  @override
  Future<List<FacilityModel>> getFacilitiesByCounty(String county) async {
    // Try gateway with county filter
    try {
      final result = await HieApiService.instance.getFacilities(county: county);
      if (result.success) {
        final list = result.data?['facilities'] as List<dynamic>?;
        if (list != null) {
          return list
              .map((f) => FacilityModel.fromGateway(f as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}

    // Firestore fallback
    try {
      final snap = await _db
          .collection('facilities')
          .where('county', isEqualTo: county)
          .where('is_active', isEqualTo: true)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FacilityModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to get facilities by county: $e');
    }
  }

  @override
  Future<FacilityModel?> getFacility(String facilityId) async {
    try {
      final doc = await _db.collection('facilities').doc(facilityId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return FacilityModel.fromFirestore(data);
    } catch (e) {
      throw ServerException('Failed to get facility: $e');
    }
  }

  @override
  Future<void> registerFacility(FacilityModel facility) async {
    try {
      await _db
          .collection('facilities')
          .doc(facility.id)
          .set(facility.toFirestore());
    } catch (e) {
      throw ServerException('Failed to register facility: $e');
    }
  }

  @override
  Future<void> updateFacility(FacilityModel facility) async {
    try {
      await _db
          .collection('facilities')
          .doc(facility.id)
          .update(facility.toFirestore());
    } catch (e) {
      throw ServerException('Failed to update facility: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<FacilityModel>> _searchFirestore(String query) async {
    try {
      final snap = await _db
          .collection('facilities')
          .where('is_active', isEqualTo: true)
          .get();
      return snap.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return FacilityModel.fromFirestore(data);
          })
          .where((f) =>
              query.isEmpty ||
              f.name.toLowerCase().contains(query.toLowerCase()) ||
              f.county.toLowerCase().contains(query.toLowerCase()))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      throw ServerException('Failed to search facilities: $e');
    }
  }
}