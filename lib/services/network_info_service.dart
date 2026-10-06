import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkContext {
  final String localIp;
  final String subnetPrefix; // e.g. 192.168.1
  final String gatewayIp;    // e.g. 192.168.1.1
  final String wifiSsid;

  /// False when no private (RFC 1918) Wi-Fi address was found, e.g. the phone
  /// is on mobile data only. The old code silently fell back to a fake
  /// 192.168.1.105 and "scanned" a network that did not exist.
  final bool isConnected;

  NetworkContext({
    required this.localIp,
    required this.subnetPrefix,
    required this.gatewayIp,
    required this.wifiSsid,
    this.isConnected = true,
  });
}

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Automatically obtains current network parameters.
  Future<NetworkContext> getCurrentNetworkContext() async {
    // Each call is wrapped separately so a missing location permission
    // (needed only for the SSID) doesn't throw away the IP and gateway.
    final String? reportedIp = await _safe(_networkInfo.getWifiIP);
    final String? wifiName = await _safe(_networkInfo.getWifiName);
    final String? reportedGateway = await _safe(_networkInfo.getWifiGatewayIP);

    final String? wifiIp = (reportedIp != null && isPrivateIpv4(reportedIp))
        ? reportedIp
        : await _findLocalInterfaceIp();

    if (wifiIp == null) {
      return NetworkContext(
        localIp: '0.0.0.0',
        subnetPrefix: '192.168.1',
        gatewayIp: '192.168.1.1',
        wifiSsid: 'Not connected to Wi-Fi',
        isConnected: false,
      );
    }

    final prefix = wifiIp.substring(0, wifiIp.lastIndexOf('.'));

    // Use the router address reported by the OS. Guessing ".1" is wrong on
    // many ISP routers (.254, .100, ...).
    final gateway = (reportedGateway != null &&
            reportedGateway.startsWith('$prefix.') &&
            isPrivateIpv4(reportedGateway))
        ? reportedGateway
        : '$prefix.1';

    return NetworkContext(
      localIp: wifiIp,
      subnetPrefix: prefix,
      gatewayIp: gateway,
      wifiSsid: (wifiName != null &&
              wifiName.isNotEmpty &&
              wifiName != '<unknown ssid>')
          ? wifiName.replaceAll('"', '')
          : 'Home Wi-Fi',
    );
  }

  static Future<String?> _safe(Future<String?> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  /// True only for RFC 1918 private IPv4 addresses
  /// (10/8, 172.16/12, 192.168/16).
  static bool isPrivateIpv4(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final p in parts) {
      final value = int.tryParse(p);
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }
    final a = octets[0];
    final b = octets[1];
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  /// Fallback when the plugin can't report the Wi-Fi IP.
  ///
  /// Skips cellular (rmnet*, ccmni*, pdp*) and VPN (tun*, ppp*) interfaces:
  /// mobile carriers often hand out 10.x addresses, and the old check would
  /// have scanned the carrier's network instead of the home Wi-Fi.
  Future<String?> _findLocalInterfaceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? fallback;
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        const skipPrefixes = ['rmnet', 'ccmni', 'pdp', 'tun', 'ppp', 'utun', 'ipsec'];
        if (skipPrefixes.any(name.startsWith)) continue;

        for (final addr in iface.addresses) {
          if (!isPrivateIpv4(addr.address)) continue;
          if (name.startsWith('wlan') || name.startsWith('en') || name.startsWith('eth')) {
            return addr.address;
          }
          fallback ??= addr.address;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }
}
