import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/network/network_info.dart';

class MockInternetConnection extends Mock implements InternetConnection {}

void main() {
  late NetworkInfoImpl networkInfo;
  late MockInternetConnection mockInternetConnection;

  setUp(() {
    mockInternetConnection = MockInternetConnection();
    networkInfo = NetworkInfoImpl(mockInternetConnection);
  });

  group('isConnected', () {
    test('should forward the call to InternetConnection.hasInternetAccess', () {
      final tHasInternetAccess = Future.value(true);
      when(() => mockInternetConnection.hasInternetAccess)
          .thenAnswer((_) => tHasInternetAccess);

      final result = networkInfo.isConnected;

      verify(() => mockInternetConnection.hasInternetAccess).called(1);
      expect(result, tHasInternetAccess);
    });
  });
}
