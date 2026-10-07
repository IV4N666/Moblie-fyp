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

  // Scan settings used by DashboardScreen when it starts a scan.
  final int _portScanTimeoutMs = 300;
  final int _maxConcurrentHosts = 24;

  bool get isExpertMode => _mode == AppOperationMode.expert;

  /// How long to wait for each TCP port before treating it as filtered.
  /// Phones in Wi-Fi power-save mode can take 100–300 ms to answer.
  int get portScanTimeoutMs => _portScanTimeoutMs;

  /// How many hosts are probed at the same time. Each host opens one socket
  /// per probed port (~21), so 24 hosts ≈ 500 sockets in flight.
  int get maxConcurrentHosts => _maxConcurrentHosts;

  void toggleMode() {
    _mode = _mode == AppOperationMode.normal
        ? AppOperationMode.expert
        : AppOperationMode.normal;
    notifyListeners();
  }
}
