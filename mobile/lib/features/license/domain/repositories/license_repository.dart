import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/license_status.dart';

abstract class LicenseRepository {
  Future<Either<Failure, LicenseStatus>> check({bool forceRemote = false});

  Future<void> clearCache();
}
