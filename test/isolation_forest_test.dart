import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_guardian_app/services/isolation_forest.dart';

void main() {
  test('c(n) matches the paper', () {
    expect(IsolationForest.averagePathLength(1), 0);
    expect(IsolationForest.averagePathLength(2), 1);
    // 2 * (ln 9 + 0.5772) - 2 * 9 / 10
    expect(IsolationForest.averagePathLength(10), closeTo(3.7489, 1e-3));
  });

  test('identical points get the neutral score 0.5', () {
    final forest = IsolationForest()..fit(List.generate(6, (_) => [0.0, 1.0, 0.0]));
    expect(forest.score([0.0, 1.0, 0.0]), closeTo(0.5, 1e-9));
  });

  test('a single different device is isolated', () {
    final data = [
      for (var i = 0; i < 9; i++) [0.0, 0.0, 0.0],
      [1.0, 1.0, 1.0],
    ];
    final forest = IsolationForest()..fit(data);
    // Any split separates the odd point immediately: path length 1.
    // s = 2^(-1 / c(10)) ≈ 0.831; the rest: 2^(-(1 + c(9)) / c(10)) ≈ 0.432
    expect(forest.score(data.last), closeTo(0.831, 0.01));
    expect(forest.score(data.first), closeTo(0.432, 0.01));
  });

  test('same seed gives the same result (reproducible demo)', () {
    final data = [
      [1.0, 0.0, 1.0], [0.0, 1.0, 0.0], [1.0, 1.0, 0.0],
      [0.0, 0.0, 1.0], [1.0, 0.0, 0.0],
    ];
    final a = IsolationForest(seed: 7)..fit(data);
    final b = IsolationForest(seed: 7)..fit(data);
    for (final row in data) {
      expect(a.score(row), b.score(row));
    }
  });
}
