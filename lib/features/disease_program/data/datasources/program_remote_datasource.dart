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
  Future<List<ProgramEnrollmentModel>> getFacilityEnrollments(String facilityId) async {
    final snapshot = await firestore
        .collection('program_enrollments')
        .where('facilityId', isEqualTo: facilityId)
        .where('status', isEqualTo: 'active')
        .orderBy('enrollmentDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ProgramEnrollmentModel.fromFirestore(doc.data()))
        .toList();
  }
}