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

  PortInfo copyWith({
    int? port,
    String? serviceName,
    bool? isSecure,
    String? description,
  }) {
    return PortInfo(
      port: port ?? this.port,
      serviceName: serviceName ?? this.serviceName,
      isSecure: isSecure ?? this.isSecure,
      description: description ?? this.description,
    );
  }
}

class DiscoveredDevice {
  final String ip;
  final String? macAddress;
  final String hostname;
  final String? customAlias;
  final String vendor;
  final DeviceCategory category;
  final List<PortInfo> openPorts;
  final List<SecurityVulnerability> vulnerabilities;
  final int responseTimeMs;
  final DateTime firstSeen;
  final bool isTrusted;

  DiscoveredDevice({
    required this.ip,
    this.macAddress,
    this.hostname = 'Unknown Device',
    this.customAlias,
    this.vendor = 'Generic Device',
    this.category = DeviceCategory.unknown,
    required this.openPorts,
    required this.vulnerabilities,
    this.responseTimeMs = 0,
    DateTime? firstSeen,
    this.isTrusted = false,
  }) : firstSeen = firstSeen ?? DateTime.now();

  bool get hasIssues => vulnerabilities.isNotEmpty;

  String get displayName {
    if (customAlias != null && customAlias!.trim().isNotEmpty) {
      return customAlias!;
    }
    return hostname.isNotEmpty ? hostname : 'Device at $ip';
  }

  /// Total penalty, counting each weakness id once (e.g. web admin on both
  /// 80 and 8080 is one weakness).
  int get riskScoreDeduction {
    final seen = <String>{};
    var total = 0;
    for (final v in vulnerabilities) {
      if (seen.add(v.id)) total += v.penaltyPoints;
    }
    return total;
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

  DiscoveredDevice copyWith({
    String? ip,
    String? macAddress,
    String? hostname,
    String? customAlias,
    String? vendor,
    DeviceCategory? category,
    List<PortInfo>? openPorts,
    List<SecurityVulnerability>? vulnerabilities,
    int? responseTimeMs,
    DateTime? firstSeen,
    bool? isTrusted,
    bool clearCustomAlias = false,
  }) {
    return DiscoveredDevice(
      ip: ip ?? this.ip,
      macAddress: macAddress ?? this.macAddress,
      hostname: hostname ?? this.hostname,
      customAlias: clearCustomAlias ? null : (customAlias ?? this.customAlias),
      vendor: vendor ?? this.vendor,
      category: category ?? this.category,
      openPorts: openPorts ?? List.from(this.openPorts),
      vulnerabilities: vulnerabilities ?? List.from(this.vulnerabilities),
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      firstSeen: firstSeen ?? this.firstSeen,
      isTrusted: isTrusted ?? this.isTrusted,
    );
  }
}
