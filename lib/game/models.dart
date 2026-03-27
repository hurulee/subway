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
  // ── Level 1 — intro ──────────────────────────────────────────────────────
  Level(
    name: 'A Train — Inwood to Far Rockaway',
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
    // Segment 2 only: local=RED, express=GREEN
    obstacles: [
      Obstacle(trackPosition: 0.56, track: TrackType.local),
    ],
  ),
  // ── Level 2 ──────────────────────────────────────────────────────────────
  Level(
    name: 'A Train — Inwood to Far Rockaway',
    startIndex: 0, endIndex: 6,
    parTime: 78,
    platformHalfLen: 163,
    cruiseSpeed: 145,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
    ],
    expressSpeedMultiplier: 1.35,
    // Seg 1: local=RED   Seg 3: express=RED
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.84, track: TrackType.express),
    ],
  ),
  // ── Level 3 ──────────────────────────────────────────────────────────────
  Level(
    name: 'A Train — Inwood to Far Rockaway',
    startIndex: 0, endIndex: 6,
    parTime: 68,
    platformHalfLen: 148,
    cruiseSpeed: 165,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
    ],
    expressSpeedMultiplier: 1.35,
    // Seg 1: local=RED   Seg 2: express=RED   Seg 3: local=RED
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
      Obstacle(trackPosition: 0.84, track: TrackType.local),
    ],
  ),
  // ── Level 4 — adds 4th switch point ──────────────────────────────────────
  Level(
    name: 'A Train — Inwood to Far Rockaway',
    startIndex: 0, endIndex: 6,
    parTime: 60,
    platformHalfLen: 134,
    cruiseSpeed: 190,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    // Seg 1: local=RED   Seg 2: express=RED   Seg 3: local=RED   Seg 4: express=RED
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.56, track: TrackType.express),
      Obstacle(trackPosition: 0.76, track: TrackType.local),
      Obstacle(trackPosition: 0.92, track: TrackType.express),
    ],
  ),
  // ── Level 5 — adds 5th switch point ──────────────────────────────────────
  Level(
    name: 'A Train — Inwood to Far Rockaway',
    startIndex: 0, endIndex: 6,
    parTime: 52,
    platformHalfLen: 119,
    cruiseSpeed: 215,
    switchPoints: [
      SwitchPoint(trackPosition: 0.10, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.38, windowSize: 0.06),
      SwitchPoint(trackPosition: 0.55, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.68, windowSize: 0.05),
      SwitchPoint(trackPosition: 0.82, windowSize: 0.05),
    ],
    expressSpeedMultiplier: 1.35,
    // All 5 segments have obstacles, alternating tracks
    obstacles: [
      Obstacle(trackPosition: 0.27, track: TrackType.local),
      Obstacle(trackPosition: 0.50, track: TrackType.express),
      Obstacle(trackPosition: 0.65, track: TrackType.local),
      Obstacle(trackPosition: 0.78, track: TrackType.express),
      Obstacle(trackPosition: 0.92, track: TrackType.local),
    ],
  ),
];
