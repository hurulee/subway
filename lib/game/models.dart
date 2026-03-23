enum TrackType { local, express }

class Station {
  final String name;
  final int passengers;
  final double trackPosition; // 0.0 – 1.0 along the track
  final TrackType track;

  const Station({
    required this.name,
    required this.passengers,
    required this.trackPosition,
    this.track = TrackType.local,
  });
}

class SwitchPoint {
  final double trackPosition; // trackT where the switch window opens
  final double windowSize;    // trackT range the button stays active
  const SwitchPoint({required this.trackPosition, required this.windowSize});
}

class Level {
  final String name;
  final List<Station> stations;
  final int startIndex;
  final int endIndex;
  final double parTime;
  final List<SwitchPoint> switchPoints;
  final double expressSpeedMultiplier;

  const Level({
    required this.name,
    required this.stations,
    required this.startIndex,
    required this.endIndex,
    required this.parTime,
    this.switchPoints = const [],
    this.expressSpeedMultiplier = 1.0,
  });
}

class HudData {
  final int passengers;
  final double elapsed;
  final String nextStation;
  final int passengerScore;
  final int timeBonus;
  final TrackType currentTrack;

  const HudData({
    required this.passengers,
    required this.elapsed,
    required this.nextStation,
    this.passengerScore = 0,
    this.timeBonus = 0,
    this.currentTrack = TrackType.local,
  });

  int get totalScore => passengerScore + timeBonus;
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
);
