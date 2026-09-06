import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyeloop/services/admin_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('payment test mode defaults to enabled', () async {
    final service = AdminConfigService();
    await service.initialize();

    final config = service.load();
    expect(config.paymentTestMode, isTrue);
  });

  test('saves and loads payment test mode', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setPaymentTestMode(false);
    expect(service.load().paymentTestMode, isFalse);

    await service.setPaymentTestMode(true);
    expect(service.load().paymentTestMode, isTrue);
  });
}
