import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/business_setup.dart';

abstract class BusinessSetupRepository {
  /// Reads the signed-in business. A missing record is a legacy hortifruti
  /// account, not a new one waiting for setup.
  Future<Either<Failure, BusinessSetup>> read(String userId);

  /// Persists [kind] and replaces that type's category suggestions.
  ///
  /// Succeeds only after the source of truth has stored the profile.
  Future<Either<Failure, BusinessSetup>> save({
    required String userId,
    required BusinessKind kind,
  });
}
