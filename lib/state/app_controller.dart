import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/admin_config.dart';
import '../models/photo_session.dart';
import '../models/pricing_tier.dart';
import '../services/admin_config_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_server_service.dart';
import '../services/printer_service.dart';
import '../services/sales_database_service.dart';
import '../services/sales_upload_service.dart';
import '../services/session_file_service.dart';
import '../services/upload_scheduler_service.dart';

class AppController extends ChangeNotifier {
  final configService = AdminConfigService();
  final printerService = PrinterService();
  final localServerService = LocalServerService();
  final sessionFileService = SessionFileService();
  final connectivityService = ConnectivityService();
  final salesDatabaseService = SalesDatabaseService();

  SalesUploadService? salesUploadService;
  UploadSchedulerService? uploadSchedulerService;

  AdminConfig config = const AdminConfig();
  PhotoSession? session;

  bool get hasAdminPassword => configService.hasPassword;

  Future<void> initialize() async {
    await configService.initialize();
    config = configService.load();

    salesUploadService = SalesUploadService(salesDatabaseService);
    uploadSchedulerService = UploadSchedulerService(
      configService,
      connectivityService,
      salesUploadService!,
    );

    await connectivityService.initialize();
    await uploadSchedulerService!.initialize();

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

  /// Record a completed session as a sales record in the database.
  Future<void> recordCompletedSession(PhotoSession completedSession) async {
    final record = SalesRecord(
      sessionId: completedSession.id,
      startedAt: completedSession.startedAt,
      pricingTier: completedSession.tier.name,
      price: completedSession.tier.price,
      photoCount: completedSession.photoPaths.length,
      copies: completedSession.copies,
    );
    await salesDatabaseService.insertSession(record);
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

  @override
  void dispose() {
    connectivityService.dispose();
    uploadSchedulerService?.dispose();
    salesDatabaseService.close();
    super.dispose();
  }
}
