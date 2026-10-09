import '../models/device_model.dart';
import 'isolation_forest.dart';

enum AnomalySeverity { normal, low, suspicious, critical }

class AnomalyFinding {
  final String title;
  final String description;
  final AnomalySeverity severity;

  /// For Isolation Forest findings: the measured isolation score s(x).
  /// For expert-rule findings: the weight assigned to the rule by the
  /// author (a design choice, not a measured probability).
  final double anomalyConfidence;

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

  /// Raw Isolation Forest score s(x), or null when the network has too few
  /// devices for a statistical comparison.
  final double? isolationScore;

  /// Score contributed by the expert rules alone (0.0–1.0).
  final double ruleScore;

  const DeviceAnomalyProfile({
    required this.device,
    required this.anomalyScore,
    required this.findings,
    this.isolationScore,
    this.ruleScore = 0.0,
  });

  bool get isAnomalous => anomalyScore >= 0.4;
}

/// Hybrid anomaly detection (FYP Phase 1 Report Section 5.2.2).
///
/// 1. Unsupervised: an Isolation Forest is trained on THIS network's devices,
///    using each device's open-port pattern as a binary feature vector.
///    Devices whose service exposure differs from their neighbours are
///    isolated quickly and receive a higher score. No labelled data needed.
/// 2. Expert rules: known-bad combinations for a device type (e.g. Telnet on
///    a smart plug or camera), which statistics alone cannot judge.
///
/// The two are combined as a probabilistic OR:
///   anomaly = 1 − (1 − rules) × (1 − 0.4 × isolation)
/// so either signal raises the score, and statistical rarity alone (which is
/// not automatically dangerous) can contribute at most 0.4.
///
/// The previous version was labelled "Unsupervised ML" but contained only
/// fixed if-rules with hard-coded confidence values.
class AnomalyDetectionService {
  static const double isolationWeight = 0.4;
  static const int minDevicesForStatistics = 4;

  /// A port is "rare" when at most this share of devices expose it.
  static const double rarePortShare = 0.25;

  /// Rule-only analysis of a single device (no network context).
  static DeviceAnomalyProfile analyzeDevice(DiscoveredDevice device) {
    return _combine(device, null, const []);
  }

  /// Full hybrid analysis of a network inventory.
  static List<DeviceAnomalyProfile> analyzeNetwork(
      List<DiscoveredDevice> devices) {
    final portSets =
        devices.map((d) => d.openPorts.map((p) => p.port).toSet()).toList();
    final allPorts = <int>{for (final s in portSets) ...s}.toList()..sort();

    IsolationForest? forest;
    List<List<double>> vectors = const [];
    if (devices.length >= minDevicesForStatistics && allPorts.isNotEmpty) {
      vectors = [
        for (final s in portSets)
          [for (final port in allPorts) s.contains(port) ? 1.0 : 0.0],
      ];
      forest = IsolationForest()..fit(vectors);
    }

    final portCounts = <int, int>{};
    for (final s in portSets) {
      for (final port in s) {
        portCounts[port] = (portCounts[port] ?? 0) + 1;
      }
    }

    return [
      for (var i = 0; i < devices.length; i++)
        _combine(
          devices[i],
          forest?.score(vectors[i]),
          [
            for (final port in portSets[i])
              if (devices.length >= minDevicesForStatistics &&
                  portCounts[port]! / devices.length <= rarePortShare)
                port,
          ]..sort(),
        ),
    ];
  }

  static DeviceAnomalyProfile _combine(
    DiscoveredDevice device,
    double? isolationScore,
    List<int> rarePorts,
  ) {
    final findings = <AnomalyFinding>[];
    final ruleScore = _applyExpertRules(device, findings);

    var isolationComponent = 0.0;
    if (isolationScore != null) {
      // s = 0.5 means "nothing unusual"; s ≈ 0.75 is a clear outlier.
      isolationComponent =
          ((isolationScore - 0.5) / 0.25).clamp(0.0, 1.0).toDouble();

      if (isolationComponent >= 0.25 && rarePorts.isNotEmpty) {
        findings.add(AnomalyFinding(
          title: 'Statistical outlier on this network (Isolation Forest)',
          description:
              'Has ${rarePorts.length == 1 ? 'a port' : 'ports'} few other devices here have: ${rarePorts.join(', ')}. '
              'Isolation score ${isolationScore.toStringAsFixed(2)} (0.50 = typical). Unusual is not always dangerous.',
          severity: isolationScore >= 0.7
              ? AnomalySeverity.suspicious
              : AnomalySeverity.low,
          anomalyConfidence: isolationScore,
        ));
      }
    }

    final combined =
        1 - (1 - ruleScore) * (1 - isolationWeight * isolationComponent);

    return DeviceAnomalyProfile(
      device: device,
      anomalyScore: combined.clamp(0.0, 1.0).toDouble(),
      findings: findings,
      isolationScore: isolationScore,
      ruleScore: ruleScore,
    );
  }

  /// Adds rule findings to [findings] and returns the rule score (0–1).
  static double _applyExpertRules(
      DiscoveredDevice device, List<AnomalyFinding> findings) {
    var score = 0.0;
    final ports = device.openPorts.map((p) => p.port).toSet();

    // Low-power IoT running terminal services or databases
    if (device.category == DeviceCategory.iotDevice) {
      if (ports.contains(23) || ports.contains(2323)) {
        findings.add(const AnomalyFinding(
          title: 'Terminal Daemon on Constrained IoT Endpoint',
          description:
              'Smart home appliances should communicate via MQTT/CoAP or HTTP APIs. Active Telnet suggests an unauthorized remote shell or botnet enlistment.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.45,
        ));
        score += 0.45;
      }
      if (ports.contains(3306) ||
          ports.contains(5432) ||
          ports.contains(6379) ||
          ports.contains(27017)) {
        findings.add(const AnomalyFinding(
          title: 'Database Engine on IoT Hardware',
          description:
              'IoT sensor hardware running database servers deviates significantly from typical vendor baselines.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.40,
        ));
        score += 0.40;
      }
    }

    // Security cameras running Telnet, desktop services or backdoor ports
    if (device.category == DeviceCategory.smartCamera) {
      if (ports.contains(23)) {
        findings.add(const AnomalyFinding(
          title: 'Telnet Console Active on Camera',
          description:
              'IP cameras with Telnet open are the main target of Mirai-style botnets, which log in with factory default passwords.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.45,
        ));
        score += 0.45;
      }
      if (ports.contains(445) || ports.contains(3389)) {
        findings.add(const AnomalyFinding(
          title: 'Workstation Services Exposed on Camera',
          description:
              'IP camera is listening on SMB or RDP ports typically exclusive to desktop computers.',
          severity: AnomalySeverity.suspicious,
          anomalyConfidence: 0.35,
        ));
        score += 0.35;
      }
      if (ports.contains(2323)) {
        findings.add(const AnomalyFinding(
          title: 'Known Botnet Backdoor Port Active',
          description:
              'Port 2323 is non-standard and highly correlated with Mirai/Mozi IoT malware families.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.50,
        ));
        score += 0.50;
      }
    }

    // Gateway router with risky management services
    if (device.category == DeviceCategory.gateway) {
      if (ports.contains(23)) {
        findings.add(const AnomalyFinding(
          title: 'Legacy WAN/LAN Management Active',
          description:
              'Gateway router allows unencrypted terminal management, severely deviating from secure modern router baselines.',
          severity: AnomalySeverity.critical,
          anomalyConfidence: 0.35,
        ));
        score += 0.35;
      }
      // Only flag UPnP when the router actually advertised an Internet
      // Gateway Device (detected via SSDP), not plain SSDP announcements.
      if (device.vulnerabilities.any((v) => v.affectedPort == 1900)) {
        findings.add(const AnomalyFinding(
          title: 'Automated Port Mapping (UPnP) Active',
          description:
              'UPnP service active on gateway enables internal devices to open router firewall ports without the owner noticing.',
          severity: AnomalySeverity.suspicious,
          anomalyConfidence: 0.20,
        ));
        score += 0.20;
      }
    }

    return score.clamp(0.0, 1.0).toDouble();
  }
}
