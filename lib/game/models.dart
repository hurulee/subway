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
  final String name;
  final List<Station> stations; // empty when loaded from a RouteData asset
  final int startIndex;
  final int endIndex;
  final double parTime;
  final List<SwitchPoint> switchPoints;
  final double expressSpeedMultiplier;
  final List<Obstacle> obstacles;
  final double platformHalfLen;
  final double cruiseSpeed;

  const Level({
    required this.name,
    this.stations = const [],
    required this.startIndex,
    required this.endIndex,
    required this.parTime,
    this.switchPoints = const [],
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
// Stations are loaded at runtime from assets/data/nyc/a_train.json
// (7 key stations: indices 0, 5, 9, 17, 22, 29, 36).
// startIndex / endIndex refer into the local-station list of that subset.

const gameLevels = [
  // ── Rounds 1–5: Short lines ───────────────────────────────────────────────
  Level(
    name: 'Round 1',
    startIndex: 0, endIndex: 6,
    parTime: 90,
    platformHalfLen: 178,
    cruiseSpeed: 120,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.56, track: TrackType.local),
    ],
  ),
  Level(
    name: 'Round 2',
    startIndex: 0, endIndex: 6,
    parTime: 80,
    platformHalfLen: 174,
    cruiseSpeed: 138,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
    ],
  ),
  Level(
    name: 'Round 3',
    startIndex: 0, endIndex: 6,
    parTime: 71,
    platformHalfLen: 170,
    cruiseSpeed: 155,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
      Obstacle(trackPosition: 0.84, track: TrackType.local),
    ],
  ),
  Level(
    name: 'Round 4',
    startIndex: 0, endIndex: 6,
    parTime: 63,
    platformHalfLen: 166,
    cruiseSpeed: 173,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
      Obstacle(trackPosition: 0.76, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),
  Level(
    name: 'Round 5',
    startIndex: 0, endIndex: 6,
    parTime: 55,
    platformHalfLen: 161,
    cruiseSpeed: 190,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
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
  Level(
    name: 'Round 6',
    startIndex: 0, endIndex: 6,
    parTime: 49,
    platformHalfLen: 157,
    cruiseSpeed: 208,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.65, track: TrackType.express),
      Obstacle(trackPosition: 0.78, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),
  Level(
    name: 'Round 7',
    startIndex: 0, endIndex: 6,
    parTime: 45,
    platformHalfLen: 153,
    cruiseSpeed: 223,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.43, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.78, track: TrackType.express),
      Obstacle(trackPosition: 0.92, track: TrackType.local),
    ],
  ),
  Level(
    name: 'Round 8',
    startIndex: 0, endIndex: 6,
    parTime: 41,
    platformHalfLen: 149,
    cruiseSpeed: 237,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.express),
      Obstacle(trackPosition: 0.35, track: TrackType.local),
      Obstacle(trackPosition: 0.57, track: TrackType.express),
      Obstacle(trackPosition: 0.78, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),
  Level(
    name: 'Round 9',
    startIndex: 0, endIndex: 6,
    parTime: 38,
    platformHalfLen: 145,
    cruiseSpeed: 250,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    obstacles: [
      Obstacle(trackPosition: 0.20, track: TrackType.local),
      Obstacle(trackPosition: 0.35, track: TrackType.express),
      Obstacle(trackPosition: 0.50, track: TrackType.local),
      Obstacle(trackPosition: 0.70, track: TrackType.express),
      Obstacle(trackPosition: 0.92, track: TrackType.local),
    ],
  ),
  Level(
    name: 'Round 10',
    startIndex: 0, endIndex: 6,
    parTime: 35,
    platformHalfLen: 141,
    cruiseSpeed: 262,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.70, windowSize: 0.05),
    ],
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
  Level(
    name: 'Round 11',
    startIndex: 0, endIndex: 6,
    parTime: 33,
    platformHalfLen: 137,
    cruiseSpeed: 272,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.70, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.85, windowSize: 0.04),
    ],
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
  Level(
    name: 'Round 12',
    startIndex: 0, endIndex: 6,
    parTime: 31,
    platformHalfLen: 133,
    cruiseSpeed: 281,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.70, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.85, windowSize: 0.04),
    ],
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
  Level(
    name: 'Round 13',
    startIndex: 0, endIndex: 6,
    parTime: 29,
    platformHalfLen: 128,
    cruiseSpeed: 290,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.70, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.85, windowSize: 0.04),
    ],
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
  Level(
    name: 'Round 14',
    startIndex: 0, endIndex: 6,
    parTime: 27,
    platformHalfLen: 124,
    cruiseSpeed: 298,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.70, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.85, windowSize: 0.04),
    ],
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
  Level(
    name: 'Round 15',
    startIndex: 0, endIndex: 6,
    parTime: 25,
    platformHalfLen: 120,
    cruiseSpeed: 305,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.25, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.40, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.70, windowSize: 0.04),
      SwitchPoint(trackPosition: 0.85, windowSize: 0.04),
    ],
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
