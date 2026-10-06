import 'package:flutter/foundation.dart';

enum AppOperationMode {
  normal, // Consumer / Mobile User-Friendly
  expert, // Technical / PC & Advanced Diagnostics
}

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  AppOperationMode _mode = AppOperationMode.normal;

  // These values were defined before but never passed to the scanner.
  // They are now used by DashboardScreen when it starts a scan.
  int _portScanTimeoutMs = 300;
  int _maxConcurrentHosts = 24;
  bool _enableVibration = true;

  AppOperationMode get mode => _mode;
  bool get isExpertMode => _mode == AppOperationMode.expert;

  /// How long to wait for each TCP port before treating it as filtered.
  /// Phones in Wi-Fi power-save mode can take 100–300 ms to answer.
  int get portScanTimeoutMs => _portScanTimeoutMs;

  /// How many hosts are probed at the same time. Each host opens one socket
  /// per probed port (~21), so 24 hosts ≈ 500 sockets in flight.
  int get maxConcurrentHosts => _maxConcurrentHosts;

  bool get enableVibration => _enableVibration;

  void setMode(AppOperationMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      notifyListeners();
    }
  }

  void toggleMode() {
    _mode = _mode == AppOperationMode.normal
        ? AppOperationMode.expert
        : AppOperationMode.normal;
    notifyListeners();
  }

  void updateSettings({
    int? timeoutMs,
    int? maxConcurrentHosts,
    bool? vibration,
  }) {
    if (timeoutMs != null) _portScanTimeoutMs = timeoutMs.clamp(50, 5000);
    if (maxConcurrentHosts != null) {
      _maxConcurrentHosts = maxConcurrentHosts.clamp(1, 64);
    }
    if (vibration != null) _enableVibration = vibration;
    notifyListeners();
  }
}
