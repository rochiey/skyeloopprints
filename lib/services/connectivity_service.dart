import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isConnectedToWifi = false;
  bool get isConnectedToWifi => _isConnectedToWifi;

  /// True if any internet-capable connection exists (wifi or mobile).
  bool _hasInternet = false;
  bool get hasInternet => _hasInternet;

  /// Fires when the device transitions to WiFi-connected state.
  final _wifiReconnectedController = StreamController<void>.broadcast();
  Stream<void> get onWifiReconnected => _wifiReconnectedController.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasWifi = _isConnectedToWifi;
    _isConnectedToWifi = results.contains(ConnectivityResult.wifi);
    _hasInternet =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet);

    // Notify reconnection listeners when WiFi becomes available after being off
    if (_isConnectedToWifi && !wasWifi) {
      _wifiReconnectedController.add(null);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _wifiReconnectedController.close();
    super.dispose();
  }
}
