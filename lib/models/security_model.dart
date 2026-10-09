import 'dart:math';
import 'cvss.dart';
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

  /// CVSS v3.1 qualitative band for a base score (FIRST specification):
  /// Low 0.1–3.9, Medium 4.0–6.9, High 7.0–8.9, Critical 9.0–10.0.
  /// Returns null for 0.0 ("None").
  static RiskLevel? fromCvss(double score) {
    if (score <= 0) return null;
    if (score < 4.0) return RiskLevel.low;
    if (score < 7.0) return RiskLevel.medium;
    if (score < 9.0) return RiskLevel.high;
    return RiskLevel.critical;
  }

  /// One level higher (Critical stays Critical).
  RiskLevel get raisedOneLevel =>
      RiskLevel.values[min(index + 1, RiskLevel.values.length - 1)];
}

/// Points deducted from a device's score for one finding, by severity.
///
/// Calibrated to the five security tiers: a single finding of a given
/// severity moves a perfect device (100) into the matching tier.
///   Critical 45 -> 55 POOR · High 30 -> 70 FAIR
///   Medium 15  -> 85 GOOD · Low 5   -> 95 EXCELLENT
/// Two Critical findings (-> 10) reach the CRITICAL tier.
class SeverityPoints {
  static const int critical = 45;
  static const int high = 30;
  static const int medium = 15;
  static const int low = 5;

  static int of(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical:
        return critical;
      case RiskLevel.high:
        return high;
      case RiskLevel.medium:
        return medium;
      case RiskLevel.low:
        return low;
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
  /// Weakness id. Several ports can share one id (e.g. web admin on 80,
  /// 8080 and 8888); a device is only penalised once per id.
  final String id;
  final String title;
  final String summary;
  final String plainEnglishWhyDangerous;
  final RiskLevel riskLevel;
  final int penaltyPoints;
  final int affectedPort;
  final List<FixStep> howToFixSteps;

  /// CVSS v3.1 base vector of the typical weakness, scored with
  /// Attack Vector = Adjacent because the attacker has to be on the same
  /// Wi-Fi. See docs/scoring-method.md.
  final String cvssVector;

  /// Evidence that this service is attacked at scale in its default
  /// configuration. When present, the severity is raised one level.
  final String? threatEvidence;

  const SecurityVulnerability({
    required this.id,
    required this.title,
    required this.summary,
    required this.plainEnglishWhyDangerous,
    required this.riskLevel,
    required this.penaltyPoints,
    required this.affectedPort,
    required this.howToFixSteps,
    required this.cvssVector,
    this.threatEvidence,
  });

  double get cvssBaseScore => CvssV31.baseScore(cvssVector);

  /// Short line showing where the penalty comes from, e.g.
  /// "CVSS 8.8 · +1 level (known attacks) · -45 pts".
  String get scoringBasis {
    final raised = threatEvidence == null ? '' : ' · +1 level (known attacks)';
    return 'CVSS ${cvssBaseScore.toStringAsFixed(1)}$raised · -$penaltyPoints pts';
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
