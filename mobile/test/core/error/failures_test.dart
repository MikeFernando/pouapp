import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/error/failures.dart';

void main() {
  test('should compare failures by runtime type', () {
    expect(const ServerFailure(), const ServerFailure());
    expect(const CacheFailure(), const CacheFailure());
    expect(const ServerFailure(), isNot(const CacheFailure()));
  });
}
