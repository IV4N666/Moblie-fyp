import '../models/device_model.dart';
import '../models/security_model.dart';

class SecurityScoringService {
  /// Evaluates device-level security score (0 to 100) based on deterministic additive penalties
  static int calculateDeviceScore(DiscoveredDevice device) {
    int score = 100;
    for (final vuln in device.vulnerabilities) {
      score -= vuln.penaltyPoints;
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
    if (devices.isEmpty) {
      return NetworkAuditResult(
        subnet: subnet,
        localIp: localIp,
        gatewayIp: gatewayIp,
        wifiSsid: wifiSsid,
        overallScore: 100,
        scanTimestamp: DateTime.now(),
        devices: devices,
        allIssues: [],
      );
    }

    int score = 100;
    final List<SecurityVulnerability> allIssues = [];

    int unknownDeviceCount = 0;

    for (final device in devices) {
      if (device.category == DeviceCategory.unknown) {
        unknownDeviceCount++;
      }

      for (final vuln in device.vulnerabilities) {
        score -= vuln.penaltyPoints;
        if (!allIssues.any((i) => i.id == vuln.id)) {
          allIssues.add(vuln);
        }
      }
    }

    // Penalty for excessive unknown devices on primary Wi-Fi
    if (unknownDeviceCount > 3) {
      score -= 10;
    }

    // Clamp overall score between 0 and 100
    final finalScore = score.clamp(0, 100);

    return NetworkAuditResult(
      subnet: subnet,
      localIp: localIp,
      gatewayIp: gatewayIp,
      wifiSsid: wifiSsid,
      overallScore: finalScore,
      scanTimestamp: DateTime.now(),
      devices: devices,
      allIssues: allIssues,
    );
  }
}
