enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

class FixStep {
  final int stepNumber;
  final String action;
  final String details;

  const FixStep({
    required this.stepNumber,
    required this.action,
    required this.details,
  });
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
}

class NetworkAuditResult {
  final String subnet;
  final String localIp;
  final String? gatewayIp;
  final String? wifiSsid;
  final int overallScore;
  final DateTime scanTimestamp;
  final List<dynamic> devices; // DiscoveredDevice instances
  final List<SecurityVulnerability> allIssues;

  NetworkAuditResult({
    required this.subnet,
    required this.localIp,
    this.gatewayIp,
    this.wifiSsid,
    required this.overallScore,
    required this.scanTimestamp,
    required this.devices,
    required this.allIssues,
  });

  String get scoreHealthRating {
    if (overallScore >= 85) return 'Excellent & Safe';
    if (overallScore >= 70) return 'Good (Minor Tweaks Needed)';
    if (overallScore >= 50) return 'Moderate Risk (Attention Recommended)';
    return 'High Risk (Vulnerabilities Detected)';
  }
}
