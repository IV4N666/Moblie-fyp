import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../widgets/vulnerability_card.dart';

class DeviceDetailScreen extends StatelessWidget {
  final DiscoveredDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  IconData _getDeviceIcon(DeviceCategory cat) {
    switch (cat) {
      case DeviceCategory.gateway:
        return Icons.router;
      case DeviceCategory.smartCamera:
        return Icons.videocam;
      case DeviceCategory.printer:
        return Icons.print;
      case DeviceCategory.computer:
        return Icons.laptop_mac;
      case DeviceCategory.phoneOrTablet:
        return Icons.phone_iphone;
      case DeviceCategory.entertainment:
        return Icons.tv;
      case DeviceCategory.iotDevice:
        return Icons.sensors;
      case DeviceCategory.unknown:
        return Icons.device_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.hostname),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Header Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: device.hasIssues ? Colors.orange.shade100 : Colors.green.shade100,
                    child: Icon(
                      _getDeviceIcon(device.category),
                      size: 32,
                      color: device.hasIssues ? Colors.orange.shade800 : Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.hostname,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${device.categoryDisplayName} • ${device.vendor}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'IP: ${device.ip}  (${device.responseTimeMs}ms)',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Security Vulnerabilities Section
          Row(
            children: [
              Icon(
                device.hasIssues ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                color: device.hasIssues ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                device.hasIssues
                    ? 'Detected Security Risks (${device.vulnerabilities.length})'
                    : 'Security Status: Clean',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (device.hasIssues)
            ...device.vulnerabilities.map((vuln) {
              return VulnerabilityCard(vulnerability: vuln, deviceIp: device.ip);
            }).toList()
          else
            Card(
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No unencrypted or legacy high-risk services found on this device.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Open Ports & Services
          const Text(
            'Reachable Services / Ports',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (device.openPorts.isEmpty)
            Text(
              'No public listening ports detected.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: device.openPorts.length,
                separatorBuilder: (context, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final port = device.openPorts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: port.isSecure ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Text(
                        '${port.port}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: port.isSecure ? Colors.green.shade900 : Colors.black87,
                        ),
                      ),
                    ),
                    title: Text(
                      port.serviceName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      port.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
