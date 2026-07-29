import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/admin_config.dart';
import '../models/photo_session.dart';
import '../models/pricing_tier.dart';
import '../services/admin_config_service.dart';
import '../services/local_server_service.dart';
import '../services/printer_service.dart';
import '../services/session_file_service.dart';

class AppController extends ChangeNotifier {
  final configService = AdminConfigService();
  final printerService = PrinterService();
  final localServerService = LocalServerService();
  final sessionFileService = SessionFileService();

  AdminConfig config = const AdminConfig();
  PhotoSession? session;

  bool get hasAdminPassword => configService.hasPassword;

  Future<void> initialize() async {
    await configService.initialize();
    config = configService.load();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await sessionFileService.cleanupOldSessions();
    await printerService.enterKioskMode();
  }

  void beginSession(PricingTier tier) {
    session = PhotoSession(tier: tier);
    notifyListeners();
  }

  Future<void> clearSession() async {
    session = null;
    await localServerService.stop();
    notifyListeners();
  }

  void refreshConfig() {
    config = configService.load();
    notifyListeners();
  }
}
