import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkContext {
  final String localIp;
  final String subnetPrefix; // e.g. 192.168.1
  final String gatewayIp;    // e.g. 192.168.1.1
  final String wifiSsid;

  NetworkContext({
    required this.localIp,
    required this.subnetPrefix,
    required this.gatewayIp,
    required this.wifiSsid,
  });
}

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Automatically obtains current network parameters
  Future<NetworkContext> getCurrentNetworkContext() async {
    String? wifiIp;
    String? wifiName;

    try {
      wifiIp = await _networkInfo.getWifiIP();
      wifiName = await _networkInfo.getWifiName();
    } catch (_) {
      // Fallback if platform permission not yet granted
    }

    // Secondary fallback: inspect network interfaces directly
    if (wifiIp == null || wifiIp.isEmpty) {
      wifiIp = await _findLocalInterfaceIp();
    }

    // Default fallback if offline or in simulator
    final finalIp = wifiIp ?? '192.168.1.105';
    final parts = finalIp.split('.');
    
    String prefix = '192.168.1';
    String gateway = '192.168.1.1';

    if (parts.length == 4) {
      prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      gateway = '$prefix.1';
    }

    return NetworkContext(
      localIp: finalIp,
      subnetPrefix: prefix,
      gatewayIp: gateway,
      wifiSsid: (wifiName != null && wifiName.isNotEmpty && wifiName != '<unknown ssid>')
          ? wifiName.replaceAll('"', '')
          : 'Home Wi-Fi',
    );
  }

  Future<String?> _findLocalInterfaceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
