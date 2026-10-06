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
      final telnetCam = deviceWithPorts('192.168.1.10', [23]); // -35
      expect(SecurityScoringService.calculateDeviceScore(telnetCam), 65);
      expect(SecurityScoringService.calculateNetworkScore([telnetCam]), 65);
    });

    test('demo network scores 62 (FAIR) instead of 0', () {
      final demo = ScannerService.getDemoDevices('192.168.1');
      final score = SecurityScoringService.calculateNetworkScore(demo);
      // average 73.125, weakest device 35 -> 0.7*73.125 + 0.3*35 = 61.69
      expect(score, 62);
      expect(SecurityTierExtension.fromScore(score), SecurityTier.fair);
    });

    test('many devices with a web UI no longer drive the score to 0', () {
      final devices = [
        for (var i = 2; i < 12; i++) deviceWithPorts('192.168.1.$i', [80]),
      ];
      // Old formula: 100 - 10*20 = 0. New: every device scores 80.
      expect(SecurityScoringService.calculateNetworkScore(devices), 80);
    });

    test('one critical device is not hidden by many clean ones', () {
      final devices = [
        deviceWithPorts('192.168.1.2', [23, 80, 554]), // device score 35
        for (var i = 3; i < 12; i++) deviceWithPorts('192.168.1.$i', []),
      ];
      final score = SecurityScoringService.calculateNetworkScore(devices);
      // Plain average would be 93.5 (EXCELLENT); weakest-link term pulls it down.
      expect(score, 76);
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
