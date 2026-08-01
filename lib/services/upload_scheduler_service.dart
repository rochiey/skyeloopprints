import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/upload_config.dart';
import 'admin_config_service.dart';
import 'connectivity_service.dart';
import 'sales_upload_service.dart';

class UploadSchedulerService extends ChangeNotifier {
  final AdminConfigService _configService;
  final ConnectivityService _connectivityService;
  final SalesUploadService _uploadService;

  Timer? _dailyTimer;
  StreamSubscription<void>? _reconnectSub;
  bool _initialized = false;
  bool _isUploading = false;

  /// Status message shown in admin UI.
  String _lastStatus = 'Not started';
  String get lastStatus => _lastStatus;

  /// Timestamp of last upload attempt.
  DateTime? _lastAttempt;
  DateTime? get lastAttempt => _lastAttempt;

  UploadSchedulerService(
    this._configService,
    this._connectivityService,
    this._uploadService,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final config = _configService.loadUploadConfig();
    _scheduleDailyTimer(config);

    // Listen for WiFi reconnection — upload any pending days
    _reconnectSub = _connectivityService.onWifiReconnected.listen((_) async {
      final cfg = _configService.loadUploadConfig();
      if (cfg.autoUploadEnabled) {
        await _runUpload(cfg, source: 'reconnection');
      }
    });

    // On startup, check for pending uploads from past days
    if (config.autoUploadEnabled && _connectivityService.isConnectedToWifi) {
      // Run after a short delay so the app fully initializes
      Future.delayed(const Duration(seconds: 5), () {
        _runUpload(config, source: 'startup').ignore();
      });
    }
  }

  void _scheduleDailyTimer(UploadConfig config) {
    _dailyTimer?.cancel();
    _dailyTimer = null;

    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      config.scheduledHour,
      config.scheduledMinute,
    );

    // If scheduled time has passed today, schedule for tomorrow
    final nextRun = scheduled.isAfter(now) ? scheduled : scheduled.add(const Duration(days: 1));
    final delay = nextRun.difference(now);

    _dailyTimer = Timer(delay, () async {
      final cfg = _configService.loadUploadConfig();
      if (cfg.autoUploadEnabled) {
        await _runUpload(cfg, source: 'scheduled');
      }
      // Re-schedule for the next day
      _scheduleDailyTimer(cfg);
    });

    debugPrint('UploadScheduler: next daily upload at $nextRun');
  }

  /// Called when the admin changes upload config — reschedule timer.
  void onConfigChanged(UploadConfig config) {
    _scheduleDailyTimer(config);
  }

  /// Manual trigger (from admin UI).
  Future<void> triggerManualUpload() async {
    final config = _configService.loadUploadConfig();
    await _runUpload(config, source: 'manual');
  }

  Future<void> _runUpload(UploadConfig config, {required String source}) async {
    if (_isUploading) {
      _lastStatus = 'Upload already in progress (requested via $source)';
      notifyListeners();
      return;
    }

    if (!config.autoUploadEnabled && source != 'manual') return;

    if (!_connectivityService.isConnectedToWifi) {
      _lastStatus = 'WiFi not available — upload deferred (trigger: $source)';
      notifyListeners();
      return;
    }

    _isUploading = true;
    _lastStatus = 'Uploading… (trigger: $source)';
    notifyListeners();

    try {
      final result = await _uploadService.uploadPending(config);
      _lastStatus = result.success
          ? 'Uploaded ${result.uploaded} session(s) (trigger: $source)'
          : 'Upload failed: ${result.message}';
      _lastAttempt = DateTime.now();
    } catch (error) {
      _lastStatus = 'Upload error: $error';
      _lastAttempt = DateTime.now();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dailyTimer?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }
}
