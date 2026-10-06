import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../models/security_model.dart';
import '../../services/scanner_service.dart';
import '../../services/history_service.dart';
import '../../services/app_settings_service.dart';
import '../widgets/vulnerability_card.dart';
import 'custom_port_scan_screen.dart';
import 'ping_diagnostic_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final DiscoveredDevice device;
  final String? gatewayIp;

  /// Demo devices don't exist on the real network, so re-checking them
  /// would wrongly report every issue as fixed.
  final bool isDemoMode;

  /// Notifies the dashboard about renames, trust changes and re-check
  /// results so its list and overall score update too.
  final ValueChanged<DiscoveredDevice>? onDeviceUpdated;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    this.gatewayIp,
    this.isDemoMode = false,
    this.onDeviceUpdated,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late DiscoveredDevice _currentDevice;
  final HistoryService _historyService = HistoryService();
  final ScannerService _scannerService = ScannerService();
  bool _isRechecking = false;

  // Warm theme palette
  static const primaryWarm = Color(0xFF6D4C41); // Warm Mocha
  static const deepMocha = Color(0xFF4E342E);   // Deep Espresso
  static const softBrown = Color(0xFF8D6E63);   // Soft Caramel Brown
  static const warmCream = Color(0xFFF5EFEB);   // Soft Warm Cream

  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device;
  }

  void _updateDevice(DiscoveredDevice updated) {
    setState(() => _currentDevice = updated);
    widget.onDeviceUpdated?.call(updated);
  }

  IconData _getDeviceIcon(DeviceCategory cat) {
    switch (cat) {
      case DeviceCategory.gateway:
        return Icons.router_outlined;
      case DeviceCategory.smartCamera:
        return Icons.videocam_outlined;
      case DeviceCategory.printer:
        return Icons.print_outlined;
      case DeviceCategory.computer:
        return Icons.laptop_outlined;
      case DeviceCategory.phoneOrTablet:
        return Icons.smartphone_outlined;
      case DeviceCategory.entertainment:
        return Icons.tv_outlined;
      case DeviceCategory.iotDevice:
        return Icons.sensors_outlined;
      case DeviceCategory.unknown:
        return Icons.devices_other_outlined;
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _currentDevice.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Customize Device Name',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: deepMocha),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Living Room Camera',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA1887F)),
            filled: true,
            fillColor: warmCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: softBrown)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryWarm,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save Name', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName == null || !mounted) return; // dialog cancelled
    // An empty name now resets the device to its detected name.
    _updateDevice(newName.isEmpty
        ? _currentDevice.copyWith(clearCustomAlias: true)
        : _currentDevice.copyWith(customAlias: newName));
    _historyService.setCustomAlias(_currentDevice.ip, newName);
  }

  void _toggleTrustStatus() {
    final newTrust = !_currentDevice.isTrusted;
    _updateDevice(_currentDevice.copyWith(isTrusted: newTrust));
    _historyService.setDeviceTrusted(_currentDevice.ip, newTrust);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newTrust
            ? '${_currentDevice.displayName} marked as trusted.'
            : '${_currentDevice.displayName} unmarked as trusted.'),
        duration: const Duration(seconds: 2),
        backgroundColor: primaryWarm,
      ),
    );
  }

  Future<void> _recheckDevice() async {
    if (widget.isDemoMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Re-check needs a real scan. Turn off Demo Mode and scan your network first.'),
          backgroundColor: primaryWarm,
        ),
      );
      return;
    }

    setState(() {
      _isRechecking = true;
    });

    DiscoveredDevice? updated;
    try {
      updated = await _scannerService.recheckHost(
        ip: _currentDevice.ip,
        mac: _currentDevice.macAddress,
        hostname: _currentDevice.hostname,
        category: _currentDevice.category,
        vendor: _currentDevice.vendor,
        gatewayIp: widget.gatewayIp ?? '',
      );
    } catch (_) {
      updated = null;
    }

    if (!mounted) return;
    setState(() {
      _isRechecking = false;
    });

    if (updated == null) {
      // Before, an offline device came back with zero open ports and the
      // app announced "Device is fully secured!".
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The device did not respond, so the fix could not be confirmed. Make sure it is switched on and connected, then try again.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    _updateDevice(_currentDevice.copyWith(
      openPorts: updated.openPorts,
      vulnerabilities: updated.vulnerabilities,
      responseTimeMs: updated.responseTimeMs,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated.hasIssues
            ? 'Re-check complete: ${updated.vulnerabilities.length} active risk(s) detected.'
            : 'Re-check complete: no risky services found on this device. 🎉'),
        backgroundColor: updated.hasIssues ? const Color(0xFFD97706) : const Color(0xFF2D6A4F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = _currentDevice;
    final devScore = (100 - device.riskScoreDeduction).clamp(0, 100);
    final tier = SecurityTierExtension.fromScore(devScore);

    Color tierColor;
    Color tierBg;
    if (devScore >= 90) {
      tierColor = const Color(0xFF2D6A4F);
      tierBg = const Color(0xFFEAF5EE);
    } else if (devScore >= 75) {
      tierColor = const Color(0xFF52796F);
      tierBg = const Color(0xFFE0F2F1);
    } else if (devScore >= 60) {
      tierColor = const Color(0xFFC88A2E);
      tierBg = const Color(0xFFFFF8E1);
    } else if (devScore >= 40) {
      tierColor = const Color(0xFFD97706);
      tierBg = const Color(0xFFFFF3E0);
    } else {
      tierColor = const Color(0xFFC53030);
      tierBg = const Color(0xFFFFEBEE);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(device.displayName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              device.isTrusted ? Icons.verified : Icons.verified_outlined,
              color: device.isTrusted ? const Color(0xFF2D6A4F) : softBrown,
            ),
            tooltip: device.isTrusted ? 'Trusted Device' : 'Mark as Trusted',
            onPressed: _toggleTrustStatus,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename Device',
            color: softBrown,
            onPressed: _showRenameDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Header Card
          Card(
            elevation: 0.8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: device.hasIssues ? const Color(0xFFFFF3E0) : const Color(0xFFEAF5EE),
                        child: Icon(
                          _getDeviceIcon(device.category),
                          size: 30,
                          color: device.hasIssues ? const Color(0xFFD97706) : const Color(0xFF2D6A4F),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device.displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: deepMocha,
                                    ),
                                  ),
                                ),
                                if (device.isTrusted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF5EE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TRUSTED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D6A4F),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${device.categoryDisplayName} • ${device.vendor}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: warmCream,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'IP: ${device.ip}  (${device.responseTimeMs}ms)',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: deepMocha),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tierBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: tierColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'Score: $devScore/100 (${tier.displayName})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: tierColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFEFEBE9)),

                  // Re-test Device Action Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isRechecking ? null : _recheckDevice,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryWarm,
                        side: const BorderSide(color: Color(0xFFD7CCC8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: _isRechecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(primaryWarm)),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isRechecking ? 'Re-probing Device...' : 'Re-Check Device Security Now',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Expert Diagnostics Card (Only in Expert Mode)
          if (AppSettingsService().isExpertMode) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723), // Deep Cocoa HUD
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal_rounded, color: Color(0xFFFFCCBC), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'EXPERT HOST DIAGNOSTICS',
                        style: TextStyle(
                          color: Color(0xFFFFCCBC),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Target: ${device.ip} | Hostname: ${device.hostname}',
                    style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OS Fingerprint: ${device.category == DeviceCategory.computer ? "TTL ≈ 128 (Windows NT/Server Stack)" : "TTL ≈ 64 (Linux / Embedded RTOS Stack)"}',
                    style: const TextStyle(color: Color(0xFFBCAAA4), fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const Divider(color: Color(0xFF5D4037), height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFE0B2),
                            side: const BorderSide(color: Color(0xFF8D6E63)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.manage_search_rounded, size: 16),
                          label: const Text('Custom Port Sweep', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomPortScanScreen(
                                initialIp: device.ip,
                                initialDeviceName: device.displayName,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFE0B2),
                            side: const BorderSide(color: Color(0xFF8D6E63)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.network_ping_rounded, size: 16),
                          label: const Text('Ping / Jitter Test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PingDiagnosticScreen(initialHost: device.ip),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Security Vulnerabilities Section
          Row(
            children: [
              Icon(
                device.hasIssues ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                color: device.hasIssues ? const Color(0xFFD97706) : const Color(0xFF2D6A4F),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                device.hasIssues
                    ? 'Recommended Actions (${device.vulnerabilities.length})'
                    : 'Security Status: Clean',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: deepMocha,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!device.hasIssues)
            Card(
              elevation: 0.6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF5EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Color(0xFF2D6A4F), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No Security Risks Found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: deepMocha),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'This device does not expose unencrypted or vulnerable administration services.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...device.vulnerabilities.map(
              (v) => VulnerabilityCard(vulnerability: v, deviceIp: device.ip),
            ),

          const SizedBox(height: 18),

          // Network Technical Information
          const Text(
            'Technical Hardware Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: deepMocha),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0.6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow('IP Address', device.ip),
                  const Divider(color: Color(0xFFF5EFEB)),
                  _buildDetailRow('MAC Address', device.macAddress ?? 'Unavailable (Hidden by OS)'),
                  const Divider(color: Color(0xFFF5EFEB)),
                  _buildDetailRow('Hardware Vendor', device.vendor),
                  const Divider(color: Color(0xFFF5EFEB)),
                  _buildDetailRow('Network Hostname', device.hostname ?? 'Unknown'),
                  const Divider(color: Color(0xFFF5EFEB)),
                  _buildDetailRow('Latency (Ping)', '${device.responseTimeMs} ms'),
                  const Divider(color: Color(0xFFF5EFEB)),
                  _buildDetailRow('Role in Network', widget.gatewayIp == device.ip ? 'Default Gateway (Router)' : 'Client Host'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Open Ports Section
          Text(
            'Active Listening Ports (${device.openPorts.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: deepMocha),
          ),
          const SizedBox(height: 8),
          if (device.openPorts.isEmpty)
            Card(
              elevation: 0.6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No common services listening. Device appears to operate in stealth mode.',
                  style: TextStyle(color: softBrown, fontSize: 12),
                ),
              ),
            )
          else
            Card(
              elevation: 0.6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: device.openPorts.map((port) {
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: port.isSecure ? const Color(0xFFEAF5EE) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${port.port}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: port.isSecure ? const Color(0xFF2D6A4F) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    title: Text(
                      port.serviceName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: deepMocha),
                    ),
                    subtitle: Text(
                      port.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    trailing: Icon(
                      port.isSecure ? Icons.lock_outline : Icons.lock_open_rounded,
                      size: 17,
                      color: port.isSecure ? const Color(0xFF2D6A4F) : const Color(0xFFD97706),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: softBrown)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: deepMocha,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
