import 'dart:math';

/// Isolation Forest (Liu, Ting & Zhou, ICDM 2008).
///
/// Unsupervised: it needs no labelled "good" or "bad" examples. Each tree
/// isolates points with random splits; points that get isolated after only
/// a few splits are unusual compared with the rest of the data.
///
/// The anomaly score is s(x) = 2^(-E[h(x)] / c(n)), where E[h(x)] is the
/// average path length over all trees and c(n) the expected path length of
/// an unsuccessful binary-search-tree lookup on n points.
///   s close to 1   -> clear anomaly
///   s around 0.5   -> no distinct anomaly in the data
///   s well below 0.5 -> normal (part of a dense group)
///
/// A fixed [seed] makes results reproducible, which matters for a report
/// and a live demo: the same network always gets the same scores.
class IsolationForest {
  final int numTrees;
  final int maxSamples;
  final int seed;

  final List<_Node> _trees = [];
  int _sampleSize = 0;

  IsolationForest({this.numTrees = 100, this.maxSamples = 256, this.seed = 42});

  void fit(List<List<double>> data) {
    _trees.clear();
    if (data.isEmpty) return;

    final rng = Random(seed);
    _sampleSize = min(maxSamples, data.length);
    final heightLimit = (log(max(_sampleSize, 2)) / ln2).ceil();

    for (var t = 0; t < numTrees; t++) {
      final sample = List<List<double>>.of(data)..shuffle(rng);
      _trees.add(_build(sample.sublist(0, _sampleSize), 0, heightLimit, rng));
    }
  }

  double score(List<double> x) {
    if (_trees.isEmpty) return 0.5;
    var total = 0.0;
    for (final tree in _trees) {
      total += _pathLength(x, tree, 0);
    }
    final c = averagePathLength(_sampleSize);
    if (c <= 0) return 0.5;
    return pow(2, -(total / _trees.length) / c).toDouble();
  }

  /// c(n): average path length of an unsuccessful search in a BST of n nodes.
  static double averagePathLength(int n) {
    if (n <= 1) return 0;
    if (n == 2) return 1;
    const eulerGamma = 0.5772156649;
    final harmonic = log(n - 1) + eulerGamma;
    return 2 * harmonic - 2 * (n - 1) / n;
  }

  _Node _build(List<List<double>> rows, int depth, int limit, Random rng) {
    if (depth >= limit || rows.length <= 1) return _Node.leaf(rows.length);

    // Only features that still vary inside this node can split it
    // (same approach as scikit-learn).
    final dims = rows.first.length;
    final candidates = <int>[];
    for (var f = 0; f < dims; f++) {
      final first = rows.first[f];
      if (rows.any((r) => r[f] != first)) candidates.add(f);
    }
    if (candidates.isEmpty) return _Node.leaf(rows.length);

    final feature = candidates[rng.nextInt(candidates.length)];
    var lo = rows.first[feature];
    var hi = lo;
    for (final r in rows) {
      if (r[feature] < lo) lo = r[feature];
      if (r[feature] > hi) hi = r[feature];
    }
    var split = lo + rng.nextDouble() * (hi - lo);
    if (split <= lo) split = (lo + hi) / 2;

    final left = rows.where((r) => r[feature] < split).toList();
    final right = rows.where((r) => r[feature] >= split).toList();

    return _Node.split(
      feature,
      split,
      _build(left, depth + 1, limit, rng),
      _build(right, depth + 1, limit, rng),
    );
  }

  double _pathLength(List<double> x, _Node node, int depth) {
    if (node.isLeaf) return depth + averagePathLength(node.size);
    return x[node.feature] < node.threshold
        ? _pathLength(x, node.left!, depth + 1)
        : _pathLength(x, node.right!, depth + 1);
  }
}

class _Node {
  final int feature;
  final double threshold;
  final _Node? left;
  final _Node? right;
  final int size;

  _Node.leaf(this.size)
      : feature = -1,
        threshold = 0,
        left = null,
        right = null;

  _Node.split(this.feature, this.threshold, this.left, this.right) : size = 0;

  bool get isLeaf => left == null;
}
