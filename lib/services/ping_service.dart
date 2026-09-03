import 'dart:async';
import 'dart:io';
import 'dart:math';

class PingSample {
  final int sequence;
  final int latencyMs;
  final bool isSuccess;
  final String status;
  final DateTime timestamp;

  const PingSample({
    required this.sequence,
    required this.latencyMs,
    required this.isSuccess,
    required this.status,
    required this.timestamp,
  });
}

class PingStatistics {
  final int transmitted;
  final int received;
  final int minLatencyMs;
  final int maxLatencyMs;
  final double avgLatencyMs;
  final double jitterMs; // Mean absolute deviation between consecutive packets
  final double packetLossRate;

  const PingStatistics({
    required this.transmitted,
    required this.received,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.avgLatencyMs,
    required this.jitterMs,
    required this.packetLossRate,
  });

  static PingStatistics calculate(List<PingSample> samples) {
    if (samples.isEmpty) {
      return const PingStatistics(
        transmitted: 0,
        received: 0,
        minLatencyMs: 0,
        maxLatencyMs: 0,
        avgLatencyMs: 0.0,
        jitterMs: 0.0,
        packetLossRate: 0.0,
      );
    }

    final transmitted = samples.length;
    final successful = samples.where((s) => s.isSuccess).toList();
    final received = successful.length;

    if (received == 0) {
      return PingStatistics(
        transmitted: transmitted,
        received: 0,
        minLatencyMs: 0,
        maxLatencyMs: 0,
        avgLatencyMs: 0.0,
        jitterMs: 0.0,
        packetLossRate: 100.0,
      );
    }

    int minLat = successful.first.latencyMs;
    int maxLat = successful.first.latencyMs;
    int sum = 0;

    for (final s in successful) {
      if (s.latencyMs < minLat) minLat = s.latencyMs;
      if (s.latencyMs > maxLat) maxLat = s.latencyMs;
      sum += s.latencyMs;
    }

    final avg = sum / received;

    // Calculate Jitter (RFC 3550 standard calculation)
    double jitter = 0.0;
    if (successful.length > 1) {
      double diffSum = 0.0;
      for (int i = 1; i < successful.length; i++) {
        diffSum += (successful[i].latencyMs - successful[i - 1].latencyMs).abs();
      }
      jitter = diffSum / (successful.length - 1);
    }

    final lossRate = ((transmitted - received) / transmitted) * 100.0;

    return PingStatistics(
      transmitted: transmitted,
      received: received,
      minLatencyMs: minLat,
      maxLatencyMs: maxLat,
      avgLatencyMs: double.parse(avg.toStringAsFixed(1)),
      jitterMs: double.parse(jitter.toStringAsFixed(1)),
      packetLossRate: double.parse(lossRate.toStringAsFixed(1)),
    );
  }
}

class PingDiagnosticService {
  /// Measures socket round-trip time to target host and preferred port
  static Future<PingSample> singleProbe({
    required String host,
    int port = 80,
    required int sequence,
    int timeoutMs = 1000,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      sw.stop();
      socket.destroy();
      return PingSample(
        sequence: sequence,
        latencyMs: sw.elapsedMilliseconds,
        isSuccess: true,
        status: 'Connected (${sw.elapsedMilliseconds} ms)',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      sw.stop();
      // If port is closed, check if connection was actively rejected (which still proves host is alive)
      final err = e.toString();
      final isRst = err.contains('refused') || err.contains('reset');
      if (isRst && sw.elapsedMilliseconds < timeoutMs) {
        return PingSample(
          sequence: sequence,
          latencyMs: max(1, sw.elapsedMilliseconds),
          isSuccess: true,
          status: 'Host Responded RST (${sw.elapsedMilliseconds} ms)',
          timestamp: DateTime.now(),
        );
      }
      return PingSample(
        sequence: sequence,
        latencyMs: timeoutMs,
        isSuccess: false,
        status: 'Timeout / Unreachable',
        timestamp: DateTime.now(),
      );
    }
  }
}
