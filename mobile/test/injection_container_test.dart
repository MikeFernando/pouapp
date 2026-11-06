import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/core/network/network_info.dart';
import 'package:pouapp/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await sl.reset();
  });

  test('should register core dependencies', () async {
    await init();

    expect(sl<NetworkInfo>(), isA<NetworkInfoImpl>());
  });
}
