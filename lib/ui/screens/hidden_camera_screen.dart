import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../services/hidden_camera_service.dart';

class HiddenCameraScreen extends StatefulWidget {
  final List<DiscoveredDevice> currentDevices;

  const HiddenCameraScreen({super.key, required this.currentDevices});

  @override
  State<HiddenCameraScreen> createState() => _HiddenCameraScreenState();
}

class _HiddenCameraScreenState extends State<HiddenCameraScreen> {
  late HiddenCameraScanReport _report;
  bool _isScanning = false;

  static const Color primaryWarm = Color(0xFF6D4C41);
  static const Color backgroundWarm = Color(0xFFFAF8F5);
  static const Color cardWarm = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF3E2723);

  @override
  void initState() {
    super.initState();
    _report = HiddenCameraService.analyzeFromInventory(widget.currentDevices);
  }

  void _runDeepCameraScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _report = HiddenCameraService.analyzeFromInventory(widget.currentDevices);
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_report.hasHiddenCameras
              ? 'Found ${_report.streamCount} active surveillance streams!'
              : 'Scan complete: No exposed RTSP or surveillance streams found.'),
          backgroundColor: _report.hasHiddenCameras ? Colors.red.shade800 : primaryWarm,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWarm,
      appBar: AppBar(
        title: const Text(
          'Hidden Camera & Privacy Sniffer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark),
        ),
        backgroundColor: backgroundWarm,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryWarm),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-scan Cameras',
            onPressed: _isScanning ? null : _runDeepCameraScan,
          )
        ],
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryWarm),
                  SizedBox(height: 16),
                  Text(
                    'Sniffing RTSP & Surveillance Ports (554, 8000, 37777)...',
                    style: TextStyle(color: primaryWarm, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Radar / Status Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _report.hasHiddenCameras ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _report.hasHiddenCameras ? const Color(0xFFFFCDD2) : const Color(0xFFC8E6C9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _report.hasHiddenCameras ? Colors.red.shade100 : Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _report.hasHiddenCameras ? Icons.videocam_off_rounded : Icons.verified_user_rounded,
                          color: _report.hasHiddenCameras ? Colors.red.shade800 : Colors.green.shade800,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _report.hasHiddenCameras
                                  ? '⚠️ Surveillance Streams Detected'
                                  : '✅ Wi-Fi Privacy Protected',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _report.hasHiddenCameras ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _report.hasHiddenCameras
                                  ? '${_report.streamCount} surveillance device(s) streaming on local Wi-Fi.'
                                  : 'Zero exposed RTSP or DVR surveillance feeds found on this subnet.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _report.hasHiddenCameras ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detected Cameras (${_report.detectedCameras.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    Text(
                      'Targeting RTSP / ONVIF / DVR',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_report.detectedCameras.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardWarm,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade600),
                        const SizedBox(height: 12),
                        const Text(
                          'No Hidden Cameras Detected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'All connected devices are safe endpoints (smartphones, PCs, safe gateways). No unencrypted surveillance feeds exist.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ..._report.detectedCameras.map((cam) => Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardWarm,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.videocam_rounded, color: Colors.red.shade800, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cam.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
                                      ),
                                      Text(
                                        '${cam.ip} • Port ${cam.port} (${cam.vendor})',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cam.protocolName.split(' ').first,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cam.riskExplanation,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                            ),
                            const Divider(height: 20),
                            const Text(
                              'Remediation & Privacy Advice:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                            ),
                            const SizedBox(height: 6),
                            ...cam.remediationSteps.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: primaryWarm)),
                                    Expanded(
                                      child: Text(s, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),

                const SizedBox(height: 16),

                // Educational Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBE6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: primaryWarm, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Privacy Tip: When staying at hotels or rental properties, run this check after connecting to Wi-Fi. Legitimate smart TVs may show media ports, but active RTSP (554) video streams indicate an active camera on your shared local network.',
                          style: TextStyle(fontSize: 12, color: Colors.brown.shade800, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
