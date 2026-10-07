import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/models/cvss.dart';
import 'package:wifi_guardian_app/models/security_model.dart';
import 'package:wifi_guardian_app/services/vulnerability_db.dart';

/// Checks that the knowledge base follows docs/scoring-method.md exactly.
void main() {
  group('CVSS v3.1 calculator', () {
    test('matches published scores', () {
      // BlueKeep (CVE-2019-0708): 9.8 Critical
      expect(CvssV31.baseScore('AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H'), 9.8);
      // Same weakness, attacker on the same Wi-Fi (Adjacent): 8.8
      expect(CvssV31.baseScore('AV:A/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H'), 8.8);
      // Scope changed (used for UPnP): 6.1
      expect(CvssV31.baseScore('AV:A/AC:L/PR:N/UI:N/S:C/C:L/I:L/A:N'), 6.1);
      // No impact: 0.0
      expect(CvssV31.baseScore('AV:A/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N'), 0.0);
    });

    test('maps scores to the FIRST severity bands', () {
      expect(RiskLevelExtension.fromCvss(0.0), isNull);
      expect(RiskLevelExtension.fromCvss(3.9), RiskLevel.low);
      expect(RiskLevelExtension.fromCvss(4.0), RiskLevel.medium);
      expect(RiskLevelExtension.fromCvss(7.0), RiskLevel.high);
      expect(RiskLevelExtension.fromCvss(9.0), RiskLevel.critical);
    });
  });

  group('knowledge base', () {
    final entries = VulnerabilityDatabase.allEntries;

    test('scores 18 ports', () {
      expect(entries.length, 18);
      expect(entries.keys, containsAll(<int>[23, 2323, 5555, 27017, 80, 8080, 8888, 1900]));
    });

    test('severity = CVSS band, raised one level only with threat evidence', () {
      entries.forEach((port, v) {
        final band = RiskLevelExtension.fromCvss(v.cvssBaseScore);
        expect(band, isNotNull, reason: 'port $port has a zero CVSS score');
        final expected = v.threatEvidence == null ? band : band!.raisedOneLevel;
        expect(v.riskLevel, expected, reason: 'port $port');
      });
    });

    test('penalty points come from the severity level', () {
      entries.forEach((port, v) {
        expect(v.penaltyPoints, SeverityPoints.of(v.riskLevel), reason: 'port $port');
        expect(v.affectedPort, port, reason: 'port $port');
      });
    });

    test('ports that share a weakness share everything that is scored', () {
      final telnet = [entries[23]!, entries[2323]!];
      final web = [entries[80]!, entries[8080]!, entries[8888]!];
      for (final group in [telnet, web]) {
        expect(group.map((v) => v.id).toSet().length, 1);
        expect(group.map((v) => v.riskLevel).toSet().length, 1);
        expect(group.map((v) => v.cvssVector).toSet().length, 1);
      }
    });
  });

  test('one finding moves a perfect device into the matching tier', () {
    SecurityTier tierAfter(int points) => SecurityTierExtension.fromScore(100 - points);
    expect(tierAfter(SeverityPoints.low), SecurityTier.excellent);
    expect(tierAfter(SeverityPoints.medium), SecurityTier.good);
    expect(tierAfter(SeverityPoints.high), SecurityTier.fair);
    expect(tierAfter(SeverityPoints.critical), SecurityTier.poor);
    expect(SecurityTierExtension.fromScore(100 - 2 * SeverityPoints.critical), SecurityTier.critical);
  });
}
