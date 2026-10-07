import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';

class AuditHistoryEntry {
  final int score;
  final DateTime timestamp;
  final int totalDevices;
  final int riskyDevices;
  final String wifiSsid;

  const AuditHistoryEntry({
    required this.score,
    required this.timestamp,
    required this.totalDevices,
    required this.riskyDevices,
    required this.wifiSsid,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'timestamp': timestamp.toIso8601String(),
        'totalDevices': totalDevices,
        'riskyDevices': riskyDevices,
        'wifiSsid': wifiSsid,
      };

  factory AuditHistoryEntry.fromJson(Map<String, dynamic> json) =>
      AuditHistoryEntry(
        score: json['score'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        totalDevices: json['totalDevices'] as int,
        riskyDevices: json['riskyDevices'] as int,
        wifiSsid: json['wifiSsid'] as String? ?? 'Home Wi-Fi',
      );
}

/// Stores scan history, custom device names and trusted devices.
///
/// Previously everything lived only in memory, so the "score improvement
/// trend" was lost every time the app was closed. Data is now saved with
/// shared_preferences. Call [load] once before runApp().
///
/// Limitation: names and trust are keyed by IP address because Android 10+
/// does not let apps read MAC addresses. If the router hands a device a new
/// IP (DHCP), its custom name will not follow it.
class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  static const _historyKey = 'audit_history_v1';
  static const _aliasesKey = 'device_aliases_v1';
  static const _trustedKey = 'trusted_ips_v1';
  static const int maxEntries = 50;

  final List<AuditHistoryEntry> _history = [];
  final Map<String, String> _customAliases = {};
  final Set<String> _trustedIps = {};
  SharedPreferences? _prefs;

  /// The audit before the latest one *on the same Wi-Fi network*, so the
  /// trend arrow never compares two different networks.
  AuditHistoryEntry? get previousAudit {
    if (_history.length < 2) return null;
    final latest = _history.last;
    for (var i = _history.length - 2; i >= 0; i--) {
      if (_history[i].wifiSsid == latest.wifiSsid) return _history[i];
    }
    return null;
  }

  /// Loads saved data. Safe to call more than once; never throws.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      final rawHistory = prefs.getString(_historyKey);
      if (rawHistory != null) {
        final decoded = jsonDecode(rawHistory) as List<dynamic>;
        _history
          ..clear()
          ..addAll(decoded.map(
              (e) => AuditHistoryEntry.fromJson(e as Map<String, dynamic>)));
      }

      final rawAliases = prefs.getString(_aliasesKey);
      if (rawAliases != null) {
        final decoded = jsonDecode(rawAliases) as Map<String, dynamic>;
        _customAliases
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(k, v as String)));
      }

      _trustedIps
        ..clear()
        ..addAll(prefs.getStringList(_trustedKey) ?? const <String>[]);
    } catch (_) {
      // Corrupt or unavailable storage: start fresh instead of crashing at launch.
    }
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
          _historyKey, jsonEncode(_history.map((e) => e.toJson()).toList()));
      await prefs.setString(_aliasesKey, jsonEncode(_customAliases));
      await prefs.setStringList(_trustedKey, _trustedIps.toList());
    } catch (_) {
      // Saving is best-effort; the in-memory copy is still correct.
    }
  }

  /// Records a completed audit. Do not call this for Demo Mode or for a
  /// cancelled (partial) scan, or the trend will be misleading.
  void recordAudit({
    required int score,
    required int totalDevices,
    required int riskyDevices,
    required String wifiSsid,
  }) {
    _history.add(AuditHistoryEntry(
      score: score,
      timestamp: DateTime.now(),
      totalDevices: totalDevices,
      riskyDevices: riskyDevices,
      wifiSsid: wifiSsid,
    ));
    if (_history.length > maxEntries) {
      _history.removeRange(0, _history.length - maxEntries);
    }
    _save();
  }

  void setCustomAlias(String ip, String alias) {
    if (alias.trim().isEmpty) {
      _customAliases.remove(ip);
    } else {
      _customAliases[ip] = alias.trim();
    }
    _save();
  }

  void setDeviceTrusted(String ip, bool isTrusted) {
    if (isTrusted) {
      _trustedIps.add(ip);
    } else {
      _trustedIps.remove(ip);
    }
    _save();
  }

  /// Applies saved names and trust flags to freshly scanned devices.
  /// (Before, these were saved but never read back, so they vanished.)
  List<DiscoveredDevice> applyUserPreferences(List<DiscoveredDevice> devices) {
    return devices
        .map((d) => d.copyWith(
              customAlias: _customAliases[d.ip],
              isTrusted: d.isTrusted || _trustedIps.contains(d.ip),
            ))
        .toList();
  }
}
