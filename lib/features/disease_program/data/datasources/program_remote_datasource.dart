// lib/features/disease_program/data/datasources/program_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/program_enrollment_model.dart';

abstract class ProgramRemoteDatasource {
  Future<void> syncEnrollment(ProgramEnrollmentModel enrollment);
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(String facilityId);
}

class ProgramRemoteDatasourceImpl implements ProgramRemoteDatasource {
  final FirebaseFirestore firestore;

  ProgramRemoteDatasourceImpl({required this.firestore});

  @override
  Future<void> syncEnrollment(ProgramEnrollmentModel enrollment) async {
    await firestore
        .collection('program_enrollments')
        .doc(enrollment.id)
        .set(enrollment.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(
      String facilityId) async {
    // FIX 1: Removed `.where('status', isEqualTo: 'active')` — this was
    //         silently excluding all completed enrollments (malaria, tb).
    //
    // FIX 2: Removed `.orderBy('enrollmentDate', descending: true)` — Firestore
    //         requires a composite index for where+orderBy on different fields.
    //         Without the index deployed, the query returns nothing.
    //         Sorting is done in Dart instead (zero infra requirement).
    final snapshot = await firestore
        .collection('program_enrollments')
        .where('facilityId', isEqualTo: facilityId)
        .get();

    final enrollments = snapshot.docs
        .map((doc) => ProgramEnrollmentModel.fromFirestore(doc.data()))
        .toList();

    // Sort by enrollmentDate descending — newest first
    enrollments.sort((a, b) => b.enrollmentDate.compareTo(a.enrollmentDate));

    return enrollments;
  }
}