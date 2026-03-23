import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'train_component.dart';
import 'map_component.dart';

class SubwayGame extends FlameGame {
  final ValueNotifier<HudData> hudNotifier =
      ValueNotifier(const HudData(passengers: 0, elapsed: 0, nextStation: ''));
  final ValueNotifier<bool> brakingNotifier = ValueNotifier(false);

  int _passengers = 0;
  double _elapsed = 0.0;
  bool _levelDone = false;

  // Plain Dart objects — rendered manually, no Flame component tree
  late TrainComponent _train;
  late MapComponent _map;

  final Level level = gameLevel;
  int _nextStationIndex = 1;
  bool _stoppedAtStation = false;
  double _stopTimer = 0.0;
  static const double stopDuration = 2.0;
  double _startupDelay = 0.9;

  static const double cruiseSpeed = 180.0;
  static const double perfectZone = 14.0;
  static const double goodZone = 36.0;

  // Train sits at 68% down the screen so 68% is visible track ahead
  static const double trainScreenFraction = 0.68;

  @override
  Future<void> onLoad() async {
    _map = MapComponent(stations: level.stations);
    _train = TrainComponent();
    _train.trackT = level.stations[level.startIndex].trackPosition;
  }

  double _worldYForT(double t) => kTrackBottomY - t * kTrackLength;

  @override
  void update(double dt) {
    super.update(dt);
    if (_levelDone) return;

    if (_startupDelay > 0) {
      _startupDelay -= dt;
      return;
    }
    _elapsed += dt;
    _train.isBraking = brakingNotifier.value;
    _train.targetSpeed = (_stoppedAtStation || brakingNotifier.value) ? 0.0 : cruiseSpeed;
    _train.update(dt);

    if (_stoppedAtStation) {
      _stopTimer += dt;
      final earlyDepart = !brakingNotifier.value && _stopTimer >= 0.5;
      if (earlyDepart || _stopTimer >= stopDuration) {
        _stoppedAtStation = false;
        _stopTimer = 0;
        _nextStationIndex++;
        if (_nextStationIndex >= level.stations.length) {
          _finishLevel();
          return;
        }
      }
    } else {
      _train.trackT += (_train.speed * dt) / kTrackLength;
      _train.trackT = _train.trackT.clamp(0.0, 1.0);
      _checkArrival();
    }

    if (!_levelDone) _updateHud();
  }

  void _checkArrival() {
    if (_nextStationIndex >= level.stations.length) return;
    final targetY = _worldYForT(level.stations[_nextStationIndex].trackPosition);
    final trainY = _worldYForT(_train.trackT);
    final distPx = trainY - targetY; // positive = train still below station

    if (_train.speed < 8 && distPx < goodZone * 2) {
      // Train slowed to a stop near the station — board passengers
      _arriveAtStation(_nextStationIndex);
    } else if (distPx < -goodZone) {
      // Blew past the station at speed — miss it, keep going
      _missStation(_nextStationIndex);
    }
  }

  void _arriveAtStation(int idx) {
    final station = level.stations[idx];

    if (station.passengers > 0) {
      final distPx =
          (_worldYForT(_train.trackT) - _worldYForT(station.trackPosition)).abs();
      int boarded;
      if (distPx <= perfectZone) {
        boarded = station.passengers;
      } else if (distPx <= goodZone) {
        boarded = (station.passengers * 0.6).round();
      } else {
        boarded = (station.passengers * 0.25).round();
      }
      _passengers += boarded;
    }

    _train.speed = 0;
    _stoppedAtStation = true;
  }

  void _missStation(int idx) {
    // No stop, no passengers — advance to next target
    _nextStationIndex = idx + 1;
    if (_nextStationIndex >= level.stations.length) {
      _finishLevel();
    }
  }

  void _finishLevel() {
    _levelDone = true;
    final passengerScore = _passengers * 10;
    final timeBonus = ((level.parTime - _elapsed) * 10).round().clamp(0, 999999);
    hudNotifier.value = HudData(
      passengers: _passengers,
      elapsed: _elapsed,
      nextStation: '',
      passengerScore: passengerScore,
      timeBonus: timeBonus,
    );
    overlays.add('levelComplete');
    overlays.remove('brake');
  }

  void _updateHud() {
    final nextName = _nextStationIndex < level.stations.length
        ? level.stations[_nextStationIndex].name
        : '';
    hudNotifier.value = HudData(
        passengers: _passengers, elapsed: _elapsed, nextStation: nextName);
  }

  void setBraking(bool braking) {
    if (_levelDone) return;
    brakingNotifier.value = braking;
  }

  void restartLevel() {
    overlays.remove('levelComplete');
    overlays.add('brake');
    _passengers = 0;
    _elapsed = 0;
    _levelDone = false;
    _nextStationIndex = 1;
    _stoppedAtStation = false;
    _stopTimer = 0;
    _train.trackT = level.stations[level.startIndex].trackPosition;
    _train.speed = 0;
    brakingNotifier.value = false;
    hudNotifier.value =
        const HudData(passengers: 0, elapsed: 0, nextStation: '');
    _startupDelay = 0.9;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); // Flame internals (overlays etc.)

    final trainWorldY = _worldYForT(_train.trackT);
    // scrollY = world Y that maps to screen top
    final scrollY = trainWorldY - size.y * trainScreenFraction;

    // ── Background (screen space) ──────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF111111),
    );
    // Left tunnel wall
    canvas.drawRect(
      Rect.fromLTWH(0, 0, kTrackX - 20, size.y),
      Paint()..color = const Color(0xFF1C1C1C),
    );

    // ── World space ────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(0, -scrollY);

    _map.render(canvas);

    // Train: top-left of bounding box
    final trainLeft = kTrackX - TrainComponent.w / 2;
    final trainTop = trainWorldY - TrainComponent.h / 2;
    canvas.save();
    canvas.translate(trainLeft, trainTop);
    _train.render(canvas);
    canvas.restore();

    canvas.restore();
    // ── Screen-space overlays ──────────────────────────────────────────────
    _renderApproachBar(canvas);
    _renderSpeedIndicator(canvas);
  }

  void _renderApproachBar(Canvas canvas) {
    if (_stoppedAtStation || _levelDone) return;
    if (_nextStationIndex >= level.stations.length) return;

    final targetY =
        _worldYForT(level.stations[_nextStationIndex].trackPosition);
    final trainY = _worldYForT(_train.trackT);
    final distPx = trainY - targetY;
    if (distPx > 400 || distPx < 0) return;

    const barW = 220.0;
    const barH = 14.0;
    final barX = (size.x - barW) / 2;
    final barY = size.y - 195.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(7)),
      Paint()..color = const Color(0xFF333333),
    );

    final progress = (1 - distPx / 400).clamp(0.0, 1.0);
    final fillColor = Color.lerp(Colors.green, Colors.red, progress)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * progress, barH),
          const Radius.circular(7)),
      Paint()..color = fillColor,
    );

    // Perfect-stop marker
    final markerX = barX + barW * (1 - perfectZone / 400);
    canvas.drawLine(
      Offset(markerX, barY - 5),
      Offset(markerX, barY + barH + 5),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'STOP',
        style: TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(markerX - tp.width / 2, barY - 18));
  }

  void _renderSpeedIndicator(Canvas canvas) {
    if (_levelDone) return;
    final speedKmh = (_train.speed * 3.6).round();
    final tp = TextPainter(
      text: TextSpan(
        text: '$speedKmh km/h',
        style: TextStyle(
            color: _train.isBraking ? Colors.orange : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.x - tp.width - 16, size.y - 195));
  }
}
