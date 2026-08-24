import '../models/device_model.dart';
import '../models/security_model.dart';

class SecurityScoringService {
  /// Evaluates the complete health and hygiene score (0 to 100) of the network
  static NetworkAuditResult evaluateNetworkHealth({
    required String subnet,
    required String localIp,
    required String gatewayIp,
    required String wifiSsid,
    required List<DiscoveredDevice> devices,
  }) {
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

    // Clamp score between 0 and 100
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
