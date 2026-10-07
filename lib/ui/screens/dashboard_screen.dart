import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/device_model.dart';
import '../../models/security_model.dart';
import '../../services/network_info_service.dart';
import '../../services/scanner_service.dart';
import '../../services/security_scoring_service.dart';
import '../../services/history_service.dart';
import '../widgets/score_gauge.dart';
import '../widgets/report_modal.dart';
import 'device_detail_screen.dart';
import 'security_tips_screen.dart';
import 'anomaly_detection_screen.dart';
import '../../services/app_settings_service.dart';
import '../../services/platform_support.dart';
import 'expert_dashboard_view.dart';
import 'hidden_camera_screen.dart';
import 'custom_port_scan_screen.dart';
import 'ping_diagnostic_screen.dart';

enum DeviceFilter { all, risky, clean, gateway, cameras, iot }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NetworkInfoService _netInfoService = NetworkInfoService();
  final ScannerService _scannerService = ScannerService();
  final HistoryService _historyService = HistoryService();
  final AppSettingsService _settingsService = AppSettingsService();

  NetworkContext? _networkContext;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatusText = 'Ready to scan your home network';
  int _score = 100;
  List<DiscoveredDevice> _devices = [];
  bool _hasCompletedScan = false;
  bool _isDemoMode = false;
  NetworkAuditResult? _lastAuditResult;

  // Search & Filter
  String _searchQuery = '';
  DeviceFilter _currentFilter = DeviceFilter.all;
  final TextEditingController _searchController = TextEditingController();

  // Warm theme constants
  static const primaryWarm = Color(0xFF6D4C41); // Warm Mocha
  static const deepMocha = Color(0xFF4E342E);   // Deep Espresso
  static const softBrown = Color(0xFF8D6E63);   // Soft Caramel Brown
  static const warmCream = Color(0xFFF5EFEB);   // Soft Warm Cream

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
    _loadNetworkContext();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstRunNotice());
  }

  /// Shown once: responsible use and privacy, before the first scan.
  Future<void> _showFirstRunNotice() async {
    if (!mounted || _historyService.hasAcceptedNotice) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Before you start'),
        content: const SingleChildScrollView(
          child: Text(
            'Only scan networks you own or have permission to test.\n\n'
            'Everything stays on this device. Scan results, history and device names are never uploaded.\n\n'
            'The score shows exposed services on your network. It does not check passwords, firmware or Wi-Fi encryption, so a high score is not a guarantee of safety.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              _historyService.acceptNotice();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNetworkContext() async {
    final ctx = await _netInfoService.getCurrentNetworkContext();
    if (mounted) {
      setState(() {
        _networkContext = ctx;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    // Location permission (needed to read the Wi-Fi name) only exists on
    // phones. On a computer, just refresh the network details.
    if (!PlatformSupport.isMobile) {
      await _loadNetworkContext();
      return;
    }
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      await _loadNetworkContext();
    }
  }

  Future<void> _startNetworkScan() async {
    if (_isScanning) return;

    if (_isDemoMode) {
      setState(() {
        _isScanning = true;
        _scanProgress = 0.25;
        _scanStatusText = 'Presentation Mode: Simulating home network scan...';
        _devices = [];
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() {
        _scanProgress = 0.70;
        _scanStatusText = 'Auditing smart camera, gateway router, and media players...';
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      final demoDevices = ScannerService.getDemoDevices(
          _networkContext?.subnetPrefix ?? '192.168.1');

      final audit = SecurityScoringService.evaluateNetworkHealth(
        subnet: _networkContext?.subnetPrefix ?? '192.168.1',
        localIp: _networkContext?.localIp ?? '192.168.1.105',
        gatewayIp: _networkContext?.gatewayIp ?? '192.168.1.1',
        wifiSsid: 'Demo-SmartHome-WiFi',
        devices: demoDevices,
      );

      // Demo results are not saved to history, so the real trend stays real.
      setState(() {
        _devices = demoDevices;
        _score = audit.overallScore;
        _lastAuditResult = audit;
        _isScanning = false;
        _hasCompletedScan = true;
        _scanStatusText = 'Audit complete. Found ${demoDevices.length} connected devices.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _scanStatusText = 'Checking your Wi-Fi connection...';
    });

    final ctx = await _netInfoService.getCurrentNetworkContext();
    if (!mounted) return;

    if (!ctx.isConnected) {
      // Previously the app silently scanned a made-up 192.168.1.x network.
      setState(() {
        _networkContext = ctx;
        _isScanning = false;
        _scanStatusText =
            'No Wi-Fi connection found. Connect to Wi-Fi, or turn on Demo Mode.';
      });
      return;
    }

    setState(() {
      _networkContext = ctx;
      _scanStatusText = 'Scanning devices on ${ctx.wifiSsid}...';
      _devices = [];
      _score = 100;
    });

    List<DiscoveredDevice> results;
    try {
      results = await _scannerService.scanSubnet(
        subnetPrefix: ctx.subnetPrefix,
        localIp: ctx.localIp,
        gatewayIp: ctx.gatewayIp,
        perPortTimeoutMs: _settingsService.portScanTimeoutMs,
        maxConcurrentHosts: _settingsService.maxConcurrentHosts,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _scanProgress = progress.ratio;
              _scanStatusText = progress.isCancelled
                  ? 'Scan stopped. Showing devices found so far...'
                  : 'Inspecting ${progress.currentScanningIp} (${(progress.ratio * 100).toInt()}%) • ${progress.devicesFound} devices';
            });
          }
        },
      );
    } catch (e) {
      // Without this, any error left the spinner running forever.
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanStatusText = 'Scan failed: $e';
        });
      }
      return;
    }

    // Re-apply the user's saved device names and trusted flags.
    results = _historyService.applyUserPreferences(results);
    final wasCancelled = _scannerService.isCancelled;

    final audit = SecurityScoringService.evaluateNetworkHealth(
      subnet: ctx.subnetPrefix,
      localIp: ctx.localIp,
      gatewayIp: ctx.gatewayIp,
      wifiSsid: ctx.wifiSsid,
      devices: results,
    );

    // A stopped scan only covers part of the network, so it is not saved
    // as a history point (it would distort the trend).
    if (!wasCancelled) {
      _historyService.recordAudit(
        score: audit.overallScore,
        totalDevices: results.length,
        riskyDevices: results.where((d) => d.hasIssues).length,
        wifiSsid: ctx.wifiSsid,
      );
    }

    if (mounted) {
      setState(() {
        _devices = results;
        _score = audit.overallScore;
        _lastAuditResult = audit;
        _isScanning = false;
        _hasCompletedScan = true;
        _scanStatusText = wasCancelled
            ? 'Partial scan: ${results.length} devices found before stopping (not saved to history).'
            : 'Scan completed. Found ${results.length} active devices.';
      });
    }
  }

  /// Called by DeviceDetailScreen whenever a device is renamed, trusted or
  /// re-checked, so the list and the overall score stay in sync.
  /// (Before, those changes only existed inside the detail screen.)
  void _onDeviceUpdated(DiscoveredDevice updated) {
    if (!mounted) return;
    final index = _devices.indexWhere((d) => d.ip == updated.ip);
    if (index == -1) return;

    final ctx = _networkContext;
    final previous = _lastAuditResult;
    final devices = List<DiscoveredDevice>.of(_devices)..[index] = updated;
    final audit = SecurityScoringService.evaluateNetworkHealth(
      subnet: previous?.subnet ?? ctx?.subnetPrefix ?? '192.168.1',
      localIp: previous?.localIp ?? ctx?.localIp ?? '',
      gatewayIp: previous?.gatewayIp ?? ctx?.gatewayIp ?? '',
      wifiSsid: previous?.wifiSsid ?? ctx?.wifiSsid ?? 'Home Wi-Fi',
      devices: devices,
    );

    setState(() {
      _devices = devices;
      _lastAuditResult = audit;
      _score = audit.overallScore;
    });
  }

  void _cancelCurrentScan() {
    _scannerService.cancelScan();
  }

  void _exportAuditReport() {
    if (_lastAuditResult == null) {
      final ctx = _networkContext;
      _lastAuditResult = SecurityScoringService.evaluateNetworkHealth(
        subnet: ctx?.subnetPrefix ?? '192.168.1',
        localIp: ctx?.localIp ?? '192.168.1.105',
        gatewayIp: ctx?.gatewayIp ?? '192.168.1.1',
        wifiSsid: _isDemoMode ? 'Demo-SmartHome-WiFi' : (ctx?.wifiSsid ?? 'Home Wi-Fi'),
        devices: _devices,
      );
    }
    ReportModal.show(context, _lastAuditResult!);
  }

  List<DiscoveredDevice> get _filteredDevices {
    return _devices.where((device) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = device.displayName.toLowerCase().contains(q);
        final matchesIp = device.ip.contains(q);
        final matchesVendor = device.vendor.toLowerCase().contains(q);
        if (!matchesName && !matchesIp && !matchesVendor) return false;
      }

      switch (_currentFilter) {
        case DeviceFilter.all:
          return true;
        case DeviceFilter.risky:
          return device.hasIssues;
        case DeviceFilter.clean:
          return !device.hasIssues;
        case DeviceFilter.gateway:
          return device.category == DeviceCategory.gateway;
        case DeviceFilter.cameras:
          return device.category == DeviceCategory.smartCamera;
        case DeviceFilter.iot:
          return device.category == DeviceCategory.iotDevice;
      }
    }).toList();
  }

  IconData _getDeviceCategoryIcon(DeviceCategory cat) {
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

  @override
  Widget build(BuildContext context) {
    final riskyDevicesCount = _devices.where((d) => d.hasIssues).length;
    final displayDevices = _filteredDevices;
    // No trend arrow in Demo Mode: demo results are not part of history.
    final previousScore =
        _isDemoMode ? null : _historyService.previousAudit?.score;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Security Guardian'),
        centerTitle: false,
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Center(
            child: InkWell(
              onTap: () {
                _settingsService.toggleMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_settingsService.isExpertMode
                        ? '💻 Switched to Expert Technical Mode'
                        : '📱 Switched to Normal Consumer Mode'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: primaryWarm,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _settingsService.isExpertMode ? deepMocha : const Color(0xFFEFEBE9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _settingsService.isExpertMode ? deepMocha : const Color(0xFFD7CCC8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _settingsService.isExpertMode ? Icons.computer_rounded : Icons.phone_android_rounded,
                      size: 13,
                      color: _settingsService.isExpertMode ? Colors.white : primaryWarm,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _settingsService.isExpertMode ? 'Expert' : 'Normal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _settingsService.isExpertMode ? Colors.white : primaryWarm,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          // Presentation Demo Mode toggle
          IconButton(
            icon: Icon(
              _isDemoMode ? Icons.school : Icons.school_outlined,
              color: _isDemoMode ? const Color(0xFFC88A2E) : softBrown,
            ),
            tooltip: _isDemoMode ? 'Presentation Mode Active' : 'Presentation Demo Mode',
            onPressed: () {
              setState(() {
                _isDemoMode = !_isDemoMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isDemoMode
                      ? 'Presentation Demo Mode active (8 testbed devices).'
                      : 'Live Wi-Fi scanning mode restored.'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: primaryWarm,
                ),
              );
            },
          ),
          if (_hasCompletedScan) ...[
            IconButton(
              icon: const Icon(Icons.psychology_outlined),
              tooltip: 'AI Behavioral Anomaly Detector',
              color: softBrown,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AnomalyDetectionScreen(devices: _devices),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Export Audit Report',
              color: softBrown,
              onPressed: _exportAuditReport,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Security Tips',
            color: softBrown,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecurityTipsScreen()),
              );
            },
          ),
        ],
      ),
      body: _settingsService.isExpertMode
          ? ExpertDashboardView(
              networkContext: _networkContext,
              devices: _devices,
              overallScore: _score,
              tier: SecurityTierExtension.fromScore(_score),
              onReScan: _startNetworkScan,
              onDeviceUpdated: _onDeviceUpdated,
              isDemoMode: _isDemoMode,
            )
          : RefreshIndicator(
              color: primaryWarm,
              onRefresh: _startNetworkScan,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Presentation Banner
            if (_isDemoMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF8EC), // Soft warm honey cream
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF6E0B5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFC88A2E), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo Mode: Simulating Phase 1 test network (8 devices with realistic IoT vulnerabilities).',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5D4037),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Soft Wi-Fi Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: warmCream,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAE2DC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wifi_rounded, color: primaryWarm, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isDemoMode
                                  ? 'Demo-SmartHome-WiFi'
                                  : (_networkContext?.wifiSsid ?? 'Checking Wi-Fi...'),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: deepMocha,
                              ),
                            ),
                            if (!_isDemoMode &&
                                _networkContext?.wifiSsid == 'Home Wi-Fi') ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _requestLocationPermission,
                                child: const Icon(
                                  Icons.info_outline,
                                  size: 15,
                                  color: softBrown,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your Device: ${_networkContext?.localIp ?? '...'} • Subnet ${_networkContext?.subnetPrefix ?? '...'}.0/24',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Score Gauge Card
            Card(
              elevation: 0.8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Column(
                  children: [
                    ScoreGauge(score: _score),
                    const SizedBox(height: 12),
                    Text(
                      !_hasCompletedScan
                          ? 'Tap below to evaluate your home network security'
                          : (_score >= 75
                              ? 'Your home network is in good standing!'
                              : 'Identified configuration risks to review.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5D4037),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (previousScore != null && _hasCompletedScan) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _score >= previousScore
                              ? const Color(0xFFEAF5EE)
                              : const Color(0xFFFDF2F2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _score >= previousScore
                              ? '🌱 Score improved +${_score - previousScore} pts since last check'
                              : '⚠️ Score dropped -${previousScore - _score} pts since last check',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _score >= previousScore
                                ? const Color(0xFF2D6A4F)
                                : const Color(0xFFC53030),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan Action & Stop Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startNetworkScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryWarm,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                    ),
                    icon: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.radar_rounded, size: 20),
                    label: Text(
                      _isScanning
                          ? 'Scanning Network...'
                          : (_isDemoMode ? 'Run Demo Audit' : 'Scan Connected Devices'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_isScanning) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _cancelCurrentScan,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC53030),
                      side: const BorderSide(color: Color(0xFFEF9A9A)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop'),
                  ),
                ],
              ],
            ),
            if (_isScanning) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _scanProgress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEFEBE9),
                  valueColor: const AlwaysStoppedAnimation<Color>(primaryWarm),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _scanStatusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
              ),
            ],
            const SizedBox(height: 16),

            // Quick Stats Row & Report Buttons
            if (_hasCompletedScan) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStatBadge(
                      label: 'Connected Assets',
                      value: '${_devices.length}',
                      icon: Icons.devices_rounded,
                      color: const Color(0xFF52796F), // Soft Sage
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatBadge(
                      label: 'Action Items',
                      value: '$riskyDevicesCount',
                      icon: Icons.shield_outlined,
                      color: riskyDevicesCount > 0
                          ? const Color(0xFFD97706) // Warm Amber
                          : const Color(0xFF2D6A4F), // Soft Green
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportAuditReport,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryWarm,
                        side: const BorderSide(color: Color(0xFFD7CCC8)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Audit Report', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AnomalyDetectionScreen(devices: _devices),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5D4037),
                        side: const BorderSide(color: Color(0xFFD7CCC8)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.psychology_outlined, size: 16),
                      label: const Text('AI Anomaly Check', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Search Bar & Filter Chips
            if (_devices.isNotEmpty) ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search device by name, IP, or brand...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFA1887F)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: primaryWarm),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: softBrown),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: warmCream,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
              const SizedBox(height: 8),

              // Filter Chips with warm pill style
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All (${_devices.length})', DeviceFilter.all),
                    const SizedBox(width: 6),
                    _buildFilterChip('Risky ($riskyDevicesCount)', DeviceFilter.risky),
                    const SizedBox(width: 6),
                    _buildFilterChip('Clean (${_devices.length - riskyDevicesCount})', DeviceFilter.clean),
                    const SizedBox(width: 6),
                    _buildFilterChip('Routers', DeviceFilter.gateway),
                    const SizedBox(width: 6),
                    _buildFilterChip('Cameras', DeviceFilter.cameras),
                    const SizedBox(width: 6),
                    _buildFilterChip('Smart Home IoT', DeviceFilter.iot),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Discovered Devices Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Connected Assets (${displayDevices.length})',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: deepMocha,
                  ),
                ),
                if (_devices.isNotEmpty)
                  const Text(
                    'Tap for remediation guide',
                    style: TextStyle(fontSize: 11.5, color: softBrown),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Devices List
            if (_devices.isEmpty && !_isScanning)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: warmCream,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_find_rounded,
                          size: 40, color: softBrown),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No network scan results yet.\nTap "Scan Connected Devices" or "Run Demo Audit" to evaluate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: softBrown, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (displayDevices.isEmpty && _devices.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const Text(
                  'No devices match the current filter or search.',
                  style: TextStyle(color: softBrown),
                ),
              )
            else
              ...displayDevices.map((device) {
                return Card(
                  elevation: 0.6,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: device.hasIssues
                          ? const Color(0xFFFFF3E0) // Soft Peach
                          : const Color(0xFFEAF5EE), // Soft Green
                      child: Icon(
                        _getDeviceCategoryIcon(device.category),
                        color: device.hasIssues
                            ? const Color(0xFFD97706)
                            : const Color(0xFF2D6A4F),
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: deepMocha,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.isTrusted)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE2DC),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TRUSTED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryWarm,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${device.ip} • ${device.categoryDisplayName}',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                    trailing: device.hasIssues
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF9A9A)),
                            ),
                            child: Text(
                              '${device.vulnerabilities.length} Action${device.vulnerabilities.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC53030),
                              ),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline,
                            color: Color(0xFF2D6A4F), size: 20),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceDetailScreen(
                            device: device,
                            gatewayIp: _networkContext?.gatewayIp,
                            isDemoMode: _isDemoMode,
                            onDeviceUpdated: _onDeviceUpdated,
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
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

  Widget _buildFilterChip(String label, DeviceFilter filter) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF5D4037),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryWarm,
      backgroundColor: warmCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _currentFilter = filter;
          });
        }
      },
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
        color: warmCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: deepMocha,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: softBrown),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
