import 'device_model.dart';

enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

enum SecurityTier {
  excellent, // 90-100
  good,      // 75-89
  fair,      // 60-74
  poor,      // 40-59
  critical,  // 0-39
}

extension SecurityTierExtension on SecurityTier {
  String get displayName {
    switch (this) {
      case SecurityTier.excellent:
        return 'EXCELLENT';
      case SecurityTier.good:
        return 'GOOD';
      case SecurityTier.fair:
        return 'FAIR';
      case SecurityTier.poor:
        return 'POOR';
      case SecurityTier.critical:
        return 'CRITICAL';
    }
  }

  String get description {
    switch (this) {
      case SecurityTier.excellent:
        return 'Protected & Optimal Security';
      case SecurityTier.good:
        return 'Minor Configuration Tweaks Needed';
      case SecurityTier.fair:
        return 'Moderate Risk - Attention Recommended';
      case SecurityTier.poor:
        return 'Elevated Risk - Remediation Required';
      case SecurityTier.critical:
        return 'Critical Threat Exposure - Immediate Action';
    }
  }

  static SecurityTier fromScore(int score) {
    if (score >= 90) return SecurityTier.excellent;
    if (score >= 75) return SecurityTier.good;
    if (score >= 60) return SecurityTier.fair;
    if (score >= 40) return SecurityTier.poor;
    return SecurityTier.critical;
  }
}

extension RiskLevelExtension on RiskLevel {
  String get displayName {
    switch (this) {
      case RiskLevel.critical:
        return 'CRITICAL';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.medium:
        return 'MEDIUM';
      case RiskLevel.low:
        return 'LOW';
    }
  }
}

class FixStep {
  final int stepNumber;
  final String action;
  final String details;
  final bool isCompleted;

  const FixStep({
    required this.stepNumber,
    required this.action,
    required this.details,
    this.isCompleted = false,
  });

  FixStep copyWith({
    int? stepNumber,
    String? action,
    String? details,
    bool? isCompleted,
  }) {
    return FixStep(
      stepNumber: stepNumber ?? this.stepNumber,
      action: action ?? this.action,
      details: details ?? this.details,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class SecurityVulnerability {
  final String id;
  final String title;
  final String summary;
  final String plainEnglishWhyDangerous;
  final RiskLevel riskLevel;
  final int penaltyPoints;
  final int affectedPort;
  final List<FixStep> howToFixSteps;

  const SecurityVulnerability({
    required this.id,
    required this.title,
    required this.summary,
    required this.plainEnglishWhyDangerous,
    required this.riskLevel,
    required this.penaltyPoints,
    required this.affectedPort,
    required this.howToFixSteps,
  });

  SecurityVulnerability copyWith({
    String? id,
    String? title,
    String? summary,
    String? plainEnglishWhyDangerous,
    RiskLevel? riskLevel,
    int? penaltyPoints,
    int? affectedPort,
    List<FixStep>? howToFixSteps,
  }) {
    return SecurityVulnerability(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      plainEnglishWhyDangerous:
          plainEnglishWhyDangerous ?? this.plainEnglishWhyDangerous,
      riskLevel: riskLevel ?? this.riskLevel,
      penaltyPoints: penaltyPoints ?? this.penaltyPoints,
      affectedPort: affectedPort ?? this.affectedPort,
      howToFixSteps: howToFixSteps ?? this.howToFixSteps,
    );
  }
}

class NetworkAuditResult {
  final String subnet;
  final String localIp;
  final String? gatewayIp;
  final String? wifiSsid;
  final int overallScore;
  final SecurityTier tier;
  final DateTime scanTimestamp;
  final List<DiscoveredDevice> devices;
  final List<SecurityVulnerability> allIssues;

  NetworkAuditResult({
    required this.subnet,
    required this.localIp,
    this.gatewayIp,
    this.wifiSsid,
    required this.overallScore,
    SecurityTier? tier,
    required this.scanTimestamp,
    required this.devices,
    required this.allIssues,
  }) : tier = tier ?? SecurityTierExtension.fromScore(overallScore);

  String get scoreHealthRating => tier.displayName;
  String get scoreDescription => tier.description;

  /// Every finding on every device (allIssues is de-duplicated by type).
  int get totalFindingCount =>
      devices.fold(0, (sum, d) => sum + d.vulnerabilities.length);

  int get criticalIssueCount =>
      allIssues.where((i) => i.riskLevel == RiskLevel.critical).length;

  int get highIssueCount =>
      allIssues.where((i) => i.riskLevel == RiskLevel.high).length;

  int get mediumIssueCount =>
      allIssues.where((i) => i.riskLevel == RiskLevel.medium).length;

  int get lowIssueCount =>
      allIssues.where((i) => i.riskLevel == RiskLevel.low).length;
}
