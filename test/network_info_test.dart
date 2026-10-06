import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/services/network_info_service.dart';

void main() {
  test('only RFC 1918 private addresses are accepted', () {
    for (final ip in ['192.168.0.10', '10.1.2.3', '172.16.0.1', '172.31.255.254']) {
      expect(NetworkInfoService.isPrivateIpv4(ip), isTrue, reason: ip);
    }
    for (final ip in ['172.32.0.1', '172.15.0.1', '8.8.8.8', '100.64.0.1', '192.169.1.1', '256.1.1.1', 'abc', '']) {
      expect(NetworkInfoService.isPrivateIpv4(ip), isFalse, reason: ip);
    }
  });
}
