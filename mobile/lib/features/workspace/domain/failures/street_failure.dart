import '../../../../core/error/failures.dart';

class StreetChangeFailure extends Failure {
  const StreetChangeFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
