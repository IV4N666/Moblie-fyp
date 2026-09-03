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

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final List<AuditHistoryEntry> _history = [];
  final Map<String, String> _customAliases = {};
  final Set<String> _trustedIps = {};

  List<AuditHistoryEntry> get history => List.unmodifiable(_history);

  AuditHistoryEntry? get lastAudit =>
      _history.isNotEmpty ? _history.last : null;

  AuditHistoryEntry? get previousAudit =>
      _history.length >= 2 ? _history[_history.length - 2] : null;

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
  }

  void setCustomAlias(String ip, String alias) {
    if (alias.trim().isEmpty) {
      _customAliases.remove(ip);
    } else {
      _customAliases[ip] = alias.trim();
    }
  }

  String? getCustomAlias(String ip) => _customAliases[ip];

  void toggleDeviceTrust(String ip, bool isTrusted) {
    if (isTrusted) {
      _trustedIps.add(ip);
    } else {
      _trustedIps.remove(ip);
    }
  }

  bool isDeviceTrusted(String ip) => _trustedIps.contains(ip);
}
