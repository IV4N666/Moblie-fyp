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

  test('interface ranking prefers real Wi-Fi and skips virtual adapters', () {
    int rank(String n) => NetworkInfoService.interfacePriority(n);

    // Wi-Fi on Android / Windows / Linux / macOS
    expect(rank('wlan0'), 0);
    expect(rank('Wi-Fi'), 0);
    expect(rank('wlp2s0'), 0);
    expect(rank('en0'), 0);

    // Wired Ethernet comes after Wi-Fi
    expect(rank('Ethernet'), 1);
    expect(rank('eth0'), 1);

    // Never used: mobile data, VPN and virtual adapters
    for (final n in ['rmnet_data0', 'tun0', 'vEthernet (WSL)', 'VirtualBox Host-Only Network', 'VMware Network Adapter VMnet8', 'Bluetooth Network Connection']) {
      expect(rank(n), -1, reason: n);
    }
  });
}
