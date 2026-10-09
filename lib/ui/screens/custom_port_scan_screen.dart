import 'package:flutter/material.dart';
import '../../services/network_info_service.dart';
import '../../services/socket_probe.dart';

class CustomPortResult {
  final int port;
  final String service;
  final bool isOpen;
  final int latencyMs;

  const CustomPortResult({
    required this.port,
    required this.service,
    required this.isOpen,
    required this.latencyMs,
  });
}

class CustomPortScanScreen extends StatefulWidget {
  final String initialIp;
  final String? initialDeviceName;

  const CustomPortScanScreen({
    super.key,
    required this.initialIp,
    this.initialDeviceName,
  });

  @override
  State<CustomPortScanScreen> createState() => _CustomPortScanScreenState();
}

class _CustomPortScanScreenState extends State<CustomPortScanScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portsController;

  bool _isScanning = false;

  /// Increases on every start/stop. A running scan stops as soon as the id
  /// changes, so Stop followed by Start can never run two scans at once.
  int _runId = 0;
  bool _rangeWasTrimmed = false;
  int _scannedCount = 0;
  int _totalPorts = 0;
  double _timeoutMs = 200.0;

  final List<CustomPortResult> _results = [];

  static const Color primaryWarm = Color(0xFF6D4C41);
  static const Color backgroundWarm = Color(0xFFFAF8F5);
  static const Color cardWarm = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF3E2723);

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.initialIp);
    _portsController = TextEditingController(text: '21, 22, 23, 80, 443, 554, 1883, 3389, 8080, 9100');
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portsController.dispose();
    super.dispose();
  }

  void _applyPreset(String ports) {
    setState(() {
      _portsController.text = ports;
    });
  }

  List<int> _parsePorts(String text) {
    final Set<int> ports = {};
    final chunks = text.split(',');

    for (var chunk in chunks) {
      chunk = chunk.trim();
      if (chunk.isEmpty) continue;

      if (chunk.contains('-')) {
        final rangeParts = chunk.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null && start <= end && start >= 1 && end <= 65535) {
            final limitEnd = (end - start > 500) ? start + 500 : end; // Prevent UI freeze on extreme ranges
            if (limitEnd != end) _rangeWasTrimmed = true;
            for (int p = start; p <= limitEnd; p++) {
              ports.add(p);
            }
          }
        }
      } else {
        final p = int.tryParse(chunk);
        if (p != null && p >= 1 && p <= 65535) {
          ports.add(p);
        }
      }
    }
    return ports.toList()..sort();
  }

  String _lookupServiceName(int port) {
    switch (port) {
      case 21: return 'FTP';
      case 22: return 'SSH';
      case 23: return 'Telnet';
      case 25: return 'SMTP';
      case 53: return 'DNS';
      case 80: return 'HTTP';
      case 110: return 'POP3';
      case 143: return 'IMAP';
      case 443: return 'HTTPS';
      case 445: return 'SMB';
      case 554: return 'RTSP';
      case 1883: return 'MQTT';
      case 1900: return 'UPnP';
      case 2323: return 'IoT Telnet';
      case 3306: return 'MySQL';
      case 3389: return 'RDP';
      case 5432: return 'PostgreSQL';
      case 5683: return 'CoAP';
      case 5900: return 'VNC';
      case 6379: return 'Redis';
      case 8000: return 'Hikvision/Dev Server';
      case 8080: return 'HTTP-Alt';
      case 9100: return 'JetDirect Print';
      case 27017: return 'MongoDB';
      case 37777: return 'Dahua DVR';
      default: return 'Custom Port';
    }
  }

  Future<void> _startScan() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a target IP address.')),
      );
      return;
    }

    // Home-network tool: only scan private (RFC 1918) addresses. Scanning
    // hosts on the Internet without permission can be illegal and breaks
    // app-store policies.
    if (!NetworkInfoService.isPrivateIpv4(targetIp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only addresses on your own network can be scanned.'),
        ),
      );
      return;
    }

    _rangeWasTrimmed = false;
    final ports = _parsePorts(_portsController.text);
    if (_rangeWasTrimmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Large ranges are limited to 500 ports per range.')),
      );
    }
    if (ports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify valid ports (e.g., 80, 443 or 1-100).')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _results.clear();
      _scannedCount = 0;
      _totalPorts = ports.length;
    });

    const int batchSize = 15;
    final runId = ++_runId;
    for (int i = 0; i < ports.length; i += batchSize) {
      if (runId != _runId || !mounted) break;

      final batch = ports.sublist(i, (i + batchSize > ports.length) ? ports.length : i + batchSize);
      final batchResults = await Future.wait(batch.map((port) async {
        final r = await SocketProbe.probe(
          targetIp,
          port,
          Duration(milliseconds: _timeoutMs.toInt()),
        );
        return CustomPortResult(
          port: port,
          service: _lookupServiceName(port),
          isOpen: r.state == PortState.open,
          latencyMs: r.elapsedMs,
        );
      }));

      // Stop pressed while this batch was running: discard it.
      if (runId != _runId || !mounted) break;

      if (mounted) {
        setState(() {
          _results.addAll(batchResults);
          _scannedCount = _results.length;
        });
      }
    }

    if (mounted && runId == _runId) {
      setState(() {
        _isScanning = false;
      });
      final openCount = _results.where((r) => r.isOpen).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Port scan finished: $openCount open port(s) found out of $_scannedCount checked.'),
          backgroundColor: primaryWarm,
        ),
      );
    }
  }

  void _stopScan() {
    setState(() {
      _runId++;
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final openPorts = _results.where((r) => r.isOpen).toList();
    final closedPorts = _results.where((r) => !r.isOpen).toList();

    return Scaffold(
      backgroundColor: backgroundWarm,
      appBar: AppBar(
        title: const Text(
          'Custom Port Range Scanner',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark),
        ),
        backgroundColor: backgroundWarm,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryWarm),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Target Configuration Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardWarm,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEFEBE9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Target Host',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _ipController,
                  enabled: !_isScanning,
                  decoration: InputDecoration(
                    hintText: 'e.g. 192.168.1.1',
                    prefixIcon: const Icon(Icons.computer_rounded, color: primaryWarm),
                    filled: true,
                    fillColor: backgroundWarm,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Ports or Range (Comma-separated or Range)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _portsController,
                  enabled: !_isScanning,
                  decoration: InputDecoration(
                    hintText: 'e.g. 80, 443, 8080 or 1-100',
                    prefixIcon: const Icon(Icons.numbers_rounded, color: primaryWarm),
                    filled: true,
                    fillColor: backgroundWarm,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Preset Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPresetChip('Web & SSH', '22, 80, 443, 8080'),
                    _buildPresetChip('Databases', '3306, 5432, 6379, 27017'),
                    _buildPresetChip('IoT / Camera', '554, 1883, 1900, 2323, 37777, 8000'),
                    _buildPresetChip('Remote Admin', '22, 3389, 5900'),
                    _buildPresetChip('Range 1-100', '1-100'),
                  ],
                ),

                const SizedBox(height: 14),

                // Timeout Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Socket Probe Timeout:', style: TextStyle(fontSize: 13, color: textDark)),
                    Text('${_timeoutMs.toInt()} ms', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryWarm)),
                  ],
                ),
                Slider(
                  value: _timeoutMs,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  activeColor: primaryWarm,
                  inactiveColor: Colors.grey.shade300,
                  onChanged: _isScanning ? null : (v) => setState(() => _timeoutMs = v),
                ),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? Colors.red.shade700 : primaryWarm,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isScanning ? _stopScan : _startScan,
                    icon: Icon(_isScanning ? Icons.stop_rounded : Icons.radar_rounded),
                    label: Text(
                      _isScanning
                          ? 'Stop Scan ($_scannedCount / $_totalPorts)'
                          : 'Probe Specified Ports',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Results Section
          if (_results.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan Results (${openPorts.length} Open, ${closedPorts.length} Closed)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryWarm),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Open Ports Cards (Highlighted)
            if (openPorts.isNotEmpty)
              ...openPorts.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_open_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Port ${r.port}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${r.service})',
                              style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'OPEN • ${r.latencyMs}ms',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )),

            // Closed Ports Collapsible Summary
            if (closedPorts.isNotEmpty)
              ExpansionTile(
                title: Text(
                  '${closedPorts.length} Closed / Filtered Ports',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                initiallyExpanded: false,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWarm,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: closedPorts
                          .map((r) => Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: backgroundWarm,
                                label: Text('Port ${r.port} (closed)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ))
                          .toList(),
                    ),
                  )
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String ports) {
    final isSelected = _portsController.text == ports;
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : textDark)),
      backgroundColor: isSelected ? primaryWarm : backgroundWarm,
      elevation: 0,
      side: BorderSide(color: isSelected ? primaryWarm : const Color(0xFFD7CCC8)),
      onPressed: _isScanning ? null : () => _applyPreset(ports),
    );
  }
}
