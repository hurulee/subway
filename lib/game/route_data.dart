import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'models.dart';

/// A single station entry as read from a route JSON file.
class RouteStation {
  final String name;
  final int passengers;
  final String stopType; // 'local' or 'local_and_express'

  const RouteStation({
    required this.name,
    required this.passengers,
    required this.stopType,
  });

  bool get isExpressStop => stopType == 'local_and_express';
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

  /// Load a route from an asset JSON file.
  static Future<RouteData> load(String assetPath) async {
    final raw  = await rootBundle.loadString(assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return RouteData(
      system: data['system'] as String,
      line:   data['line']   as String,
      name:   data['name']   as String,
      stations: (data['stations'] as List).map((s) {
        return RouteStation(
          name:       s['name']       as String,
          passengers: s['passengers'] as int,
          stopType:   s['stop_type']  as String,
        );
      }).toList(),
    );
  }

  /// Select [indices] from the full station list and assign evenly-spaced
  /// track positions in [0.02, 0.98] by sequential order.
  /// Returns (localStations, expressStations).
  (List<Station>, List<Station>) subset(List<int> indices) {
    final sorted = [...indices]..sort();
    final n = sorted.length;
    final rng = Random();

    final local   = <Station>[];
    final express = <Station>[];

    for (int i = 0; i < n; i++) {
      final src = stations[sorted[i]];
      final pos = double.parse(
        (n > 1 ? 0.02 + i / (n - 1) * 0.96 : 0.5).toStringAsFixed(4),
      );
      final basePax = src.passengers > 0 ? src.passengers + 1 + rng.nextInt(5) : 0;
      final localPax = src.isExpressStop ? basePax : (basePax * 0.7).round();
      local.add(Station(
        name: src.name,
        passengers: localPax,
        trackPosition: pos,
        track: TrackType.local,
      ));
      if (src.isExpressStop) {
        final expressPax = (basePax * 1.8).round();
        express.add(Station(
          name: src.name,
          passengers: expressPax,
          trackPosition: pos,
          track: TrackType.express,
        ));
      }
    }

    return (local, express);
  }
}
