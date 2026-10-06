import 'package:wifi_guardian_app/models/device_model.dart';
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
    vulnerabilities: [
      for (final p in ports)
        if ((VulnerabilityDatabase.getVulnerabilityForPort(p)?.penaltyPoints ?? 0) > 0)
          VulnerabilityDatabase.getVulnerabilityForPort(p)!,
    ],
  );
}
