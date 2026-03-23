import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'train_component.dart';
import 'map_component.dart';

class SubwayGame extends FlameGame {
  final ValueNotifier<HudData> hudNotifier =
      ValueNotifier(const HudData(passengers: 0, elapsed: 0, nextStation: ''));
  final ValueNotifier<bool> brakingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> switchAvailableNotifier = ValueNotifier(false);

  int _passengers = 0;
  double _elapsed = 0.0;
  bool _levelDone = false;

  late TrainComponent _train;
  late MapComponent _map;

  final Level level = gameLevel;

  // Per-track station lists (filtered from level.stations on load)
  late final List<Station> _localStations;
  late final List<Station> _expressStations;

  // Per-track next-station indices
  int _nextLocalIdx = 1;
  int _nextExpressIdx = 1;

  TrackType _activeTrack = TrackType.local;

  bool _stoppedAtStation = false;
  double _stopTimer = 0.0;
  static const double stopDuration = 2.0;
  double _startupDelay = 0.9;

  // Switch window tracking
  int _currentSwitchIdx = 0;
  bool _switchAvailable = false;

  static const double cruiseSpeed = 160.0;
  static const double perfectZone = 80.0;
  static const double goodZone = 130.0;
  static const double trainScreenFraction = 0.68;

  double get _activeCruiseSpeed => _activeTrack == TrackType.express
      ? cruiseSpeed * level.expressSpeedMultiplier
      : cruiseSpeed;

  @override
  Future<void> onLoad() async {
    _localStations   = level.stations.where((s) => s.track == TrackType.local).toList();
    _expressStations = level.stations.where((s) => s.track == TrackType.express).toList();

    _map = MapComponent(
      localStations:   _localStations,
      expressStations: _expressStations,
      switchPoints:    level.switchPoints,
    );
    _train = TrainComponent();
    _train.trackT = _localStations[level.startIndex].trackPosition;
  }

  double _worldYForT(double t) => kTrackBottomY - t * kTrackLength;

  List<Station> get _activeStations =>
      _activeTrack == TrackType.local ? _localStations : _expressStations;

  int get _nextActiveIdx =>
      _activeTrack == TrackType.local ? _nextLocalIdx : _nextExpressIdx;

  void _setNextActiveIdx(int v) {
    if (_activeTrack == TrackType.local) {
      _nextLocalIdx = v;
    } else {
      _nextExpressIdx = v;
    }
  }

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
    _train.targetSpeed =
        (_stoppedAtStation || brakingNotifier.value) ? 0.0 : _activeCruiseSpeed;
    _train.update(dt);

    if (_stoppedAtStation) {
      _stopTimer += dt;
      final earlyDepart = !brakingNotifier.value && _stopTimer >= 0.5;
      if (earlyDepart || _stopTimer >= stopDuration) {
        _stoppedAtStation = false;
        _stopTimer = 0;
        _setNextActiveIdx(_nextActiveIdx + 1);
        if (_nextActiveIdx >= _activeStations.length) {
          _finishLevel();
          return;
        }
      }
    } else {
      _train.trackT += (_train.speed * dt) / kTrackLength;
      _train.trackT = _train.trackT.clamp(0.0, 1.0);
      _checkArrival();
      if (_train.trackT >= 1.0) { _finishLevel(); return; }
      _syncPassiveTrackIndex();
      _checkSwitchWindow();
    }

    if (!_levelDone) _updateHud();
  }

  void _checkArrival() {
    final idx = _nextActiveIdx;
    if (idx >= _activeStations.length) return;

    final targetY = _worldYForT(_activeStations[idx].trackPosition);
    final trainY  = _worldYForT(_train.trackT);
    final distPx  = trainY - targetY;

    if (_train.speed < 8 && distPx < goodZone * 2) {
      _arriveAtStation(idx);
    } else if (distPx < -goodZone * 3) {
      _missStation(idx);
    }
  }

  void _arriveAtStation(int idx) {
    final station = _activeStations[idx];

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
    _setNextActiveIdx(idx + 1);
    if (_nextActiveIdx >= _activeStations.length) {
      _finishLevel();
    }
  }

  /// Keep the inactive track's index pointing at the next station ahead,
  /// so that switching to it immediately gives a valid target.
  void _syncPassiveTrackIndex() {
    final passiveStations =
        _activeTrack == TrackType.local ? _expressStations : _localStations;
    var idx =
        _activeTrack == TrackType.local ? _nextExpressIdx : _nextLocalIdx;
    while (idx < passiveStations.length &&
        _train.trackT > passiveStations[idx].trackPosition + 0.01) {
      idx++;
    }
    if (_activeTrack == TrackType.local) {
      _nextExpressIdx = idx;
    } else {
      _nextLocalIdx = idx;
    }
  }

  void _checkSwitchWindow() {
    if (_train.isSwitching) return;
    if (_currentSwitchIdx >= level.switchPoints.length) {
      if (_switchAvailable) {
        _switchAvailable = false;
        switchAvailableNotifier.value = false;
      }
      return;
    }

    final sp = level.switchPoints[_currentSwitchIdx];
    // Use the front of the train (leading edge) as the reference point
    final frontT = _train.trackT + TrainComponent.h / 2 / kTrackLength;
    final inWindow = frontT >= sp.trackPosition &&
        frontT <= sp.trackPosition + sp.windowSize;

    if (inWindow != _switchAvailable) {
      _switchAvailable = inWindow;
      switchAvailableNotifier.value = inWindow;
    }

    // Missed the window — advance to the next switch point
    if (!inWindow && frontT > sp.trackPosition + sp.windowSize) {
      _currentSwitchIdx++;
    }
  }

  void requestSwitch() {
    if (!_switchAvailable || _train.isSwitching || _levelDone || _stoppedAtStation) return;
    final targetTrack =
        _activeTrack == TrackType.local ? TrackType.express : TrackType.local;
    _activeTrack = targetTrack;
    _train.switchToTrack(targetTrack == TrackType.express ? 1.0 : 0.0);
    _switchAvailable = false;
    switchAvailableNotifier.value = false;
    _currentSwitchIdx++;
  }

  void _finishLevel() {
    _levelDone = true;
    final passengerScore = _passengers * 10;
    final timeBonus =
        ((level.parTime - _elapsed) * 10).round().clamp(0, 999999);
    hudNotifier.value = HudData(
      passengers: _passengers,
      elapsed: _elapsed,
      nextStation: '',
      passengerScore: passengerScore,
      timeBonus: timeBonus,
      currentTrack: _activeTrack,
    );
    overlays.add('levelComplete');
    overlays.remove('brake');
    overlays.remove('switch');
  }

  void _updateHud() {
    final idx = _nextActiveIdx;
    final nextName =
        idx < _activeStations.length ? _activeStations[idx].name : '';
    hudNotifier.value = HudData(
      passengers: _passengers,
      elapsed: _elapsed,
      nextStation: nextName,
      currentTrack: _activeTrack,
    );
  }

  void setBraking(bool braking) {
    if (_levelDone) return;
    brakingNotifier.value = braking;
  }

  void restartLevel() {
    overlays.remove('levelComplete');
    overlays.add('brake');
    overlays.add('switch');
    _passengers = 0;
    _elapsed = 0;
    _levelDone = false;
    _nextLocalIdx = 1;
    _nextExpressIdx = 1;
    _activeTrack = TrackType.local;
    _stoppedAtStation = false;
    _stopTimer = 0;
    _currentSwitchIdx = 0;
    _switchAvailable = false;
    switchAvailableNotifier.value = false;
    _train.trackT = _localStations[level.startIndex].trackPosition;
    _train.speed = 0;
    _train.laneOffset = 0.0;
    _train.isSwitching = false;
    brakingNotifier.value = false;
    hudNotifier.value = const HudData(passengers: 0, elapsed: 0, nextStation: '');
    _startupDelay = 0.9;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final trainWorldY = _worldYForT(_train.trackT);
    final scrollY = trainWorldY - size.y * trainScreenFraction;

    // ── Background ──────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF111111),
    );
    // Left tunnel wall
    canvas.drawRect(
      Rect.fromLTWH(0, 0, kExpressTrackX - 20, size.y),
      Paint()..color = const Color(0xFF1C1C1C),
    );

    // ── World space ─────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(0, -scrollY);

    _map.render(canvas);

    // Train X interpolated between local and express track centres
    final trainX = kLocalTrackX +
        (kExpressTrackX - kLocalTrackX) * _train.laneOffset;
    final trainLeft = trainX - TrainComponent.w / 2;
    final trainTop  = trainWorldY - TrainComponent.h / 2;

    canvas.save();
    if (_train.isSwitching) {
      final cx = trainX;
      final cy = trainWorldY;
      canvas.translate(cx, cy);
      canvas.rotate(_train.switchTiltAngle);
      canvas.translate(-cx, -cy);
    }
    canvas.translate(trainLeft, trainTop);
    _train.render(canvas);
    canvas.restore();

    canvas.restore();

    // ── Screen-space overlays ───────────────────────────────────────────────
    _renderApproachBar(canvas);
    _renderSpeedIndicator(canvas);
  }

  void _renderApproachBar(Canvas canvas) {
    if (_stoppedAtStation || _levelDone) return;
    final idx = _nextActiveIdx;
    if (idx >= _activeStations.length) return;

    final targetY = _worldYForT(_activeStations[idx].trackPosition);
    final trainY  = _worldYForT(_train.trackT);
    final distPx  = trainY - targetY;
    if (distPx > 400 || distPx < 0) return;

    const barW = 200.0;
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
