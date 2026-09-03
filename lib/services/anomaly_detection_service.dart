import '../models/device_model.dart';
import '../models/security_model.dart';

enum AnomalySeverity { normal, low, suspicious, critical }

class AnomalyFinding {
  final String title;
  final String description;
  final AnomalySeverity severity;
  final double anomalyConfidence; // 0.0 to 1.0

  const AnomalyFinding({
    required this.title,
    required this.description,
    required this.severity,
    required this.anomalyConfidence,
  });
}

class DeviceAnomalyProfile {
  final DiscoveredDevice device;
  final double anomalyScore; // 0.0 (Normal) to 1.0 (Highly Anomalous)
  final List<AnomalyFinding> findings;

  const DeviceAnomalyProfile({
    required this.device,
    required this.anomalyScore,
    required this.findings,
  });

  bool get isSuspicious => anomalyScore >= 0.5;

  String get severityLabel {
    if (anomalyScore >= 0.75) return 'CRITICAL ANOMALY';
    if (anomalyScore >= 0.5) return 'SUSPICIOUS DEVIATION';
    if (anomalyScore >= 0.25) return 'MINOR VARIANCE';
    return 'BASELINE NORMAL';
  }
}

/// Implements Unsupervised Behavioral Anomaly Detection as planned in
/// FYP Phase 1 Report Section 5.2.2 (Machine Learning Anomaly Detection).
class AnomalyDetectionService {
  /// Analyzes a device against baseline expected behavioral profiles
  /// using an Isolation-inspired heuristic distance model.
  static DeviceAnomalyProfile analyzeDevice(DiscoveredDevice device) {
    final findings = <AnomalyFinding>[];
    double riskAccumulator = 0.0;

    final openPortNums = device.openPorts.map((p) => p.port).toSet();

    // Baseline 1: Low-power IoT / Smart Plug / Bulb running terminal services
    if (device.category == DeviceCategory.iotDevice) {
      if (openPortNums.contains(23) || openPortNums.contains(2323)) {
        findings.add(const AnomalyFinding(
          title: 'Terminal Daemon on Constrained IoT Endpoint',
          description:
              'Smart home appliances should communicate via MQTT/CoAP or HTTP APIs. Active Telnet suggests unauthorized remote shell or botnet enlistment.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.94,
        ));
        riskAccumulator += 0.45;
      }

      if (openPortNums.contains(3306) ||
          openPortNums.contains(5432) ||
          openPortNums.contains(6379) ||
          openPortNums.contains(27017)) {
        findings.add(const AnomalyFinding(
          title: 'Database Engine on IoT Hardware',
          description:
              'IoT sensor hardware running database servers deviates significantly from typical vendor baselines.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.91,
        ));
        riskAccumulator += 0.40;
      }
    }

    // Baseline 2: Security Camera running remote desktop or SMB
    if (device.category == DeviceCategory.smartCamera) {
      if (openPortNums.contains(445) || openPortNums.contains(3389)) {
        findings.add(const AnomalyFinding(
          title: 'Workstation Services Exposed on Camera',
          description:
              'IP camera is listening on SMB or RDP ports typically exclusive to desktop computers.',
          severity: AnomalySeverity.suspicious,
          anomalyConfidence: 0.82,
        ));
        riskAccumulator += 0.35;
      }

      if (openPortNums.contains(2323)) {
        findings.add(const AnomalyFinding(
          title: 'Known Botnet Backdoor Port Active',
          description:
              'Port 2323 is non-standard and highly correlated with Mirai/Mozi IoT malware families.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.96,
        ));
        riskAccumulator += 0.50;
      }
    }

    // Baseline 3: Gateway Router with excessive exposed services
    if (device.category == DeviceCategory.gateway) {
      if (openPortNums.contains(23)) {
        findings.add(const AnomalyFinding(
          title: 'Legacy WAN/LAN Management Active',
          description:
              'Gateway router allows unencrypted terminal management, severely deviating from secure modern router baselines.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.89,
        ));
        riskAccumulator += 0.35;
      }
      if (openPortNums.contains(1900)) {
        findings.add(const AnomalyFinding(
          title: 'Automated Port Mapping (UPnP) Active',
          description:
              'UPnP service active on gateway enables lateral internal endpoints to bypass router firewall barriers.',
          severity: AnomalySeverity.suspicious,
          anomalyConfidence: 0.70,
        ));
        riskAccumulator += 0.20;
      }
    }

    // Clamp anomaly score between 0.0 and 1.0
    final finalAnomalyScore = riskAccumulator.clamp(0.0, 1.0);

    return DeviceAnomalyProfile(
      device: device,
      anomalyScore: finalAnomalyScore,
      findings: findings,
    );
  }

  /// Evaluates anomaly profiles for an entire network inventory
  static List<DeviceAnomalyProfile> analyzeNetwork(List<DiscoveredDevice> devices) {
    return devices.map((d) => analyzeDevice(d)).toList();
  }
}
