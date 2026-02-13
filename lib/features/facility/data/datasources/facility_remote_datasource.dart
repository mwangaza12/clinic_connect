// lib/features/facility/data/datasources/facility_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/firebase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/facility_model.dart';

abstract class FacilityRemoteDatasource {
  Future<List<FacilityModel>> searchFacilities(String query);
  Future<List<FacilityModel>> getFacilitiesByCounty(String county);
  Future<FacilityModel?> getFacility(String facilityId);
  Future<void> registerFacility(FacilityModel facility);
  Future<void> updateFacility(FacilityModel facility);
  Future<List<FacilityModel>> getAllFacilities({int limit = 50});
}

class FacilityRemoteDatasourceImpl implements FacilityRemoteDatasource {
  // Uses SHARED index DB
  FirebaseFirestore get _db => FirebaseConfig.sharedDb;

  @override
  Future<List<FacilityModel>> searchFacilities(String query) async {
    try {
      final snapshot = await _db
          .collection('facilities')
          .where('is_active', isEqualTo: true)
          .get();

      final facilities = snapshot.docs
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

      return facilities;
    } catch (e) {
      throw ServerException('Failed to search facilities: $e');
    }
  }

  @override
  Future<List<FacilityModel>> getFacilitiesByCounty(String county) async {
    try {
      final snapshot = await _db
          .collection('facilities')
          .where('county', isEqualTo: county)
          .where('is_active', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
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
      final doc = await _db
          .collection('facilities')
          .doc(facilityId)
          .get();

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

  @override
  Future<List<FacilityModel>> getAllFacilities({int limit = 50}) async {
    try {
      final snapshot = await _db
          .collection('facilities')
          .where('is_active', isEqualTo: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FacilityModel.fromFirestore(data);
      }).toList();
    } catch (e) {
      throw ServerException('Failed to get all facilities: $e');
    }
  }
}