import '../../../../core/error/failures.dart';

class FreightChangeFailure extends Failure {
  const FreightChangeFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
