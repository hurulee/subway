class Station {
  final String name;
  final int passengers; // waiting passengers
  final double trackPosition; // 0.0 - 1.0 along the track

  const Station({
    required this.name,
    required this.passengers,
    required this.trackPosition,
  });
}

class Level {
  final String name;
  final List<Station> stations;
  final int startIndex;
  final int endIndex;

  const Level({
    required this.name,
    required this.stations,
    required this.startIndex,
    required this.endIndex,
  });
}

class HudData {
  final int passengers;
  final double elapsed;
  final String nextStation;

  const HudData({
    required this.passengers,
    required this.elapsed,
    required this.nextStation,
  });
}

// NYC-inspired A line subset
final level1 = Level(
  name: 'A Train — Howard Beach to Jay St',
  stations: const [
    Station(name: 'Howard Beach', passengers: 0, trackPosition: 0.05),
    Station(name: 'Broad Channel', passengers: 12, trackPosition: 0.22),
    Station(name: 'Far Rockaway', passengers: 0, trackPosition: 0.0),
    // reordered for linear travel:
  ],
  startIndex: 0,
  endIndex: 4,
);

// Use this as the actual level data
final gameLevel = Level(
  name: 'A Train — Far Rockaway to Jay St',
  stations: const [
    Station(name: 'Far Rockaway', passengers: 0, trackPosition: 0.04),
    Station(name: 'Mott Ave', passengers: 8, trackPosition: 0.18),
    Station(name: 'Beach 25 St', passengers: 14, trackPosition: 0.32),
    Station(name: 'Howard Beach', passengers: 10, trackPosition: 0.48),
    Station(name: 'Broad Channel', passengers: 18, trackPosition: 0.64),
    Station(name: 'Rockaway Blvd', passengers: 12, trackPosition: 0.78),
    Station(name: 'Jay St', passengers: 0, trackPosition: 0.94),
  ],
  startIndex: 0,
  endIndex: 6,
);
