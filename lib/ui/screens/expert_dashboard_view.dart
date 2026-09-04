import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/device_model.dart';
import '../../models/security_model.dart';
import '../../services/network_info_service.dart';
import 'hidden_camera_screen.dart';
import 'custom_port_scan_screen.dart';
import 'ping_diagnostic_screen.dart';
import 'anomaly_detection_screen.dart';
import 'device_detail_screen.dart';

class ExpertDashboardView extends StatelessWidget {
  final NetworkContext? networkContext;
  final List<DiscoveredDevice> devices;
  final int overallScore;
  final SecurityTier tier;
  final VoidCallback onReScan;

  const ExpertDashboardView({
    super.key,
    required this.networkContext,
    required this.devices,
    required this.overallScore,
    required this.tier,
    required this.onReScan,
  });

  static const Color primaryWarm = Color(0xFF6D4C41);
  static const Color backgroundWarm = Color(0xFFFAF8F5);
  static const Color cardWarm = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF3E2723);

  void _exportSubnetCsv(BuildContext context) {
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices scanned to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('IP Address,Hostname,MAC Address,Vendor,Category,Open Ports,Risk Penalty,Response Latency (ms)');

    for (final dev in devices) {
      final openPortsStr = dev.openPorts.map((p) => p.port).join(';');
      buffer.writeln(
        '${dev.ip},"${dev.displayName}","${dev.macAddress ?? "N/A"}","${dev.vendor}","${dev.categoryDisplayName}","$openPortsStr",-${dev.riskScoreDeduction},${dev.responseTimeMs}',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Subnet inventory exported to CSV and copied to clipboard!'),
        backgroundColor: primaryWarm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRisky = devices.where((d) => d.hasIssues).length;
    final totalSafe = devices.length - totalRisky;
    final avgLatency = devices.isNotEmpty
        ? (devices.fold(0, (sum, d) => sum + d.responseTimeMs) / devices.length).toStringAsFixed(1)
        : '0';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Technical HUD Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF3E2723), // Deep Cocoa HUD
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal_rounded, color: Color(0xFFFFCCBC), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'EXPERT TECHNICAL HUD',
                        style: TextStyle(
                          color: Color(0xFFFFCCBC),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D4037),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Subnet: ${networkContext?.subnetPrefix ?? "192.168.1"}.0/24',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHudMetric('Total Hosts', '${devices.length}', const Color(0xFFFFE0B2)),
                  _buildHudMetric('Vulnerable', '$totalRisky', totalRisky > 0 ? const Color(0xFFFF8A80) : const Color(0xFFB9F6CA)),
                  _buildHudMetric('Hardened', '$totalSafe', const Color(0xFFB9F6CA)),
                  _buildHudMetric('Avg RTT', '$avgLatency ms', const Color(0xFFE0E0E0)),
                  _buildHudMetric('CVSS Score', '$overallScore/100', const Color(0xFFFFD54F)),
                ],
              ),
              const Divider(color: Color(0xFF5D4037), height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gateway: ${networkContext?.gatewayIp ?? "192.168.1.1"} | Local: ${networkContext?.localIp ?? "192.168.1.105"}',
                    style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 11, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Tier: ${tier.displayName}',
                    style: const TextStyle(color: Color(0xFFFFCCBC), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Expert Tools Row
        const Text(
          'Advanced Diagnostic Tools',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildToolButton(
                context,
                icon: Icons.videocam_rounded,
                title: 'Camera Sniffer',
                subtitle: 'RTSP / ONVIF',
                color: Colors.red.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HiddenCameraScreen(currentDevices: devices)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolButton(
                context,
                icon: Icons.manage_search_rounded,
                title: 'Port Scanner',
                subtitle: 'Custom Ranges',
                color: Colors.blue.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomPortScanScreen(
                      initialIp: devices.isNotEmpty ? devices.first.ip : '192.168.1.1',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildToolButton(
                context,
                icon: Icons.network_ping_rounded,
                title: 'Ping / Jitter',
                subtitle: 'Stability Diagnostic',
                color: Colors.purple.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PingDiagnosticScreen(
                      initialHost: networkContext?.gatewayIp ?? '192.168.1.1',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToolButton(
                context,
                icon: Icons.psychology_rounded,
                title: 'AI Anomalies',
                subtitle: 'Unsupervised ML',
                color: Colors.amber.shade900,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnomalyDetectionScreen(devices: devices),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Subnet Asset Inventory Header with Export CSV
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subnet Data Grid (${devices.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: primaryWarm,
                backgroundColor: const Color(0xFFEFEBE9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _exportSubnetCsv(context),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // High-Density Data Grid
        if (devices.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardWarm, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('No active hosts discovered. Tap Scan to sweep subnet.')),
          )
        else
          ...devices.map((dev) => _buildHighDensityRow(context, dev)),
      ],
    );
  }

  Widget _buildHudMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBCAAA4), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cardWarm,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEFEBE9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildHighDensityRow(BuildContext context, DiscoveredDevice dev) {
    final statusColor = dev.hasIssues ? Colors.red.shade700 : Colors.green.shade700;
    final ports = dev.openPorts.map((p) => p.port).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dev.hasIssues ? const Color(0xFFFFCDD2) : const Color(0xFFEFEBE9)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dev.ip,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: backgroundWarm,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        dev.categoryDisplayName.split(' ').first,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${dev.displayName} • ${dev.vendor}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (ports.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Open Ports: ${ports.join(', ')}',
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade800),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dev.hasIssues ? '-${dev.riskScoreDeduction} pts' : 'CLEAN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dev.responseTimeMs} ms',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryWarm),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceDetailScreen(
                  device: dev,
                  gatewayIp: networkContext?.gatewayIp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
