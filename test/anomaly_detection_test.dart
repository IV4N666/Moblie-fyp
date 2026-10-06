import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/models/device_model.dart';
import 'package:wifi_guardian_app/services/anomaly_detection_service.dart';

import 'test_helpers.dart';

void main() {
  test('camera running Telnet is flagged by the expert rules', () {
    final cam = deviceWithPorts('192.168.1.20', [23, 554],
        category: DeviceCategory.smartCamera);
    final profile = AnomalyDetectionService.analyzeDevice(cam);
    expect(profile.ruleScore, closeTo(0.45, 1e-9));
    expect(profile.isAnomalous, isTrue);
  });

  test('statistics are skipped on very small networks', () {
    final profiles = AnomalyDetectionService.analyzeNetwork([
      deviceWithPorts('192.168.1.2', [80]),
      deviceWithPorts('192.168.1.3', []),
    ]);
    expect(profiles.every((p) => p.isolationScore == null), isTrue);
  });

  test('the odd device out gets the highest isolation score', () {
    final devices = [
      for (var i = 2; i < 10; i++)
        deviceWithPorts('192.168.1.$i', [], category: DeviceCategory.phoneOrTablet),
      deviceWithPorts('192.168.1.50', [21, 3306, 6379],
          category: DeviceCategory.computer),
    ];
    final profiles = AnomalyDetectionService.analyzeNetwork(devices);
    final odd = profiles.last;
    final normal = profiles.first;

    expect(odd.isolationScore!, greaterThan(normal.isolationScore!));
    expect(odd.isolationScore!, greaterThan(0.7));
    expect(odd.anomalyScore, greaterThan(normal.anomalyScore));
    expect(odd.findings.any((f) => f.title.contains('Isolation Forest')), isTrue);
    // Statistical rarity alone is capped at 0.4.
    expect(odd.anomalyScore, lessThanOrEqualTo(0.4 + 1e-9));
  });
}
