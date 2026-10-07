import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/ping_service.dart';

class PingDiagnosticScreen extends StatefulWidget {
  final String initialHost;

  const PingDiagnosticScreen({super.key, required this.initialHost});

  @override
  State<PingDiagnosticScreen> createState() => _PingDiagnosticScreenState();
}

class _PingDiagnosticScreenState extends State<PingDiagnosticScreen> {
  late TextEditingController _hostController;
  int _targetPort = 80;
  int _totalCount = 15;
  bool _isRunning = false;
  /// Increases on every start/stop; a running test stops when it changes.
  int _runId = 0;

  final List<PingSample> _samples = [];
  final ScrollController _scrollController = ScrollController();

  static const Color primaryWarm = Color(0xFF6D4C41);
  static const Color backgroundWarm = Color(0xFFFAF8F5);
  static const Color cardWarm = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF3E2723);

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialHost.isNotEmpty ? widget.initialHost : '192.168.1.1');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startPing() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _isRunning = true;
      _samples.clear();
    });
    final runId = ++_runId;

    for (int i = 1; i <= _totalCount; i++) {
      if (runId != _runId || !mounted) break;

      final sample = await PingDiagnosticService.singleProbe(
        host: host,
        port: _targetPort,
        sequence: i,
        timeoutMs: 1200,
      );

      if (runId != _runId || !mounted) break;
      setState(() {
        _samples.add(sample);
      });
      // Auto scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted && runId == _runId) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _stopPing() {
    setState(() {
      _runId++;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = PingStatistics.calculate(_samples);

    return Scaffold(
      backgroundColor: backgroundWarm,
      appBar: AppBar(
        title: const Text(
          'Ping & Network Jitter Diagnostics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark),
        ),
        backgroundColor: backgroundWarm,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryWarm),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            // Controls Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardWarm,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEFEBE9)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hostController,
                          enabled: !_isRunning,
                          decoration: InputDecoration(
                            labelText: 'Host / IP Address',
                            prefixIcon: const Icon(Icons.network_ping_rounded, color: primaryWarm),
                            filled: true,
                            fillColor: backgroundWarm,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: _targetPort,
                        dropdownColor: cardWarm,
                        onChanged: _isRunning ? null : (v) => setState(() => _targetPort = v ?? 80),
                        items: const [
                          DropdownMenuItem(value: 80, child: Text('Port 80 (HTTP)')),
                          DropdownMenuItem(value: 443, child: Text('Port 443 (HTTPS)')),
                          DropdownMenuItem(value: 53, child: Text('Port 53 (DNS)')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? Colors.red.shade700 : primaryWarm,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isRunning ? _stopPing : _startPing,
                      icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(_isRunning ? 'Stop Ping Test' : 'Run Ping Diagnostic ($_totalCount Packets)'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Statistics Grid (When samples exist)
            if (_samples.isNotEmpty) ...[
              Row(
                children: [
                  _buildStatCard('Avg Latency', '${stats.avgLatencyMs} ms', Icons.speed_rounded, Colors.blue.shade700),
                  const SizedBox(width: 8),
                  _buildStatCard('Jitter', '${stats.jitterMs} ms', Icons.waves_rounded, Colors.deepPurple.shade700),
                  const SizedBox(width: 8),
                  _buildStatCard('Min / Max', '${stats.minLatencyMs} / ${stats.maxLatencyMs}', Icons.swap_vert_rounded, Colors.orange.shade800),
                  const SizedBox(width: 8),
                  _buildStatCard('Loss Rate', '${stats.packetLossRate}%', Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                      stats.packetLossRate > 0 ? Colors.red.shade700 : Colors.green.shade700),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Live Log Stream
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardWarm,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEFEBE9)),
                ),
                child: _samples.isEmpty
                    ? Center(
                        child: Text(
                          'Press "Run Ping Diagnostic" to probe round-trip latency and stability.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _samples.length,
                        itemBuilder: (ctx, idx) {
                          final s = _samples[idx];
                          final latColor = s.isSuccess
                              ? (s.latencyMs < 30
                                  ? Colors.green.shade700
                                  : (s.latencyMs < 100 ? Colors.orange.shade800 : Colors.red.shade700))
                              : Colors.red.shade800;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      s.isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      size: 16,
                                      color: latColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Seq #${s.sequence}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                                    ),
                                  ],
                                ),
                                Text(
                                  s.status,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: latColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${s.latencyMs} ms',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: latColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
