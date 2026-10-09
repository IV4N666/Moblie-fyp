import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../services/anomaly_detection_service.dart';

class AnomalyDetectionScreen extends StatelessWidget {
  final List<DiscoveredDevice> devices;

  const AnomalyDetectionScreen({
    super.key,
    required this.devices,
  });

  static const primaryWarm = Color(0xFF6D4C41); // Warm Mocha
  static const deepMocha = Color(0xFF4E342E);   // Deep Espresso
  static const softBrown = Color(0xFF8D6E63);   // Soft Caramel Brown
  static const warmCream = Color(0xFFF5EFEB);   // Soft Warm Cream

  @override
  Widget build(BuildContext context) {
    final profiles = AnomalyDetectionService.analyzeNetwork(devices);
    final anomalousCount = profiles.where((p) => p.isAnomalous).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Detector'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warm Mocha Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6D4C41), Color(0xFF8D6E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x206D4C41),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.psychology_outlined,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Isolation Forest + Expert Rules',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Unsupervised: compares each device with the others on this network',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Finds devices that behave differently from the rest of your network.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overview Status Card
          Card(
            elevation: 0.8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: anomalousCount > 0
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFEAF5EE),
                    child: Icon(
                      anomalousCount > 0
                          ? Icons.warning_amber_rounded
                          : Icons.verified_user_outlined,
                      color: anomalousCount > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF2D6A4F),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anomalousCount > 0
                              ? '$anomalousCount Device(s) Deviate From Baseline'
                              : 'All Devices Match Normal Baselines',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: deepMocha,
                          ),
                        ),
                        Text(
                          anomalousCount > 0
                              ? 'Unusual service ports detected that do not match standard device category roles.'
                              : 'No irregular communication channels or uncharacteristic open services detected.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Profiles List Header
          const Text(
            'Device Baseline Analysis',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: deepMocha,
            ),
          ),
          const SizedBox(height: 8),

          ...profiles.map((profile) {
            final devScorePct = (profile.anomalyScore * 100).toInt();
            Color statusColor;
            Color statusBg;

            if (profile.anomalyScore >= 0.70) {
              statusColor = const Color(0xFFC53030); // Soft Red
              statusBg = const Color(0xFFFDF2F2);
            } else if (profile.anomalyScore >= 0.40) {
              statusColor = const Color(0xFFD97706); // Warm Amber
              statusBg = const Color(0xFFFFFBEB);
            } else {
              statusColor = const Color(0xFF2D6A4F); // Soft Green
              statusBg = const Color(0xFFEAF5EE);
            }

            return Card(
              elevation: 0.6,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.device.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: deepMocha,
                                ),
                              ),
                              Text(
                                '${profile.device.ip} • ${profile.device.categoryDisplayName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            '$devScorePct% Anomaly Score',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress Track
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: profile.anomalyScore,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEFEBE9),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Shows how the score was built, so it can be explained.
                    Text(
                      profile.isolationScore == null
                          ? 'Rules: ${(profile.ruleScore * 100).round()}% • Isolation Forest: needs 4+ devices'
                          : 'Rules: ${(profile.ruleScore * 100).round()}% • Isolation score: ${profile.isolationScore!.toStringAsFixed(2)} (0.50 = typical)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),

                    // Findings / Anomaly Details
                    if (profile.findings.isNotEmpty) ...[
                      ...profile.findings.map((f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  profile.isAnomalous
                                      ? Icons.warning_amber_rounded
                                      : Icons.info_outline,
                                  size: 16,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: profile.isAnomalous
                                            ? const Color(0xFF5D4037)
                                            : Colors.grey.shade700,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${f.title}: ',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(text: f.description),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '✅ Behavior aligns with expected baseline profile.',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF2D6A4F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
