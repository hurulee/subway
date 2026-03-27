import 'dart:convert';
import 'package:flutter/services.dart';
import 'models.dart';

/// A single station entry as read from a route JSON file.
class RouteStation {
  final String name;
  final int passengers;
  final double trackPosition;
  final String stopType; // 'local' or 'local_and_express'

  const RouteStation({
    required this.name,
    required this.passengers,
    required this.trackPosition,
    required this.stopType,
  });

  bool get isExpressStop => stopType == 'local_and_express';

  Station toStation(TrackType track) => Station(
        name: name,
        passengers: passengers,
        trackPosition: trackPosition,
        track: track,
      );
}

/// A subway route loaded from a JSON asset file.
class RouteData {
  final String system;
  final String line;
  final String name;
  final List<RouteStation> stations;

  const RouteData({
    required this.system,
    required this.line,
    required this.name,
    required this.stations,
  });

  /// Load a route from an asset JSON file, e.g.
  /// `RouteData.load('assets/data/nyc/a_train.json')`.
  static Future<RouteData> load(String assetPath) async {
    final raw  = await rootBundle.loadString(assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return RouteData(
      system: data['system'] as String,
      line:   data['line']   as String,
      name:   data['name']   as String,
      stations: (data['stations'] as List).map((s) {
        return RouteStation(
          name:          s['name']           as String,
          passengers:    s['passengers']     as int,
          trackPosition: (s['track_position'] as num).toDouble(),
          stopType:      s['stop_type']      as String,
        );
      }).toList(),
    );
  }

  /// Return a new RouteData containing only the stations at [indices],
  /// preserving the order of [indices] (sorted ascending automatically).
  RouteData subset(List<int> indices) {
    final sorted = [...indices]..sort();
    final n      = sorted.length;
    if (n < 2) return this;

    // Re-map track positions linearly to [0.02, 0.98].
    final origPositions = sorted.map((i) => stations[i].trackPosition).toList();
    final origMin = origPositions.first;
    final origMax = origPositions.last;
    final origRange = origMax - origMin;

    final mapped = sorted.asMap().entries.map((e) {
      final src = stations[e.value];
      final normalised = origRange > 0
          ? 0.02 + (src.trackPosition - origMin) / origRange * 0.96
          : 0.02 + e.key / (n - 1) * 0.96;
      return RouteStation(
        name:          src.name,
        passengers:    src.passengers,
        trackPosition: double.parse(normalised.toStringAsFixed(4)),
        stopType:      src.stopType,
      );
    }).toList();

    return RouteData(system: system, line: line, name: name, stations: mapped);
  }

  /// Every station on the local track (all stations stop here).
  List<Station> get localStations =>
      stations.map((s) => s.toStation(TrackType.local)).toList();

  /// Only the express stations (local_and_express stop type).
  List<Station> get expressStations => stations
      .where((s) => s.isExpressStop)
      .map((s) => s.toStation(TrackType.express))
      .toList();

  /// Combined list in the format the game expects:
  /// local stations first, then express stations.
  List<Station> get allStations => [...localStations, ...expressStations];
}
