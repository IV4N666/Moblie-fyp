import 'dart:math';

/// CVSS v3.1 base score calculator, following the equations in the FIRST
/// "CVSS v3.1 Specification Document" (https://www.first.org/cvss/).
///
/// The knowledge base stores only a CVSS vector per weakness; the score is
/// computed here, so every penalty in the app can be traced back to a
/// standard formula instead of a hand-picked number.
class CvssV31 {
  static const Map<String, double> _attackVector = {'N': 0.85, 'A': 0.62, 'L': 0.55, 'P': 0.2};
  static const Map<String, double> _attackComplexity = {'L': 0.77, 'H': 0.44};
  static const Map<String, double> _userInteraction = {'N': 0.85, 'R': 0.62};
  static const Map<String, double> _impact = {'H': 0.56, 'L': 0.22, 'N': 0.0};

  /// Base score (0.0–10.0) for a vector such as
  /// `AV:A/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`. Throws [FormatException] for an
  /// incomplete or invalid vector.
  static double baseScore(String vector) {
    final m = <String, String>{};
    for (final part in vector.split('/')) {
      final kv = part.split(':');
      if (kv.length == 2) m[kv[0]] = kv[1];
    }
    String need(String key) {
      final value = m[key];
      if (value == null) throw FormatException('CVSS vector is missing $key', vector);
      return value;
    }

    final scopeChanged = need('S') == 'C';
    final pr = need('PR');
    final privileges = pr == 'N'
        ? 0.85
        : pr == 'L'
            ? (scopeChanged ? 0.68 : 0.62)
            : (scopeChanged ? 0.5 : 0.27);

    final av = _attackVector[need('AV')];
    final ac = _attackComplexity[need('AC')];
    final ui = _userInteraction[need('UI')];
    final c = _impact[need('C')];
    final i = _impact[need('I')];
    final a = _impact[need('A')];
    if (av == null || ac == null || ui == null || c == null || i == null || a == null) {
      throw FormatException('Invalid CVSS v3.1 vector', vector);
    }

    final iss = 1 - (1 - c) * (1 - i) * (1 - a);
    final impact = scopeChanged
        ? 7.52 * (iss - 0.029) - 3.25 * pow(iss - 0.02, 15).toDouble()
        : 6.42 * iss;
    final exploitability = 8.22 * av * ac * privileges * ui;

    if (impact <= 0) return 0.0;
    final raw = scopeChanged
        ? min(1.08 * (impact + exploitability), 10.0)
        : min(impact + exploitability, 10.0);
    return roundUp(raw);
  }

  /// "Roundup" as defined in Appendix A of the CVSS v3.1 specification:
  /// the smallest number with one decimal place that is >= the input.
  static double roundUp(double value) {
    final intInput = (value * 100000).round();
    if (intInput % 10000 == 0) return intInput / 100000.0;
    return ((intInput ~/ 10000) + 1) / 10.0;
  }
}
