import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/services/report_export_service.dart';
import 'package:wifi_guardian_app/services/security_scoring_service.dart';

import 'test_helpers.dart';

void main() {
  final audit = SecurityScoringService.evaluateNetworkHealth(
    subnet: '192.168.1',
    localIp: '192.168.1.5',
    gatewayIp: '192.168.1.1',
    wifiSsid: 'Home',
    devices: [
      // Hostnames come from the network, so an attacker can choose them.
      deviceWithPorts('192.168.1.66', [23], hostname: '<script>alert(1)</script>'),
      deviceWithPorts('192.168.1.67', [80], hostname: 'evil|name'),
    ],
  );

  test('HTML report escapes device names (no script injection)', () {
    final html = ReportExportService.generateHtmlReport(audit);
    expect(html.contains('<script>'), isFalse);
    expect(html.contains('&lt;script&gt;'), isTrue);
  });

  test('Markdown report escapes table separators', () {
    final md = ReportExportService.generateMarkdownReport(audit);
    expect(md.contains(r'evil\|name'), isTrue);
  });
}
