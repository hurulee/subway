import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'route_data.dart';
import 'train_component.dart';
import 'map_component.dart';

class SubwayGame extends FlameGame {
  final String routeAsset;
  final ValueNotifier<HudData> hudNotifier =
      ValueNotifier(const HudData(passengers: 0, elapsed: 0, nextStation: ''));
  final ValueNotifier<bool> brakingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> switchAvailableNotifier = ValueNotifier(false);

  int _passengers = 0;
  double _elapsed = 0.0;
  bool _levelDone = false;

  late TrainComponent _train;
  late MapComponent _map;

  // ── Level progression ──────────────────────────────────────────────────────
  int _currentLevelIndex = 0;
  int _totalScore = 0;

  Level get level => gameLevels[_currentLevelIndex];
  int get currentLevelNumber => _currentLevelIndex + 1;
  bool get isLastLevel => _currentLevelIndex >= gameLevels.length - 1;
  int get totalScore => _totalScore;

  // Per-track station lists
  late List<Station> _localStations;
  late List<Station> _expressStations;

  // Per-track next-station indices
  int _nextLocalIdx = 1;
  int _nextExpressIdx = 1;

  TrackType _activeTrack = TrackType.local;

  bool _stoppedAtStation = false;
  double _stopTimer = 0.0;
  static const double stopDuration = 2.0;
  bool _waitingForStart = true;

  // Switch window tracking
  int _currentSwitchIdx = 0;
  bool _switchAvailable = false;

  // Signals
  late List<(SignalColor, SignalColor)> _segmentSignals;

  // Obstacles
  final Set<int> _hitObstacles = {};
  int _penaltyCount = 0;
  double _penaltyFlashTimer = 0.0;

  static const double trainScreenFraction = 0.68;

  // Route data loaded from JSON asset.
  static const int _kStationCount = 7;
  late RouteData _route;

  double get _activeCruiseSpeed => _activeTrack == TrackType.express
      ? level.cruiseSpeed * level.expressSpeedMultiplier
      : level.cruiseSpeed;

  // Braking zones scale with platform length
  double get _perfectZone => level.platformHalfLen * 0.615;
  double get _goodZone => level.platformHalfLen;

  SubwayGame({required this.routeAsset});

  @override
  Future<void> onLoad() async {
    _train = TrainComponent();
    final base = await RouteData.load(routeAsset);
    final n = base.stations.length;
    final count = _kStationCount.clamp(2, n);
    final indices = List.generate(
      count,
      (i) => (i * (n - 1) / (count - 1)).round(),
    );
    _route = base.subset(indices);
    _initLevel();
  }

  void _initLevel() {
    _localStations   = _route.localStations;
    _expressStations = _route.expressStations;

    _map = MapComponent(
      localStations:   _localStations,
      expressStations: _expressStations,
      switchPoints:    level.switchPoints,
      obstacles:       level.obstacles,
      platformHalfLen: level.platformHalfLen,
    );

    _train.trackT = _localStations[level.startIndex].trackPosition;
    _train.speed = 0;
    _train.laneOffset = 0.0;
    _train.isSwitching = false;

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
    _hitObstacles.clear();
    _penaltyCount = 0;
    _penaltyFlashTimer = 0;
    _waitingForStart = true;
    overlays.add('readyToStart');

    brakingNotifier.value = false;
    switchAvailableNotifier.value = false;
    hudNotifier.value = HudData(
      passengers: 0, elapsed: 0, nextStation: '', level: currentLevelNumber,
    );

    _segmentSignals = _computeSegmentSignals();
  }

  /// Pre-compute (localSignal, expressSignal) for each switch segment.
  List<(SignalColor, SignalColor)> _computeSegmentSignals() {
    final signals = <(SignalColor, SignalColor)>[];
    for (int i = 0; i < level.switchPoints.length; i++) {
      final segStart = level.switchPoints[i].trackPosition +
          level.switchPoints[i].windowSize;
      final segEnd = i + 1 < level.switchPoints.length
          ? level.switchPoints[i + 1].trackPosition
          : 1.0;

      bool localRed = false;
      bool expressRed = false;
      for (final obs in level.obstacles) {
        if (obs.trackPosition >= segStart && obs.trackPosition <= segEnd) {
          if (obs.track == TrackType.local) localRed = true;
          if (obs.track == TrackType.express) expressRed = true;
        }
      }
      // Safety: never both red
      if (localRed && expressRed) expressRed = false;
      signals.add((
        localRed ? SignalColor.red : SignalColor.green,
        expressRed ? SignalColor.red : SignalColor.green,
      ));
    }
    // Past all switch points: both green
    signals.add((SignalColor.green, SignalColor.green));
    return signals;
  }

  (SignalColor, SignalColor) get _currentSignals =>
      _segmentSignals[_currentSwitchIdx.clamp(0, _segmentSignals.length - 1)];

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

    if (_waitingForStart) return;

    _elapsed += dt;
    if (_penaltyFlashTimer > 0) _penaltyFlashTimer -= dt;
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
      _checkObstacles();
    }

    if (!_levelDone) _updateHud();
  }

  void _checkArrival() {
    final idx = _nextActiveIdx;
    if (idx >= _activeStations.length) return;

    final targetY = _worldYForT(_activeStations[idx].trackPosition);
    final trainY  = _worldYForT(_train.trackT);
    final distPx  = trainY - targetY;

    if (_train.speed < 8 && distPx < _goodZone * 2) {
      _arriveAtStation(idx);
    } else if (distPx < -_goodZone * 3) {
      _missStation(idx);
    }
  }

  void _arriveAtStation(int idx) {
    final station = _activeStations[idx];

    if (station.passengers > 0) {
      final distPx =
          (_worldYForT(_train.trackT) - _worldYForT(station.trackPosition)).abs();
      int boarded;
      if (distPx <= _perfectZone) {
        boarded = station.passengers;
      } else if (distPx <= _goodZone) {
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

  /// Keep the inactive track's index pointing at the next station ahead.
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
    final frontT = _train.trackT + TrainComponent.h / 2 / kTrackLength;
    final inWindow = frontT >= sp.trackPosition &&
        frontT <= sp.trackPosition + sp.windowSize;

    if (inWindow != _switchAvailable) {
      _switchAvailable = inWindow;
      switchAvailableNotifier.value = inWindow;
    }

    if (!inWindow && frontT > sp.trackPosition + sp.windowSize) {
      _currentSwitchIdx++;
    }
  }

  void requestSwitch() {
    if (!_switchAvailable || _train.isSwitching || _levelDone || _stoppedAtStation) return;
    final targetTrack =
        _activeTrack == TrackType.local ? TrackType.express : TrackType.local;
    _activeTrack = targetTrack;

    // Pre-clear obstacles on the new track already behind the train
    for (int i = 0; i < level.obstacles.length; i++) {
      final obs = level.obstacles[i];
      if (obs.track == targetTrack && obs.trackPosition <= _train.trackT) {
        _hitObstacles.add(i);
      }
    }

    _train.switchToTrack(targetTrack == TrackType.express ? 1.0 : 0.0);
    _switchAvailable = false;
    switchAvailableNotifier.value = false;
    _currentSwitchIdx++;
  }

  void _checkObstacles() {
    for (int i = 0; i < level.obstacles.length; i++) {
      if (_hitObstacles.contains(i)) continue;
      final obs = level.obstacles[i];
      if (obs.track != _activeTrack) continue;
      final frontT = _train.trackT + TrainComponent.h / (2 * kTrackLength);
      if (frontT >= obs.trackPosition) {
        _hitObstacles.add(i);
        _applyPenalty();
      }
    }
  }

  void _applyPenalty() {
    _elapsed += 10.0;
    _penaltyCount++;
    _penaltyFlashTimer = 2.0;
  }

  void _finishLevel() {
    _levelDone = true;
    final passengerScore = _passengers * 10;
    final timeBonus =
        ((level.parTime - _elapsed) * 10).round().clamp(0, 999999);
    final levelScore = (passengerScore + timeBonus - _penaltyCount * 50).clamp(0, 999999);
    _totalScore += levelScore;

    hudNotifier.value = HudData(
      passengers: _passengers,
      elapsed: _elapsed,
      nextStation: '',
      passengerScore: passengerScore,
      timeBonus: timeBonus,
      currentTrack: _activeTrack,
      penaltyCount: _penaltyCount,
      level: currentLevelNumber,
    );

    overlays.remove('brake');
    overlays.remove('switch');

    if (isLastLevel) {
      overlays.add('gameComplete');
    } else {
      overlays.add('levelComplete');
    }
  }

  void _updateHud() {
    final idx = _nextActiveIdx;
    final nextName =
        idx < _activeStations.length ? _activeStations[idx].name : '';
    final sig = _currentSignals;
    hudNotifier.value = HudData(
      passengers: _passengers,
      elapsed: _elapsed,
      nextStation: nextName,
      currentTrack: _activeTrack,
      localSignal: sig.$1,
      expressSignal: sig.$2,
      penaltyCount: _penaltyCount,
      level: currentLevelNumber,
    );
  }

  void setBraking(bool braking) {
    if (_levelDone) return;
    brakingNotifier.value = braking;
  }

  void startLevel() {
    if (!_waitingForStart) return;
    _waitingForStart = false;
    overlays.remove('readyToStart');
  }

  /// Advance to next level after completing current one.
  void proceedToNextLevel() {
    if (isLastLevel) return;
    overlays.remove('levelComplete');
    overlays.add('brake');
    overlays.add('switch');
    _currentLevelIndex++;
    _initLevel();
  }

  /// Restart current level (retry).
  void restartLevel() {
    overlays.remove('levelComplete');
    overlays.remove('gameComplete');
    overlays.add('brake');
    overlays.add('switch');
    // Don't subtract previously accumulated score from prior levels
    _totalScore -= _computeLevelScore();
    _initLevel();
  }

  /// Restart entire game from level 1.
  void restartGame() {
    overlays.remove('gameComplete');
    overlays.remove('levelComplete');
    overlays.add('brake');
    overlays.add('switch');
    _currentLevelIndex = 0;
    _totalScore = 0;
    _initLevel();
  }

  int _computeLevelScore() {
    final passengerScore = _passengers * 10;
    final timeBonus = ((level.parTime - _elapsed) * 10).round().clamp(0, 999999);
    return (passengerScore + timeBonus - _penaltyCount * 50).clamp(0, 999999);
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, kExpressTrackX - 20, size.y),
      Paint()..color = const Color(0xFF1C1C1C),
    );

    // ── World space ─────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(0, -scrollY);

    _map.render(canvas);

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
    _renderPenaltyFlash(canvas);
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

    final markerX = barX + barW * (1 - _perfectZone / 400);
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

  void _renderPenaltyFlash(Canvas canvas) {
    if (_penaltyFlashTimer <= 0) return;
    final alpha = (_penaltyFlashTimer / 2.0).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Color.fromRGBO(220, 0, 0, alpha * 0.30),
    );

    if (alpha > 0.4) {
      final tp = TextPainter(
        text: const TextSpan(
          text: '⚠  OBSTACLE HIT  ⚠\n+10s penalty  −50 pts',
          style: TextStyle(
              color: Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.6),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.x - 32);
      tp.paint(
          canvas, Offset((size.x - tp.width) / 2, size.y * 0.38));
    }
  }
}
