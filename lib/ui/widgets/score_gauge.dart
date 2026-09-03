import 'package:flutter/material.dart';
import '../../models/security_model.dart';

class ScoreGauge extends StatelessWidget {
  final int score;
  final double size;

  const ScoreGauge({
    super.key,
    required this.score,
    this.size = 180,
  });

  Color _getScoreColor(int s) {
    if (s >= 90) return const Color(0xFF2D6A4F); // Soft Forest Green
    if (s >= 75) return const Color(0xFF52796F); // Gentle Muted Sage
    if (s >= 60) return const Color(0xFFC88A2E); // Warm Honey Amber
    if (s >= 40) return const Color(0xFFD97706); // Warm Terracotta Cinnamon
    return const Color(0xFFC53030);              // Soft Brick Rose
  }

  Color _getScoreBgColor(int s) {
    if (s >= 90) return const Color(0xFFE8F5E9);
    if (s >= 75) return const Color(0xFFE0F2F1);
    if (s >= 60) return const Color(0xFFFFF8E1);
    if (s >= 40) return const Color(0xFFFFF3E0);
    return const Color(0xFFFFEBEE);
  }

  String _getScoreLabel(int s) {
    final tier = SecurityTierExtension.fromScore(s);
    return tier.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);
    final bgColor = _getScoreBgColor(score);
    final label = _getScoreLabel(score);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft track
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEFEBE9)),
            ),
          ),
          // Score progress arc with smooth rounded cap
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: score / 100.0),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              );
            },
          ),
          // Inner score display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4E342E), // Warm deep mocha
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
              Text(
                'out of 100',
                style: TextStyle(
                  fontSize: size * 0.075,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8D6E63), // Soft warm brown
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3), width: 1.2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: size * 0.07,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.4,
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
