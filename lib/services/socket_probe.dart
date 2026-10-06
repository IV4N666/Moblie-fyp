import 'dart:async';
import 'dart:io';

/// Outcome of a single TCP connect attempt.
///
/// The key insight for host discovery: a *closed* port still proves the host
/// exists, because the host's TCP stack actively answers with a RST
/// ("connection refused"). Only a *filtered* result (timeout / unreachable)
/// tells us nothing.
enum PortState { open, closed, filtered }

class ProbeResult {
  final int port;
  final PortState state;
  final int elapsedMs;

  const ProbeResult(this.port, this.state, this.elapsedMs);

  /// True when the remote host answered at all (open or actively refused).
  bool get hostAnswered => state != PortState.filtered;
}

class SocketProbe {
  // errno values meaning "the host answered with a RST".
  // Linux / Android: ECONNREFUSED = 111, ECONNRESET = 104
  // iOS / macOS (BSD): ECONNREFUSED = 61, ECONNRESET = 54
  // Windows (WSA):    WSAECONNREFUSED = 10061, WSAECONNRESET = 10054
  static const Set<int> _refusedErrnos = {111, 104, 61, 54, 10061, 10054};

  /// Attempts a TCP connection and classifies the result.
  static Future<ProbeResult> probe(String ip, int port, Duration timeout) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: timeout);
      return ProbeResult(port, PortState.open, sw.elapsedMilliseconds);
    } on SocketException catch (e) {
      final state = isRefused(e) ? PortState.closed : PortState.filtered;
      return ProbeResult(port, state, sw.elapsedMilliseconds);
    } catch (_) {
      return ProbeResult(port, PortState.filtered, sw.elapsedMilliseconds);
    } finally {
      socket?.destroy();
    }
  }

  /// Whether a [SocketException] was caused by an active refusal/reset
  /// (host alive) rather than a timeout or unreachable route.
  static bool isRefused(SocketException e) {
    final code = e.osError?.errorCode;
    if (code != null && _refusedErrnos.contains(code)) return true;
    final msg = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    return msg.contains('refused') || msg.contains('reset by peer');
  }
}
