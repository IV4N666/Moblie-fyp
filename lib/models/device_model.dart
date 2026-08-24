import 'security_model.dart';

enum DeviceCategory {
  gateway,
  smartCamera,
  iotDevice,
  printer,
  computer,
  phoneOrTablet,
  entertainment,
  unknown
}

class PortInfo {
  final int port;
  final String serviceName;
  final bool isSecure;
  final String description;

  const PortInfo({
    required this.port,
    required this.serviceName,
    required this.isSecure,
    required this.description,
  });
}

class DiscoveredDevice {
  final String ip;
  final String? macAddress;
  final String hostname;
  final String vendor;
  final DeviceCategory category;
  final List<PortInfo> openPorts;
  final List<SecurityVulnerability> vulnerabilities;
  final int responseTimeMs;
  final DateTime firstSeen;

  DiscoveredDevice({
    required this.ip,
    this.macAddress,
    this.hostname = 'Unknown Device',
    this.vendor = 'Generic Device',
    this.category = DeviceCategory.unknown,
    required this.openPorts,
    required this.vulnerabilities,
    this.responseTimeMs = 0,
    DateTime? firstSeen,
  }) : firstSeen = firstSeen ?? DateTime.now();

  bool get hasIssues => vulnerabilities.isNotEmpty;

  int get riskScoreDeduction {
    return vulnerabilities.fold(0, (sum, item) => sum + item.penaltyPoints);
  }

  String get categoryDisplayName {
    switch (category) {
      case DeviceCategory.gateway:
        return 'Router / Wi-Fi Gateway';
      case DeviceCategory.smartCamera:
        return 'Security Camera / RTSP';
      case DeviceCategory.iotDevice:
        return 'Smart Home (IoT)';
      case DeviceCategory.printer:
        return 'Network Printer';
      case DeviceCategory.computer:
        return 'Computer / Workstation';
      case DeviceCategory.phoneOrTablet:
        return 'Mobile Device';
      case DeviceCategory.entertainment:
        return 'Smart TV / Media Player';
      case DeviceCategory.unknown:
        return 'Unidentified Device';
    }
  }
}
