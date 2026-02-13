// lib/features/referral/data/datasources/referral_remote_datasource.dart

import '../../domain/entities/referral.dart';
import '../models/referral_model.dart';

abstract class ReferralRemoteDatasource {
  /// Create a new referral
  Future<ReferralModel> createReferral(ReferralModel referral);
  
  /// Get all outgoing referrals from a facility
  Future<List<ReferralModel>> getOutgoingReferrals(String facilityId);
  
  /// Get all incoming referrals to a facility
  Future<List<ReferralModel>> getIncomingReferrals(String facilityId);
  
  /// Update referral status (accept/reject/complete)
  Future<ReferralModel> updateReferralStatus(
    String referralId,
    ReferralStatus status, {
    String? feedbackNotes,
  });
  
  /// Get a specific referral by ID
  Future<ReferralModel> getReferral(String referralId);
  
  /// Search referrals by patient NUPI
  Future<List<ReferralModel>> searchReferralsByPatient(String patientNupi);
  
  /// Get referral statistics for a facility
  Future<Map<String, dynamic>> getReferralStats(String facilityId);
}