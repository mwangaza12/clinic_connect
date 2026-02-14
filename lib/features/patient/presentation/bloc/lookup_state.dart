import 'package:equatable/equatable.dart';
import '../../domain/entities/patient_lookup.dart';

abstract class LookupState extends Equatable {
  const LookupState();
  @override
  List<Object?> get props => [];
}

class LookupInitial extends LookupState {}

class LookupLoading extends LookupState {}

class LookupFound extends LookupState {
  final PatientLookupResult result;
  final Map<String, dynamic>? summary;

  const LookupFound({
    required this.result,
    this.summary,
  });

  @override
  List<Object?> get props => [result, summary];
}

class LookupNotFound extends LookupState {}

class LookupError extends LookupState {
  final String message;
  const LookupError(this.message);
  @override
  List<Object> get props => [message];
}