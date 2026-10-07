import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/models/device_model.dart';
import 'package:wifi_guardian_app/models/security_model.dart';
import 'package:wifi_guardian_app/services/scanner_service.dart';
import 'package:wifi_guardian_app/services/security_scoring_service.dart';

import 'test_helpers.dart';

void main() {
  group('SecurityScoringService', () {
    test('empty network scores 100', () {
      expect(SecurityScoringService.calculateNetworkScore([]), 100);
    });

    test('device score subtracts that device\'s penalties', () {
      final telnetCam = deviceWithPorts('192.168.1.10', [23]); // Critical: -45
      expect(SecurityScoringService.calculateDeviceScore(telnetCam), 55);
      expect(SecurityScoringService.calculateNetworkScore([telnetCam]), 55);
    });

    test('the same weakness on several ports is deducted once', () {
      // 80 and 8080 are both "unencrypted web admin" (High, -30).
      final router = deviceWithPorts('192.168.1.1', [80, 8080]);
      expect(router.vulnerabilities.length, 1);
      expect(SecurityScoringService.calculateDeviceScore(router), 70);
    });

    test('demo network scores 48 (POOR)', () {
      final demo = ScannerService.getDemoDevices('192.168.1');
      final score = SecurityScoringService.calculateNetworkScore(demo);
      // device scores 70, 10, 100, 55, 70, 100, 55, 55
      // average 64.375, weakest 10 -> 0.7 * 64.375 + 0.3 * 10 = 48.06
      expect(score, 48);
      expect(SecurityTierExtension.fromScore(score), SecurityTier.poor);
    });

    test('many devices with a web UI no longer drive the score to 0', () {
      final devices = [
        for (var i = 2; i < 12; i++) deviceWithPorts('192.168.1.$i', [80]),
      ];
      // Summing every penalty from one 100 gave 0. Now every device scores 70.
      expect(SecurityScoringService.calculateNetworkScore(devices), 70);
    });

    test('one critical device is not hidden by many clean ones', () {
      final devices = [
        deviceWithPorts('192.168.1.2', [23, 80, 554]), // 100 - 45 - 30 - 15 = 10
        for (var i = 3; i < 12; i++) deviceWithPorts('192.168.1.$i', []),
      ];
      final score = SecurityScoringService.calculateNetworkScore(devices);
      // Plain average would be 91 (EXCELLENT); the weakest-link term gives 67.
      expect(score, 67);
      expect(score, lessThan(90));
    });

    test('more than 3 unidentified devices costs 10 points', () {
      final devices = [
        for (var i = 2; i < 6; i++)
          deviceWithPorts('192.168.1.$i', [], category: DeviceCategory.unknown),
      ];
      expect(SecurityScoringService.calculateNetworkScore(devices), 90);
    });

    test('audit counts every finding and distinct issue types', () {
      final audit = SecurityScoringService.evaluateNetworkHealth(
        subnet: '192.168.1',
        localIp: '192.168.1.5',
        gatewayIp: '192.168.1.1',
        wifiSsid: 'Test',
        devices: [
          deviceWithPorts('192.168.1.2', [80]),
          deviceWithPorts('192.168.1.3', [80, 23]),
        ],
      );
      expect(audit.totalFindingCount, 3);
      expect(audit.allIssues.length, 2);
    });
  });
}
