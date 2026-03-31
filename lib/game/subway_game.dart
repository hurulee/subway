import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'route_data.dart';
import 'line_data.dart';
import 'train_component.dart';
import 'map_component.dart';

class SubwayGame extends FlameGame {
  // ignore: prefer_final_fields  — reassigned when randomizing per level
  String _currentRouteAsset = 'assets/data/nyc/a_train.json';
  String get routeAsset => _currentRouteAsset;
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

  // Pre-shuffled route order — one asset path per round, no repeats within a group.
  late List<String> _routeOrder;

  Level get level => gameLevels[_currentLevelIndex];
  int get currentLevelNumber => _currentLevelIndex + 1;
  bool get isLastLevel => _currentLevelIndex >= gameLevels.length - 1;
  int get totalScore => _totalScore;

  // Per-track station lists
  late List<Station> _localStations;
  late List<Station> _expressStations;

  // Per-track next-station indices
  int _nextLocalIdx = 1;
  int _nextExpressIdx = 0;

  TrackType _activeTrack = TrackType.local;

  bool _stoppedAtStation = false;
  double _stopTimer = 0.0;
  bool _waitingForStart = true;

  // Switch points — generated dynamically each level.
  // _kSwitchWindowPx   : fixed pixel length of each switch window (tune to adjust difficulty).
  // _kSwitchGapPosition: 0.0 = just after station, 0.5 = midpoint, 1.0 = just before next station.
  static const double _kSwitchWindowPx    = 200.0;
  static const double _kSwitchGapPosition = 0.6;
  late List<SwitchPoint> _switchPoints;
  int _currentSwitchIdx = 0;
  bool _switchAvailable = false;
  bool _switchQueued = false;

  // Signals
  late List<(SignalColor, SignalColor)> _segmentSignals;

  // Obstacles — generated dynamically each level.
  late List<Obstacle> _obstacles;
  final Set<int> _hitObstacles = {};
  int _penaltyCount = 0;
  double _penaltyFlashTimer = 0.0;

  static const int _kMaxLives = 3;
  int _lives = _kMaxLives;

  // Boarding animations
  final List<BoardingAnim> _boardingAnims = [];

  static const double trainScreenFraction = 0.68;

  // Route data loaded from JSON asset.
  late double _trackLength;
  late double _trackBottomY;

  int _stationCountForLevel() {
    if (_currentLevelIndex < 5)  return 15;
    if (_currentLevelIndex < 10) return 20;
    return 25;
  }

  int _obstacleCountForLevel() {
    if (_currentLevelIndex < 5)  return 5;
    if (_currentLevelIndex < 10) return 9;
    return 15;
  }

  int _switchCountForLevel() {
    if (_currentLevelIndex < 5)  return 7;
    if (_currentLevelIndex < 10) return 10;
    if (_currentLevelIndex < 13) return 13;
    return 16;
  }

  List<SwitchPoint> _generateSwitchPoints() {
    final n = _localStations.length;
    if (n < 2) return [];

    // Compute one candidate switch position per inter-station gap.
    final candidates = <double>[];
    for (int i = 0; i < n - 1; i++) {
      final gapStart = _localStations[i].trackPosition;
      final gapEnd   = _localStations[i + 1].trackPosition;
      candidates.add(gapStart + _kSwitchGapPosition * (gapEnd - gapStart));
    }

    final count = _switchCountForLevel().clamp(1, candidates.length);

    // First gap always gets a switch; randomly pick the rest.
    final remaining = List.generate(candidates.length - 1, (i) => i + 1)
      ..shuffle(Random());
    final selected = [0, ...remaining.take(count - 1)]..sort();

    final windowSize = (_kSwitchWindowPx / _trackLength).clamp(0.001, 0.5);
    return selected.map((i) {
      final windowStart = (candidates[i] - windowSize / 2)
          .clamp(0.01, 1.0 - windowSize);
      return SwitchPoint(trackPosition: windowStart, windowSize: windowSize);
    }).toList();
  }

  List<Obstacle> _generateObstacles() {
    final candidates = <double>[];

    // Station positions (skip terminals)
    for (int i = 1; i < _localStations.length - 1; i++) {
      candidates.add(_localStations[i].trackPosition);
    }

    // Gap midpoints
    for (int i = 0; i < _localStations.length - 1; i++) {
      final gapStart = _localStations[i].trackPosition;
      final gapEnd   = _localStations[i + 1].trackPosition;
      candidates.add(gapStart + _kSwitchGapPosition * (gapEnd - gapStart));
    }

    // Exclude positions before the first switch (unavoidable — player starts on
    // local and cannot switch until they reach switch 0) and inside switch windows.
    final firstSwitchStart =
        _switchPoints.isEmpty ? 1.0 : _switchPoints.first.trackPosition;
    final filtered = candidates.where((pos) {
      if (pos < firstSwitchStart) return false;
      return !_switchPoints.any((sp) =>
          pos >= sp.trackPosition && pos <= sp.trackPosition + sp.windowSize);
    }).toList()..shuffle(Random());

    final count = _obstacleCountForLevel().clamp(0, filtered.length);
    final selected = filtered.take(count).toList()..sort();

    // Assign tracks while guaranteeing each segment has at most one blocked
    // track — otherwise the signal logic would have to show both red, which
    // leaves the player with no safe option.
    final segmentTrack = <int, TrackType>{};
    final result = <Obstacle>[];
    bool nextIsLocal = true;

    for (final pos in selected) {
      final seg = _obstacleSegmentFor(pos);
      if (segmentTrack.containsKey(seg)) continue; // already one obstacle here

      final track = nextIsLocal ? TrackType.local : TrackType.express;
      nextIsLocal = !nextIsLocal;
      segmentTrack[seg] = track;
      result.add(Obstacle(trackPosition: pos, track: track));
    }

    return result;
  }

  /// Returns which signal segment an obstacle position belongs to.
  /// Segment i covers [switch_i_end, switch_{i+1}_start].
  int _obstacleSegmentFor(double pos) {
    for (int i = 0; i < _switchPoints.length; i++) {
      if (pos < _switchPoints[i].trackPosition) return i - 1;
    }
    return _switchPoints.length - 1;
  }

  double get _activeCruiseSpeed => _activeTrack == TrackType.express
      ? level.cruiseSpeed * level.expressSpeedMultiplier
      : level.cruiseSpeed;

  // Braking zones scale with platform length
  double get _perfectZone => level.platformHalfLen * 0.615;
  double get _goodZone => level.platformHalfLen;

  /// Build a 15-entry route order: 5 from each group, shuffled within the group,
  /// with no line repeated within a group.
  void _buildRouteOrder() {
    List<String> pickGroup(LineGroup g) =>
        (linesForGroup(g)..shuffle(Random())).take(5).map((l) => l.assetPath).toList();

    _routeOrder = [
      ...pickGroup(LineGroup.short),
      ...pickGroup(LineGroup.medium),
      ...pickGroup(LineGroup.long),
    ];
  }

  void _setRouteForCurrentLevel() {
    _currentRouteAsset = _routeOrder[_currentLevelIndex];
  }

  Future<void> _loadRoute() async {
    final base = await RouteData.load(_currentRouteAsset);
    final n = base.stations.length;
    final count = _stationCountForLevel().clamp(2, n);
    final indices = List.generate(
      count,
      (i) => (i * (n - 1) / (count - 1)).round(),
    );
    final stations = base.subset(indices);
    _localStations   = stations.$1;
    _expressStations = stations.$2;
    _trackLength  = trackLengthForCount(count);
    _trackBottomY = trackBottomYForCount(count);
    _switchPoints = _generateSwitchPoints();
    _obstacles    = _generateObstacles();
  }

  @override
  Future<void> onLoad() async {
    _train = TrainComponent();
    _buildRouteOrder();
    _setRouteForCurrentLevel();
    await _loadRoute();
    _initLevel();
  }

  void _initLevel() {
    _map = MapComponent(
      localStations:   _localStations,
      expressStations: _expressStations,
      switchPoints:    _switchPoints,
      obstacles:       _obstacles,
      platformHalfLen: level.platformHalfLen,
      trackLength:     _trackLength,
      trackBottomY:    _trackBottomY,
    );

    // Starting station is a terminal — no passengers to pick up
    _localStations[level.startIndex].passengers = 0;
    _train.trackT = _localStations[level.startIndex].trackPosition;
    _train.trackLength = _trackLength;
    _train.speed = 0;
    _train.laneOffset = 0.0;
    _train.isSwitching = false;

    _passengers = 0;
    _elapsed = 0;
    _levelDone = false;
    _nextLocalIdx = 1;   // skip local terminal at index 0
    _nextExpressIdx = 0;  // express list may not start with the terminal
    _activeTrack = TrackType.local;
    _stoppedAtStation = false;
    _stopTimer = 0;
    _currentSwitchIdx = 0;
    _switchAvailable = false;
    _switchQueued = false;
    _hitObstacles.clear();
    _penaltyCount = 0;
    _penaltyFlashTimer = 0;
    _lives = _kMaxLives;
    _boardingAnims.clear();
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
    for (int i = 0; i < _switchPoints.length; i++) {
      final segStart = _switchPoints[i].trackPosition +
          _switchPoints[i].windowSize;
      final segEnd = i + 1 < _switchPoints.length
          ? _switchPoints[i + 1].trackPosition
          : 1.0;

      bool localRed = false;
      bool expressRed = false;
      for (final obs in _obstacles) {
        if (obs.trackPosition >= segStart && obs.trackPosition <= segEnd) {
          if (obs.track == TrackType.local) localRed = true;
          if (obs.track == TrackType.express) expressRed = true;
        }
      }
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

  double _worldYForT(double t) => _trackBottomY - t * _trackLength;

  /// Walk backward along the S-curve from [startT] by [arcPixels] of arc length.
  /// Returns the new trackT. [trackDx] is (kExpressTrackX - kLocalTrackX).
  double _walkArcLength(double startT, double arcPixels, double trackDx) {
    const stepPx = 1.0; // fine step for smooth integration
    final stepT = stepPx / _trackLength;
    double remaining = arcPixels;
    double t = startT;
    while (remaining > 0) {
      // Use a smaller final step to avoid overshoot
      final fraction = remaining < stepPx ? remaining / stepPx : 1.0;
      final actualStepT = stepT * fraction;
      final lane0 = _train.laneOffsetAt(t);
      final lane1 = _train.laneOffsetAt(t - actualStepT);
      final dx = (lane1 - lane0) * trackDx;
      final dy = stepPx * fraction;
      final arcStep = sqrt(dx * dx + dy * dy);
      t -= actualStepT;
      remaining -= arcStep;
    }
    return t;
  }

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

      // Spawn all boarding animations at once when boarding starts
      final idx = _nextActiveIdx;
      if (idx < _activeStations.length) {
        final station = _activeStations[idx];

        if (station.boardableCount > 0 && !_boardingSpawned) {
          _spawnAllBoardingAnims(station);
          _boardingSpawned = true;
        }

        // Holding brake keeps doors open — spawn more if new passengers become boardable
        if (brakingNotifier.value) {
          if (station.boardableCount <= 0 && station.passengers > 0) {
            station.boardableCount = station.passengers;
            _spawnAllBoardingAnims(station);
          }
        }
      }

      // Count passengers as their animations reach the train
      for (final anim in _boardingAnims) {
        if (!anim.counted && anim.done) {
          anim.counted = true;
          _passengers++;
        }
      }

      final animsInFlight = _boardingAnims.any((a) => !a.done);
      final allBoarded = idx >= _activeStations.length ||
          (_activeStations[idx].boardableCount <= 0 && !animsInFlight);
      // Depart when brake is released (after min 0.5s) and all have boarded
      final depart = allBoarded && !brakingNotifier.value && _stopTimer >= 0.5;
      if (depart) {
        _stoppedAtStation = false;
        _stopTimer = 0;
        _setNextActiveIdx(_nextActiveIdx + 1);
        if (_nextActiveIdx >= _activeStations.length &&
            _activeTrack == TrackType.local) {
          _finishLevel();
          return;
        }
      }
    } else {
      _train.trackT += (_train.speed * dt) / _trackLength;
      _train.trackT = _train.trackT.clamp(0.0, 1.0);
      _checkArrival();
      if (_train.trackT >= 1.0) { _finishLevel(); return; }
      _syncPassiveTrackIndex();
      _checkSwitchWindow();
      _checkObstacles();
    }

    // Update boarding animations
    for (final anim in _boardingAnims) {
      anim.progress += dt / anim.duration;
      if (anim.progress > 1.0) anim.progress = 1.0;
    }
    _boardingAnims.removeWhere((a) => a.done && a.counted);

    if (!_levelDone) _updateHud();
  }

  void _checkArrival() {
    if (_train.speed >= 8) return;

    final trainY = _worldYForT(_train.trackT);
    final stations = _activeStations;

    // Search all stations for the closest one within arrival range.
    // Skip the local starting terminal (index 0 on local track only).
    int? bestIdx;
    double bestDist = double.infinity;
    final startSearch = _activeTrack == TrackType.local ? 1 : 0;
    for (int i = startSearch; i < stations.length; i++) {
      if (stations[i].passengers <= 0) continue; // already fully boarded
      final targetY = _worldYForT(stations[i].trackPosition);
      final distPx = trainY - targetY;
      final absDist = distPx.abs();

      if (distPx < _goodZone * 2 && distPx > -_goodZone * 3 && absDist < bestDist) {
        bestDist = absDist;
        bestIdx = i;
      }
    }

    if (bestIdx != null) {
      _setNextActiveIdx(bestIdx);
      _arriveAtStation(bestIdx);
      return;
    }

    // Advance index past missed stations
    final idx = _nextActiveIdx;
    if (idx < stations.length) {
      final distPx = trainY - _worldYForT(stations[idx].trackPosition);
      if (distPx < -_goodZone * 3) {
        _missStation(idx);
      }
    }
  }

  bool _boardingSpawned = false;

  void _arriveAtStation(int idx) {
    final station = _activeStations[idx];

    if (station.passengers > 0) {
      final distPx =
          (_worldYForT(_train.trackT) - _worldYForT(station.trackPosition)).abs();
      if (distPx <= _perfectZone) {
        station.boardableCount = station.passengers;
      } else if (distPx <= _goodZone) {
        station.boardableCount = (station.passengers * 0.6).round();
      } else {
        station.boardableCount = (station.passengers * 0.25).round();
      }
    }

    _boardingSpawned = false;
    _train.speed = 0;
    _stoppedAtStation = true;
  }

  /// Spawn boarding animations for all boardable passengers at once.
  /// Each walks to the nearest car; distance determines arrival time.
  void _spawnAllBoardingAnims(Station station) {
    final worldY = _worldYForT(station.trackPosition);
    final isExpress = station.track == TrackType.express;
    final platLeft = isExpress ? kExpressPlatLeft : kLocalPlatLeft;
    final platRight = isExpress ? kExpressPlatRight : kLocalPlatRight;
    final platWidth = platRight - platLeft;
    final areaLeft = platLeft + 8;
    final areaWidth = platWidth - 16;
    final areaTop = worldY - _map.platformHalfLen + 8;
    final areaHeight = _map.platformHalfLen * 2 - 28;
    final trackX = isExpress ? kExpressTrackX : kLocalTrackX;

    final trainWorldY = _worldYForT(_train.trackT);
    final trainTop = trainWorldY - TrainComponent.h / 2;
    final carCenters = List.generate(TrainComponent.numCars, (c) =>
        trainTop + c * (TrainComponent.carH + TrainComponent.couplingGap) +
        TrainComponent.carH / 2);

    final startIdx = station.figurePositions.length - station.passengers;
    final endIdx = startIdx + station.boardableCount;
    for (int i = startIdx; i < endIdx; i++) {
      final (xf, yf) = station.figurePositions[i];
      final fx = areaLeft + xf * areaWidth;
      final fy = areaTop + yf * areaHeight;

      // Find nearest car
      double bestDist = double.infinity;
      double doorY = trainWorldY;
      for (int c = 0; c < TrainComponent.numCars; c++) {
        final dist = (fy - carCenters[c]).abs();
        if (dist < bestDist) {
          bestDist = dist;
          doorY = carCenters[c];
        }
      }

      // Target the platform-facing edge of the train, not the center
      final doorX = trackX + TrainComponent.w / 2;
      _boardingAnims.add(BoardingAnim(
        startX: fx, startY: fy,
        endX: doorX, endY: doorY,
      ));
    }

    // Remove from platform immediately (they're now animating)
    station.passengers -= station.boardableCount;
    station.boardableCount = 0;
  }

  void _missStation(int idx) {
    _setNextActiveIdx(idx + 1);
    if (_nextActiveIdx >= _activeStations.length &&
        _activeTrack == TrackType.local) {
      _finishLevel();
    }
  }

  /// Keep the inactive track's index pointing at the next station ahead.
  void _syncPassiveTrackIndex() {
    final passiveStations =
        _activeTrack == TrackType.local ? _expressStations : _localStations;
    var idx =
        _activeTrack == TrackType.local ? _nextExpressIdx : _nextLocalIdx;
    final missBuffer = _goodZone * 3 / _trackLength;
    while (idx < passiveStations.length &&
        _train.trackT > passiveStations[idx].trackPosition + missBuffer) {
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
    if (_currentSwitchIdx >= _switchPoints.length) {
      if (_switchAvailable) {
        _switchAvailable = false;
        switchAvailableNotifier.value = false;
      }
      return;
    }

    final sp = _switchPoints[_currentSwitchIdx];
    final frontT = _train.trackT + TrainComponent.h / 2 / _trackLength;
    // Decision window: available while the front is approaching the switch,
    // closes once the front reaches the switch start.
    final inWindow = frontT >= sp.trackPosition - sp.windowSize &&
        frontT <= sp.trackPosition;

    if (!_switchQueued && inWindow != _switchAvailable) {
      _switchAvailable = inWindow;
      switchAvailableNotifier.value = inWindow;
    }

    // Execute queued switch when the front reaches the switch point
    if (_switchQueued && frontT >= sp.trackPosition) {
      _executeSwitch();
      return;
    }

    if (!_switchQueued && !inWindow && frontT > sp.trackPosition) {
      _currentSwitchIdx++;
    }
  }

  void requestSwitch() {
    if (!_switchAvailable || _switchQueued || _train.isSwitching || _levelDone || _stoppedAtStation) return;
    _switchQueued = true;
    _switchAvailable = false;
    switchAvailableNotifier.value = false;
  }

  void _executeSwitch() {
    _switchQueued = false;
    final targetTrack =
        _activeTrack == TrackType.local ? TrackType.express : TrackType.local;
    _activeTrack = targetTrack;

    // Pre-clear obstacles on the new track already behind the train
    for (int i = 0; i < _obstacles.length; i++) {
      final obs = _obstacles[i];
      if (obs.track == targetTrack && obs.trackPosition <= _train.trackT) {
        _hitObstacles.add(i);
      }
    }

    final sp = _switchPoints[_currentSwitchIdx];
    _train.switchToTrack(
      targetTrack == TrackType.express ? 1.0 : 0.0,
      zoneStart: sp.trackPosition,
      zoneEnd: sp.trackPosition + sp.windowSize,
    );
    _currentSwitchIdx++;

    // Resync station indices so the new active track points at the correct
    // next station (passive sync may have advanced it too far).
    _resyncStationIndex(_localStations, (v) => _nextLocalIdx = v, startIdx: 1);
    _resyncStationIndex(_expressStations, (v) => _nextExpressIdx = v);
  }

  void _checkObstacles() {
    for (int i = 0; i < _obstacles.length; i++) {
      if (_hitObstacles.contains(i)) continue;
      final obs = _obstacles[i];
      if (obs.track != _activeTrack) continue;
      final frontT = _train.trackT + TrainComponent.h / (2 * _trackLength);
      if (frontT >= obs.trackPosition) {
        _hitObstacles.add(i);
        _applyPenalty();
      }
    }
  }

  void _applyPenalty() {
    _penaltyCount++;
    _penaltyFlashTimer = 2.0;
    _lives--;

    if (_lives <= 0) {
      _finishLevel();
      return;
    }

    // Snap back to just before the last switch window, staying on the
    // same track the player was on when they hit the obstacle.
    if (_currentSwitchIdx > 0) {
      final snapIdx = _currentSwitchIdx - 1;
      final sp = _switchPoints[snapIdx];
      _train.trackT = (sp.trackPosition - 0.02).clamp(0.0, 1.0);
      _train.speed = 0;

      // Stay on the current track (don't reset to local)
      _train.laneOffset = _activeTrack == TrackType.express ? 1.0 : 0.0;
      _train.isSwitching = false;

      // Rewind switch index so the player can re-choose
      _currentSwitchIdx = snapIdx;
      _switchAvailable = false;
      _switchQueued = false;
      switchAvailableNotifier.value = false;

      // Un-hit obstacles that are now ahead again
      _hitObstacles.removeWhere(
          (i) => _obstacles[i].trackPosition > _train.trackT);

      // Re-sync station indices to match new position
      _resyncStationIndex(_localStations, (v) => _nextLocalIdx = v);
      _resyncStationIndex(_expressStations, (v) => _nextExpressIdx = v);

      _stoppedAtStation = false;
      _stopTimer = 0;
    }
  }

  /// Reset a station index so it points at the first station ahead of the
  /// train's current position.
  void _resyncStationIndex(
      List<Station> stations, void Function(int) setter, {int startIdx = 0}) {
    // Don't skip a station the player could still stop at — use the same
    // miss threshold as _checkArrival (_goodZone * 3 pixels, converted to
    // track-position units).
    final missBuffer = _goodZone * 3 / _trackLength;
    int idx = startIdx;
    while (idx < stations.length &&
        _train.trackT > stations[idx].trackPosition + missBuffer) {
      idx++;
    }
    setter(idx);
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
      lives: _lives,
      maxLives: _kMaxLives,
    );

    overlays.remove('brake');
    overlays.remove('switch');

    if (_lives <= 0) {
      overlays.add('gameOver');
    } else if (isLastLevel) {
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
      lives: _lives,
      maxLives: _kMaxLives,
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
  Future<void> proceedToNextLevel() async {
    if (isLastLevel) return;
    overlays.remove('levelComplete');
    overlays.add('brake');
    overlays.add('switch');
    _currentLevelIndex++;
    _setRouteForCurrentLevel();
    await _loadRoute();
    _initLevel();
  }

  /// Restart current level (retry).
  void restartLevel() {
    overlays.remove('levelComplete');
    overlays.remove('gameComplete');
    overlays.remove('gameOver');
    overlays.add('brake');
    overlays.add('switch');
    // Don't subtract previously accumulated score from prior levels
    _totalScore -= _computeLevelScore();
    _initLevel();
  }

  /// Restart entire game from level 1.
  Future<void> restartGame() async {
    overlays.remove('gameComplete');
    overlays.remove('levelComplete');
    overlays.remove('gameOver');
    overlays.add('brake');
    overlays.add('switch');
    _currentLevelIndex = 0;
    _totalScore = 0;
    _buildRouteOrder();
    _setRouteForCurrentLevel();
    await _loadRoute();
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

    // Boarding animations (world space)
    for (final anim in _boardingAnims) {
      _drawFigure(canvas, anim.x, anim.y);
    }

    if (_train.isSwitching) {
      // Per-car rendering: each car follows the S-curve, spaced by arc length.
      final trackDx = (kExpressTrackX - kLocalTrackX).toDouble();

      // Walk backward from the front of the train along the curve to find
      // each car center's trackT, spaced by true arc length.
      final frontTrackT = _train.trackT + TrainComponent.h / (2 * _trackLength);
      final carTrackTs = <double>[];
      double walkT = frontTrackT;

      for (int i = 0; i < TrainComponent.numCars; i++) {
        // Walk back by carH/2 to reach this car's center
        walkT = _walkArcLength(walkT, TrainComponent.carH / 2, trackDx);
        carTrackTs.add(walkT);
        // Walk back by carH/2 + couplingGap to reach the next car's front
        if (i < TrainComponent.numCars - 1) {
          walkT = _walkArcLength(
              walkT, TrainComponent.carH / 2 + TrainComponent.couplingGap, trackDx);
        }
      }

      for (int i = 0; i < TrainComponent.numCars; i++) {
        final carTrackT = carTrackTs[i];
        final carLane = _train.laneOffsetAt(carTrackT);
        final carX = kLocalTrackX + trackDx * carLane;
        final carWorldY = _worldYForT(carTrackT);

        // Tilt from the curve tangent in pixel space
        const eps = 0.0001;
        final dLane = _train.laneOffsetAt(carTrackT + eps) -
            _train.laneOffsetAt(carTrackT - eps);
        final dxPx = dLane * trackDx;
        final dyPx = 2 * eps * _trackLength; // positive = downward in worldY
        final carAngle = atan2(dxPx, dyPx); // angle from straight ahead

        canvas.save();
        canvas.translate(carX, carWorldY);
        canvas.rotate(carAngle);
        canvas.translate(-TrainComponent.w / 2, -TrainComponent.carH / 2);
        _train.renderCar(canvas, i);
        canvas.restore();

        // Coupling to next car
        if (i < TrainComponent.numCars - 1) {
          final nextT = carTrackTs[i + 1];
          final nextLane = _train.laneOffsetAt(nextT);
          final nextX = kLocalTrackX + trackDx * nextLane;
          final nextWorldY = _worldYForT(nextT);
          final rearY = carWorldY + TrainComponent.carH / 2 * cos(carAngle);
          final rearX = carX + TrainComponent.carH / 2 * sin(carAngle);

          final dLaneNext = _train.laneOffsetAt(nextT + eps) -
              _train.laneOffsetAt(nextT - eps);
          final nextAngle = atan2(dLaneNext * trackDx, dyPx);
          final frontY = nextWorldY - TrainComponent.carH / 2 * cos(nextAngle);
          final frontX = nextX - TrainComponent.carH / 2 * sin(nextAngle);

          final couplingPaint = Paint()
            ..color = const Color(0xFF555555)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(rearX - TrainComponent.w * 0.15, rearY),
            Offset(frontX - TrainComponent.w * 0.15, frontY),
            couplingPaint);
          canvas.drawLine(
            Offset(rearX + TrainComponent.w * 0.15, rearY),
            Offset(frontX + TrainComponent.w * 0.15, frontY),
            couplingPaint);
        }
      }
      // Sparks relative to rear car
      final rearCarT = carTrackTs.last;
      final rearLane = _train.laneOffsetAt(rearCarT);
      final rearX = kLocalTrackX + trackDx * rearLane;
      final rearWorldY = _worldYForT(rearCarT);
      canvas.save();
      canvas.translate(rearX, rearWorldY);
      _train.renderSparks(canvas);
      canvas.restore();
    } else {
      // Rigid rendering when not switching
      final trainX = kLocalTrackX +
          (kExpressTrackX - kLocalTrackX) * _train.laneOffset;
      final trainLeft = trainX - TrainComponent.w / 2;
      final trainTop = trainWorldY - TrainComponent.h / 2;
      canvas.save();
      canvas.translate(trainLeft, trainTop);
      _train.render(canvas);
      canvas.restore();
    }

    canvas.restore();

    // ── Screen-space overlays ───────────────────────────────────────────────
    _renderApproachBar(canvas);
    _renderSpeedIndicator(canvas);
    _renderPenaltyFlash(canvas);
  }

  void _drawFigure(Canvas canvas, double x, double y) {
    final paint = Paint()..color = const Color(0xFFEEEEEE);
    canvas.drawCircle(Offset(x, y), 3.0, paint);
    canvas.drawLine(Offset(x, y + 3), Offset(x, y + 10),
        paint..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(x - 3, y + 6), Offset(x + 3, y + 6), paint);
    canvas.drawLine(Offset(x, y + 10), Offset(x - 2.5, y + 15), paint);
    canvas.drawLine(Offset(x, y + 10), Offset(x + 2.5, y + 15), paint);
    paint.style = PaintingStyle.fill;
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
