import '../models/device_model.dart';
import '../models/security_model.dart';

class SecurityScoringService {
  /// Weight of the average device score in the network score.
  static const double averageWeight = 0.7;

  /// Weight of the single weakest device ("a chain is only as strong as its
  /// weakest link"), so one critical camera can't be hidden by many clean phones.
  static const double weakestLinkWeight = 0.3;

  static const int unknownDeviceThreshold = 3;
  static const int unknownDevicePenalty = 10;

  /// Device score: 100 minus the sum of that device's penalty points, clamped to 0–100.
  static int calculateDeviceScore(DiscoveredDevice device) {
    return (100 - device.riskScoreDeduction).clamp(0, 100);
  }

  /// Network score (0–100):
  ///
  ///   score = 0.7 × average(device scores) + 0.3 × min(device scores)
  ///           − 10 if more than 3 unidentified devices
  ///
  /// The previous version subtracted every penalty on every device from a
  /// single 100, so any network with a few web interfaces reached 0/100.
  /// Penalties per finding are defined in docs/scoring-method.md; with them
  /// the built-in demo network scores 48 (POOR).
  static int calculateNetworkScore(List<DiscoveredDevice> devices) {
    if (devices.isEmpty) return 100;

    final scores = devices.map(calculateDeviceScore).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final weakest = scores.reduce((a, b) => a < b ? a : b);

    var score = (averageWeight * average + weakestLinkWeight * weakest).round();

    final unknownCount =
        devices.where((d) => d.category == DeviceCategory.unknown).length;
    if (unknownCount > unknownDeviceThreshold) {
      score -= unknownDevicePenalty;
    }

    return score.clamp(0, 100);
  }

  /// Evaluates the complete health and hygiene score (0 to 100) of the network
  /// following Section 3.8 & 4.3 of the FYP specification.
  static NetworkAuditResult evaluateNetworkHealth({
    required String subnet,
    required String localIp,
    required String gatewayIp,
    required String wifiSsid,
    required List<DiscoveredDevice> devices,
  }) {
    final allIssues = <SecurityVulnerability>[];
    for (final device in devices) {
      for (final vuln in device.vulnerabilities) {
        if (!allIssues.any((i) => i.id == vuln.id)) {
          allIssues.add(vuln);
        }
      }
    }

    return NetworkAuditResult(
      subnet: subnet,
      localIp: localIp,
      gatewayIp: gatewayIp,
      wifiSsid: wifiSsid,
      overallScore: calculateNetworkScore(devices),
      scanTimestamp: DateTime.now(),
      devices: devices,
      allIssues: allIssues,
    );
  }
}
