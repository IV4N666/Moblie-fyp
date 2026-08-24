import 'package:flutter/material.dart';

class ScoreGauge extends StatelessWidget {
  final int score;
  final double size;

  const ScoreGauge({
    super.key,
    required this.score,
    this.size = 180,
  });

  Color _getScoreColor(int s) {
    if (s >= 85) return const Color(0xFF2E7D32); // Deep Green
    if (s >= 70) return const Color(0xFF689F38); // Light Green
    if (s >= 50) return const Color(0xFFF57C00); // Orange
    return const Color(0xFFD32F2F);              // Red
  }

  String _getScoreLabel(int s) {
    if (s >= 85) return 'Protected & Safe';
    if (s >= 70) return 'Minor Tweaks';
    if (s >= 50) return 'Needs Attention';
    return 'Action Required';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);
    final label = _getScoreLabel(score);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 14,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
            ),
          ),
          // Score progress arc
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: score / 100.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              );
            },
          ),
          // Inner score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
              ),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: size * 0.09,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: size * 0.075,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
