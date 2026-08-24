import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../models/security_model.dart';
import '../../services/network_info_service.dart';
import '../../services/scanner_service.dart';
import '../../services/security_scoring_service.dart';
import '../widgets/score_gauge.dart';
import 'device_detail_screen.dart';
import 'security_tips_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NetworkInfoService _netInfoService = NetworkInfoService();
  final ScannerService _scannerService = ScannerService();

  NetworkContext? _networkContext;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatusText = 'Ready to scan';
  int _score = 100;
  List<DiscoveredDevice> _devices = [];
  bool _hasCompletedScan = false;

  @override
  void initState() {
    super.initState();
    _loadNetworkContext();
  }

  Future<void> _loadNetworkContext() async {
    final ctx = await _netInfoService.getCurrentNetworkContext();
    if (mounted) {
      setState(() {
        _networkContext = ctx;
      });
    }
  }

  Future<void> _startNetworkScan() async {
    if (_isScanning) return;

    final ctx = await _netInfoService.getCurrentNetworkContext();
    setState(() {
      _networkContext = ctx;
      _isScanning = true;
      _scanProgress = 0.0;
      _scanStatusText = 'Starting scan on ${ctx.wifiSsid}...';
      _devices = [];
      _score = 100;
    });

    final results = await _scannerService.scanSubnet(
      subnetPrefix: ctx.subnetPrefix,
      localIp: ctx.localIp,
      gatewayIp: ctx.gatewayIp,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _scanProgress = progress.ratio;
            _scanStatusText =
                'Checking ${progress.currentScanningIp} (${(progress.ratio * 100).toInt()}%) - Found ${progress.devicesFound} devices';
          });
        }
      },
    );

    final audit = SecurityScoringService.evaluateNetworkHealth(
      subnet: ctx.subnetPrefix,
      localIp: ctx.localIp,
      gatewayIp: ctx.gatewayIp,
      wifiSsid: ctx.wifiSsid,
      devices: results,
    );

    if (mounted) {
      setState(() {
        _devices = results;
        _score = audit.overallScore;
        _isScanning = false;
        _hasCompletedScan = true;
        _scanStatusText = 'Scan completed. Found ${results.length} active devices.';
      });
    }
  }

  IconData _getDeviceCategoryIcon(DeviceCategory cat) {
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
    final riskyDevicesCount = _devices.where((d) => d.hasIssues).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Security Guardian'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Security Tips',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecurityTipsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _startNetworkScan,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Wi-Fi Status Bar Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _networkContext?.wifiSsid ?? 'Searching Wi-Fi...',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        Text(
                          'Your IP: ${_networkContext?.localIp ?? '...'} (Subnet ${_networkContext?.subnetPrefix ?? '...'}.0/24)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Score Card & Gauge
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ScoreGauge(score: _score),
                    const SizedBox(height: 14),
                    Text(
                      !_hasCompletedScan
                          ? 'Tap below to scan and evaluate your Wi-Fi hygiene'
                          : (_score >= 80
                              ? 'Your home network is secure!'
                              : 'Security vulnerabilities found on your Wi-Fi.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan Action Button
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startNetworkScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.radar),
              label: Text(
                _isScanning ? 'Scanning Network...' : 'Scan Connected Devices',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (_isScanning) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _scanProgress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _scanStatusText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 20),

            // Quick Stats Row
            if (_hasCompletedScan)
              Row(
                children: [
                  Expanded(
                    child: _buildStatBadge(
                      label: 'Total Devices',
                      value: '${_devices.length}',
                      icon: Icons.devices,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatBadge(
                      label: 'Needs Fix',
                      value: '$riskyDevicesCount',
                      icon: Icons.warning_amber_rounded,
                      color: riskyDevicesCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Discovered Devices Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connected Devices (${_devices.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_devices.isNotEmpty)
                  Text(
                    'Tap device for fix guide',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Devices List
            if (_devices.isEmpty && !_isScanning)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.wifi_find, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No scan results yet.\nTap "Scan Connected Devices" to check your network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              ..._devices.map((device) {
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: device.hasIssues
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                      child: Icon(
                        _getDeviceCategoryIcon(device.category),
                        color: device.hasIssues
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                    title: Text(
                      device.hostname,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${device.ip} • ${device.categoryDisplayName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    trailing: device.hasIssues
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              '${device.vulnerabilities.length} Risk${device.vulnerabilities.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, color: Colors.green),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceDetailScreen(device: device),
                        ),
                      );
                    },
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
