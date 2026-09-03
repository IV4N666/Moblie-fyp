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
  int _portScanTimeoutMs = 150;
  int _maxParallelSockets = 25;
  bool _enableVibration = true;

  AppOperationMode get mode => _mode;
  bool get isExpertMode => _mode == AppOperationMode.expert;
  int get portScanTimeoutMs => _portScanTimeoutMs;
  int get maxParallelSockets => _maxParallelSockets;
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
    int? maxParallel,
    bool? vibration,
  }) {
    if (timeoutMs != null) _portScanTimeoutMs = timeoutMs;
    if (maxParallel != null) _maxParallelSockets = maxParallel;
    if (vibration != null) _enableVibration = vibration;
    notifyListeners();
  }
}
