import 'package:clinic_connect/features/patient/domain/usecases/search_patient.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient.dart';

abstract class PatientRepository {
  Future<Either<Failure, Patient>> registerPatient(Patient patient);
  Future<Either<Failure, Patient>> getPatient(String patientId);
  
  Future<Either<Failure, List<Patient>>> searchPatients({
    required String query,
    required SearchType searchType,
    String? facilityId,
    int page = 1,
    int limit = 20,
  });
  
  Future<Either<Failure, Patient>> updatePatient(Patient patient);
  Future<Either<Failure, List<Patient>>> getAllPatients();   // ← ADD

}