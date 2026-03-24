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
  final List<Station> stations;
  final int startIndex;
  final int endIndex;
  final double parTime;
  final List<SwitchPoint> switchPoints;
  final double expressSpeedMultiplier;
  final List<Obstacle> obstacles;

  const Level({
    required this.name,
    required this.stations,
    required this.startIndex,
    required this.endIndex,
    required this.parTime,
    this.switchPoints = const [],
    this.expressSpeedMultiplier = 1.0,
    this.obstacles = const [],
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
  });

  int get penaltyDeduction => penaltyCount * 50;
  int get totalScore =>
      (passengerScore + timeBonus - penaltyDeduction).clamp(0, 999999);
}

final gameLevel = Level(
  name: 'A Train — Far Rockaway to Jay St',
  stations: const [
    // ── Local track ──────────────────────────────────────────────────────────
    Station(name: 'Far Rockaway',  passengers: 0,  trackPosition: 0.04, track: TrackType.local),
    Station(name: 'Mott Ave',      passengers: 8,  trackPosition: 0.18, track: TrackType.local),
    Station(name: 'Beach 25 St',   passengers: 14, trackPosition: 0.32, track: TrackType.local),
    Station(name: 'Howard Beach',  passengers: 10, trackPosition: 0.48, track: TrackType.local),
    Station(name: 'Broad Channel', passengers: 18, trackPosition: 0.64, track: TrackType.local),
    Station(name: 'Rockaway Blvd', passengers: 12, trackPosition: 0.78, track: TrackType.local),
    Station(name: 'Jay St',        passengers: 0,  trackPosition: 0.94, track: TrackType.local),
    // ── Express track ────────────────────────────────────────────────────────
    Station(name: 'Far Rockaway',  passengers: 0,  trackPosition: 0.04, track: TrackType.express),
    Station(name: 'Howard Beach',  passengers: 20, trackPosition: 0.48, track: TrackType.express),
    Station(name: 'Broad Channel', passengers: 28, trackPosition: 0.64, track: TrackType.express),
    Station(name: 'Jay St',        passengers: 0,  trackPosition: 0.94, track: TrackType.express),
  ],
  startIndex: 0,
  endIndex: 6,
  parTime: 65.0,
  switchPoints: const [
    SwitchPoint(trackPosition: 0.10, windowSize: 0.06), // after Far Rockaway
    SwitchPoint(trackPosition: 0.38, windowSize: 0.06), // before Howard Beach
    SwitchPoint(trackPosition: 0.68, windowSize: 0.06), // after Broad Channel
  ],
  expressSpeedMultiplier: 1.35,
  // One obstacle per segment, always on different tracks so at least one is safe.
  // Segment 1 (0.16–0.38): obstacle on local  → signals: local=RED,    express=GREEN
  // Segment 2 (0.44–0.68): obstacle on express → signals: local=GREEN, express=RED
  // Segment 3 (0.74–0.94): obstacle on local  → signals: local=RED,    express=GREEN
  obstacles: const [
    Obstacle(trackPosition: 0.27, track: TrackType.local),
    Obstacle(trackPosition: 0.56, track: TrackType.express),
    Obstacle(trackPosition: 0.84, track: TrackType.local),
  ],
);
