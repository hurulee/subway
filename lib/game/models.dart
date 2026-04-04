import 'dart:math';

enum TrackType { local, express }
enum SignalColor { green, red }

class Station {
  final String name;
  int passengers;
  final double trackPosition;
  final TrackType track;

  /// How many passengers will board at this stop (set on arrival based on
  /// stopping accuracy). Decremented one-by-one during boarding.
  int boardableCount = 0;

  /// Pre-computed random positions for each passenger figure.
  /// Each entry is (xFraction, yFraction) in [0, 1] relative to the
  /// platform's drawable area. Generated once so they don't jitter.
  late final List<(double, double)> figurePositions;

  /// Lambda for the exponential distribution on the x-axis (platform depth).
  /// Higher values cluster passengers closer to the track edge.
  static double kDepthLambda = 2.5;

  Station({
    required this.name,
    required this.passengers,
    required this.trackPosition,
    this.track = TrackType.local,
  }) {
    final rng = Random();
    figurePositions = List.generate(passengers, (_) => (
      _expSample(rng, kDepthLambda),
      rng.nextDouble(),
    ));
  }

  /// Sample from an exponential distribution mapped to [0, 1].
  /// Uses inverse CDF with lambda controlling skew: higher lambda = more
  /// passengers clustered near x=0 (the track-side edge).
  static double _expSample(Random rng, double lambda) {
    if (lambda <= 0) return rng.nextDouble();
    // Inverse CDF: x = -ln(1-u) / lambda, then divide by a cutoff to
    // map into [0,1]. We use the 99th percentile as the cutoff so most
    // values land in range, with a clamp for the rare outlier.
    final cutoff = -log(0.01) / lambda; // ≈ 4.6 / lambda
    final u = rng.nextDouble();
    final raw = -log(1 - u) / lambda;
    return (raw / cutoff).clamp(0.0, 1.0);
  }
}

class SwitchPoint {
  final double trackPosition;
  final double windowSize;
  const SwitchPoint({required this.trackPosition, required this.windowSize});
}

class BoardingAnim {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  double progress = 0.0;
  bool counted = false; // true once this passenger has been added to the counter

  /// Walking speed in pixels per second.
  static const double walkSpeed = 40.0;

  /// Duration is based on distance so each passenger walks at the same speed.
  late final double duration;

  BoardingAnim({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  }) {
    final dx = endX - startX;
    final dy = endY - startY;
    final dist = sqrt(dx * dx + dy * dy);
    duration = (dist / walkSpeed).clamp(0.3, 5.0);
  }

  bool get done => progress >= 1.0;

  double get x => startX + (endX - startX) * _ease(progress);
  double get y => startY + (endY - startY) * _ease(progress);

  static double _ease(double t) => t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2;
}

class Obstacle {
  final double trackPosition;
  final TrackType track;
  const Obstacle({required this.trackPosition, required this.track});
}

class Bend {
  final double startT;
  final double endT;
  final int direction; // 1 = left, -1 = right
  const Bend({required this.startT, required this.endT, required this.direction});
}

class Level {
  final int startIndex;
  final double parTime;
  final double expressSpeedMultiplier;
  final double platformHalfLen;
  final double cruiseSpeed;

  const Level({
    required this.startIndex,
    required this.parTime,
    this.expressSpeedMultiplier = 1.0,
    this.platformHalfLen = 130.0,
    this.cruiseSpeed = 160.0,
  });
}

class HudData {
  final int passengers;
  final double elapsed;
  final String nextStation;
  final int passengerScore;
  final int timeBonus;
  final TrackType currentTrack;
  final SignalColor localSignal;
  final SignalColor expressSignal;
  final int penaltyCount;
  final int level;
  final int lives;
  final int maxLives;

  const HudData({
    required this.passengers,
    required this.elapsed,
    required this.nextStation,
    this.passengerScore = 0,
    this.timeBonus = 0,
    this.currentTrack = TrackType.local,
    this.localSignal = SignalColor.green,
    this.expressSignal = SignalColor.green,
    this.penaltyCount = 0,
    this.level = 1,
    this.lives = 3,
    this.maxLives = 3,
  });

  int get penaltyDeduction => penaltyCount * 50;
  int get totalScore =>
      (passengerScore + timeBonus - penaltyDeduction).clamp(0, 999999);
}

// ── Level definitions ─────────────────────────────────────────────────────────
//
// Rounds  Line group  Stations  Lines
// 1–5     Short       15        7, E, G, L, W, Z
// 6–10    Medium      20        3, 4, 5, D, J, M, N, Q
// 11–15   Long        25        1, 2, 6, A, B, C, F, R

const gameLevels = [
  // ── Rounds 1–5: Short lines ───────────────────────────────────────────────

  // Level 1
  Level(startIndex: 0, parTime: 90,  platformHalfLen: 178, cruiseSpeed: 120,  expressSpeedMultiplier: 1.35),

  // Level 2
  Level(startIndex: 0, parTime: 80,  platformHalfLen: 174, cruiseSpeed: 138,  expressSpeedMultiplier: 1.35),

  // Level 3
  Level(startIndex: 0, parTime: 71,  platformHalfLen: 170, cruiseSpeed: 155,  expressSpeedMultiplier: 1.35),

  // Level 4
  Level(startIndex: 0, parTime: 63,  platformHalfLen: 166, cruiseSpeed: 173,  expressSpeedMultiplier: 1.35),

  // Level 5
  Level(startIndex: 0, parTime: 55,  platformHalfLen: 161, cruiseSpeed: 190,  expressSpeedMultiplier: 1.35),

  // ── Rounds 6–10: Medium lines ─────────────────────────────────────────────

  // Level 6
  Level(startIndex: 0, parTime: 49,  platformHalfLen: 157, cruiseSpeed: 208,  expressSpeedMultiplier: 1.35),

  // Level 7
  Level(startIndex: 0, parTime: 45,  platformHalfLen: 153, cruiseSpeed: 223,  expressSpeedMultiplier: 1.35),

  // Level 8
  Level(startIndex: 0, parTime: 41,  platformHalfLen: 149, cruiseSpeed: 237,  expressSpeedMultiplier: 1.35),

  // Level 9
  Level(startIndex: 0, parTime: 38,  platformHalfLen: 145, cruiseSpeed: 250,  expressSpeedMultiplier: 1.35),

  // Level 10
  Level(startIndex: 0, parTime: 35,  platformHalfLen: 141, cruiseSpeed: 262,  expressSpeedMultiplier: 1.35),

  // ── Rounds 11–15: Long lines ──────────────────────────────────────────────

  // Level 11
  Level(startIndex: 0, parTime: 33,  platformHalfLen: 137, cruiseSpeed: 272,  expressSpeedMultiplier: 1.35),

  // Level 12
  Level(startIndex: 0, parTime: 31,  platformHalfLen: 133, cruiseSpeed: 281,  expressSpeedMultiplier: 1.35),

  // Level 13
  Level(startIndex: 0, parTime: 29,  platformHalfLen: 128, cruiseSpeed: 290,  expressSpeedMultiplier: 1.35),

  // Level 14
  Level(startIndex: 0, parTime: 27,  platformHalfLen: 124, cruiseSpeed: 298,  expressSpeedMultiplier: 1.35),

  // Level 15
  Level(startIndex: 0, parTime: 25,  platformHalfLen: 120, cruiseSpeed: 305,  expressSpeedMultiplier: 1.35),
];
