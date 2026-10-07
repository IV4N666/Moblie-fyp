import 'package:wifi_guardian_app/models/device_model.dart';
import 'package:wifi_guardian_app/models/security_model.dart';
import 'package:wifi_guardian_app/services/vulnerability_db.dart';

/// Builds a device whose open ports and findings match [ports].
DiscoveredDevice deviceWithPorts(
  String ip,
  List<int> ports, {
  DeviceCategory category = DeviceCategory.iotDevice,
  String hostname = 'Test Device',
}) {
  return DiscoveredDevice(
    ip: ip,
    hostname: hostname,
    category: category,
    openPorts: [
      for (final p in ports)
        PortInfo(port: p, serviceName: 'Port $p', isSecure: false, description: ''),
    ],
    vulnerabilities: _findings(ports),
  );
}

/// Knowledge-base findings for [ports], one per weakness id (as the scanner does).
List<SecurityVulnerability> _findings(List<int> ports) {
  final found = <SecurityVulnerability>[];
  for (final p in ports) {
    final v = VulnerabilityDatabase.getVulnerabilityForPort(p);
    if (v != null && !found.any((f) => f.id == v.id)) found.add(v);
  }
  return found;
}
