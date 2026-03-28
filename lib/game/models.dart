enum TrackType { local, express }
enum SignalColor { green, red }

class Station {
  final String name;
  final int passengers;
  final double trackPosition;
  final TrackType track;

  const Station({
    required this.name,
    required this.passengers,
    required this.trackPosition,
    this.track = TrackType.local,
  });
}

class SwitchPoint {
  final double trackPosition;
  final double windowSize;
  const SwitchPoint({required this.trackPosition, required this.windowSize});
}

class Obstacle {
  final double trackPosition;
  final TrackType track;
  const Obstacle({required this.trackPosition, required this.track});
}

class Level {
  final int startIndex;
  final double parTime;
  final double expressSpeedMultiplier;
  final List<Obstacle> obstacles;
  final double platformHalfLen;
  final double cruiseSpeed;

  const Level({
    required this.startIndex,
    required this.parTime,
    this.expressSpeedMultiplier = 1.0,
    this.obstacles = const [],
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
  Level(
    startIndex: 0,
    parTime: 90,
    platformHalfLen: 178,
    cruiseSpeed: 120,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.56, track: TrackType.local),
    ],
  ),

  // Level 2
  Level(
    startIndex: 0,
    parTime: 80,
    platformHalfLen: 174,
    cruiseSpeed: 138,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
    ],
  ),

  // Level 3
  Level(
    startIndex: 0,
    parTime: 71,
    platformHalfLen: 170,
    cruiseSpeed: 155,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
      Obstacle(trackPosition: 0.84, track: TrackType.local),
    ],
  ),

  // Level 4
  Level(
    startIndex: 0,
    parTime: 63,
    platformHalfLen: 166,
    cruiseSpeed: 173,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
      Obstacle(trackPosition: 0.76, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),

  // Level 5
  Level(
    startIndex: 0,
    parTime: 55,
    platformHalfLen: 161,
    cruiseSpeed: 190,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.50, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.78, track: TrackType.express),
      Obstacle(trackPosition: 0.92, track: TrackType.local),
    ],
  ),
  // ── Rounds 6–10: Medium lines ─────────────────────────────────────────────

  // Level 6
  Level(
    startIndex: 0,
    parTime: 49,
    platformHalfLen: 157,
    cruiseSpeed: 208,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.65, track: TrackType.express),
      Obstacle(trackPosition: 0.78, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),

  // Level 7
  Level(
    startIndex: 0,
    parTime: 45,
    platformHalfLen: 153,
    cruiseSpeed: 223,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.43, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.78, track: TrackType.express),
      Obstacle(trackPosition: 0.92, track: TrackType.local),
    ],
  ),

  // Level 8
  Level(
    startIndex: 0,
    parTime: 41,
    platformHalfLen: 149,
    cruiseSpeed: 237,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.express),
      Obstacle(trackPosition: 0.35, track: TrackType.local),
      Obstacle(trackPosition: 0.57, track: TrackType.express),
      Obstacle(trackPosition: 0.78, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),

  // Level 9
  Level(
    startIndex: 0,
    parTime: 38,
    platformHalfLen: 145,
    cruiseSpeed: 250,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.35, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.70, track: TrackType.express),
      Obstacle(trackPosition: 0.92, track: TrackType.local),
    ],
  ),

  // Level 10
  Level(
    startIndex: 0,
    parTime: 35,
    platformHalfLen: 141,
    cruiseSpeed: 262,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.express),
      Obstacle(trackPosition: 0.35, track: TrackType.local),
      Obstacle(trackPosition: 0.50, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.82, track: TrackType.express),
    ],
  ),
  // ── Rounds 11–15: Long lines ──────────────────────────────────────────────

  // Level 11
  Level(
    startIndex: 0,
    parTime: 33,
    platformHalfLen: 137,
    cruiseSpeed: 272,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.35, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.65, track: TrackType.express),
      Obstacle(trackPosition: 0.80, track: TrackType.local),
      Obstacle(trackPosition: 0.93, track: TrackType.express),
    ],
  ),

  // Level 12
  Level(
    startIndex: 0,
    parTime: 31,
    platformHalfLen: 133,
    cruiseSpeed: 281,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.express),
      Obstacle(trackPosition: 0.35, track: TrackType.local),
      Obstacle(trackPosition: 0.50, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.80, track: TrackType.express),
      Obstacle(trackPosition: 0.93, track: TrackType.local),
    ],
  ),

  // Level 13
  Level(
    startIndex: 0,
    parTime: 29,
    platformHalfLen: 128,
    cruiseSpeed: 290,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.35, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.65, track: TrackType.express),
      Obstacle(trackPosition: 0.80, track: TrackType.local),
      Obstacle(trackPosition: 0.93, track: TrackType.express),
    ],
  ),

  // Level 14
  Level(
    startIndex: 0,
    parTime: 27,
    platformHalfLen: 124,
    cruiseSpeed: 298,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.express),
      Obstacle(trackPosition: 0.35, track: TrackType.local),
      Obstacle(trackPosition: 0.50, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.80, track: TrackType.express),
      Obstacle(trackPosition: 0.93, track: TrackType.local),
    ],
  ),

  // Level 15
  Level(
    startIndex: 0,
    parTime: 25,
    platformHalfLen: 120,
    cruiseSpeed: 305,
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.35, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.65, track: TrackType.express),
      Obstacle(trackPosition: 0.80, track: TrackType.local),
      Obstacle(trackPosition: 0.93, track: TrackType.express),
    ],
  ),
];
