import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double kExpressTrackX = 80.0;
const double kLocalTrackX   = 210.0;
const double kTrackTopY     = 100.0;

double trackLengthForCount(int n) => 900.0 * (n - 1);
double trackBottomYForCount(int n) => kTrackTopY + trackLengthForCount(n);

const double kExpressPlatLeft  = kExpressTrackX + 16.0;
const double kExpressPlatRight = kLocalTrackX - 16.0;
const double _platWidth        = kExpressPlatRight - kExpressPlatLeft;
const double kLocalPlatLeft    = kLocalTrackX + 16.0;
const double kLocalPlatRight   = kLocalPlatLeft + _platWidth;

class MapComponent {
  final List<Station> localStations;
  final List<Station> expressStations;
  final List<SwitchPoint> switchPoints;
  final List<Obstacle> obstacles;
  final double platformHalfLen;
  final double trackLength;
  final double trackBottomY;

  // Bends
  final List<Bend> bends;

  // Debris & rats
  late final List<_Debris> _debris;
  late final List<_Rat> _rats;

  MapComponent({
    required this.localStations,
    required this.expressStations,
    required this.switchPoints,
    required this.obstacles,
    required this.trackLength,
    required this.trackBottomY,
    this.platformHalfLen = 130.0,
    this.bends = const [],
  }) {
    _generateDebris();
    _generateRats();
  }

  void _generateDebris() {
    final rng = Random();
    _debris = [];
    const count = 40;
    for (int i = 0; i < count; i++) {
      final trackT = 0.02 + rng.nextDouble() * 0.96;
      // Place debris on either side of either track
      final trackX = rng.nextBool() ? kLocalTrackX : kExpressTrackX;
      final offsetX = (rng.nextDouble() * 24 + 16) * (rng.nextBool() ? 1 : -1);
      final type = _DebrisType.values[rng.nextInt(_DebrisType.values.length)];
      _debris.add(_Debris(
        trackT: trackT,
        trackX: trackX,
        offsetX: offsetX,
        type: type,
        rotation: rng.nextDouble() * pi * 2,
      ));
    }
  }

  void _generateRats() {
    final rng = Random();
    _rats = [];
    const count = 8;
    for (int i = 0; i < count; i++) {
      final trackT = 0.05 + rng.nextDouble() * 0.90;
      final trackX = rng.nextBool() ? kLocalTrackX : kExpressTrackX;
      final offsetX = (rng.nextDouble() * 20 + 18) * (rng.nextBool() ? 1 : -1);
      _rats.add(_Rat(
        trackT: trackT,
        trackX: trackX,
        offsetX: offsetX,
        heading: rng.nextDouble() * pi * 2,
        idleTimer: rng.nextDouble() * 3.0,
        rng: rng,
      ));
    }
  }

  void update(double dt) {
    for (final rat in _rats) {
      rat.update(dt);
    }
  }

  double _worldY(double trackT) => trackBottomY - trackT * trackLength;

  /// Reference X used as the arc center for bends (midpoint of the two tracks).
  static const double _bendCenterX = (kLocalTrackX + kExpressTrackX) / 2;

  /// Bend angle constant (45 degrees).
  static const double bendAngle = pi / 4;

  /// World position for a trackT, supporting multiple bends.
  /// Tracks the reference midpoint and accumulated angle through each bend,
  /// with per-track offset applied perpendicular to the current heading.
  Offset worldPosForT(double trackT, double baseX) {
    if (bends.isEmpty) return Offset(baseX, _worldY(trackT));

    // Reference midpoint position and accumulated heading angle.
    // angle=0 means straight up (-Y). Heading vector = (-sin(a), -cos(a)).
    // Left-perpendicular = (-cos(a), sin(a)).
    double rx = _bendCenterX, ry = _worldY(0);
    double a = 0.0;
    double curT = 0.0;

    for (final bend in bends) {
      if (trackT <= bend.startT) break;

      // Advance reference straight to bend start
      final d = (bend.startT - curT) * trackLength;
      rx -= d * sin(a);
      ry -= d * cos(a);
      curT = bend.startT;

      final dir = bend.direction.toDouble();
      final bendPx = (bend.endT - bend.startT) * trackLength;
      final refR = bendPx / bendAngle;

      // Arc center: perpendicular to heading, in bend direction
      final cx = rx - dir * refR * cos(a);
      final cy = ry + dir * refR * sin(a);

      if (trackT <= bend.endT) {
        // Within this bend's arc
        final progress = (trackT - bend.startT) / (bend.endT - bend.startT);
        final arcA = progress * bendAngle;
        final trackOff = baseX - _bendCenterX;
        final r = refR + dir * trackOff;
        // Vector from center back to ref at start = (dir*cos(a), -dir*sin(a)) * refR
        // Rotate this by -dir * arcA
        final startAngle = atan2(-dir * sin(a), dir * cos(a));
        final curAngle = startAngle - dir * arcA;
        return Offset(cx + r * cos(curAngle), cy + r * sin(curAngle));
      }

      // Advance past this bend
      final startAngle = atan2(-dir * sin(a), dir * cos(a));
      final endAngle = startAngle - dir * bendAngle;
      rx = cx + refR * cos(endAngle);
      ry = cy + refR * sin(endAngle);
      a += dir * bendAngle;
      curT = bend.endT;
    }

    // Straight segment (before first unprocessed bend, or after all bends)
    final d = (trackT - curT) * trackLength;
    final trackOff = baseX - _bendCenterX;
    return Offset(
      rx + trackOff * cos(a) - d * sin(a),
      ry - trackOff * sin(a) - d * cos(a),
    );
  }

  /// Track tangent angle at a given trackT position.
  /// Accumulates across all bends. Computed analytically.
  double trackAngleAtT(double trackT, double baseX) {
    double acc = 0.0;
    for (final bend in bends) {
      if (trackT <= bend.startT) return acc;
      final dir = -bend.direction.toDouble();
      if (trackT <= bend.endT) {
        final progress = (trackT - bend.startT) / (bend.endT - bend.startT);
        return acc + dir * progress * bendAngle;
      }
      acc += dir * bendAngle;
    }
    return acc;
  }

  void render(Canvas canvas) {
    _drawTrack(canvas, kLocalTrackX);
    _drawTrack(canvas, kExpressTrackX);
    _drawColumns(canvas);
    _renderDebris(canvas);
    _renderRats(canvas);

    for (final sp in switchPoints) {
      _drawSwitchZoneAtT(canvas, sp);
    }
    for (int i = 0; i < localStations.length; i++) {
      _drawStationAtT(canvas, localStations[i],
          trackX: kLocalTrackX,
          platLeft: kLocalPlatLeft,
          platRight: kLocalPlatRight);
    }
    for (int i = 0; i < expressStations.length; i++) {
      _drawStationAtT(canvas, expressStations[i],
          trackX: kExpressTrackX,
          platLeft: kExpressPlatLeft,
          platRight: kExpressPlatRight);
    }
    for (final obs in obstacles) {
      _drawObstacleAtT(canvas, obs);
    }
  }

  void _drawColumns(Canvas canvas) {
    // Support columns between the two tracks, evenly spaced along the track.
    const spacingPx = 120.0; // pixels between columns
    final nColumns = (trackLength / spacingPx).floor();
    final midX = _bendCenterX;

    final columnPaint = Paint()..color = const Color(0xFF555555);
    final highlightPaint = Paint()..color = const Color(0xFF6A6A6A);
    const radius = 5.0;

    for (int i = 1; i < nColumns; i++) {
      final t = i / nColumns;

      // Skip columns that overlap with switch zones
      final inSwitch = switchPoints.any((sp) =>
          t >= sp.trackPosition && t <= sp.trackPosition + sp.windowSize);
      if (inSwitch) continue;

      final pos = worldPosForT(t, midX);
      final angle = trackAngleAtT(t, midX);
      const half = 5.0;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      // Column body
      canvas.drawRect(Rect.fromLTWH(-half, -half, half * 2, half * 2), columnPaint);
      // Small highlight to give a 3D look
      canvas.drawRect(Rect.fromLTWH(-half, -half, half * 0.6, half * 2), highlightPaint);
      canvas.restore();
    }
  }

  void _drawTrack(Canvas canvas, double baseTrackX) {
    // Sample the track path at fine intervals along trackT [0, 1]
    const sampleStep = 4.0;
    final nSamples = (trackLength / sampleStep).ceil();

    final points = List.generate(nSamples + 1, (i) {
      final trackT = i / nSamples;
      return worldPosForT(trackT, baseTrackX);
    });

    // Tangents
    final tangents = List.generate(nSamples + 1, (i) {
      final prev = i > 0 ? points[i - 1] : points[i];
      final next = i < nSamples ? points[i + 1] : points[i];
      final d = next - prev;
      final len = sqrt(d.dx * d.dx + d.dy * d.dy);
      return len > 0 ? Offset(d.dx / len, d.dy / len) : const Offset(0, -1);
    });

    // Rail bed
    final bedPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 28.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round;
    final bedPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i <= nSamples; i++) {
      bedPath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(bedPath, bedPaint);

    // Cross-ties
    final tiePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 2;
    double arcAccum = 0;
    const tieSpacing = 20.0;
    for (int i = 1; i <= nSamples; i++) {
      final dx = points[i].dx - points[i - 1].dx;
      final dy = points[i].dy - points[i - 1].dy;
      arcAccum += sqrt(dx * dx + dy * dy);
      if (arcAccum >= tieSpacing) {
        arcAccum -= tieSpacing;
        final pt = points[i];
        final tan = tangents[i];
        final perpX = -tan.dy;
        final perpY = tan.dx;
        canvas.drawLine(
          Offset(pt.dx + perpX * 14, pt.dy + perpY * 14),
          Offset(pt.dx - perpX * 14, pt.dy - perpY * 14),
          tiePaint,
        );
      }
    }

    // Steel rails
    final railPaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const railOffset = 9.0;
    for (final sign in [-1.0, 1.0]) {
      final railPath = Path();
      for (int i = 0; i <= nSamples; i++) {
        final pt = points[i];
        final tan = tangents[i];
        final rx = pt.dx + (-tan.dy) * railOffset * sign;
        final ry = pt.dy + tan.dx * railOffset * sign;
        if (i == 0) {
          railPath.moveTo(rx, ry);
        } else {
          railPath.lineTo(rx, ry);
        }
      }
      canvas.drawPath(railPath, railPaint);
    }
  }

  void _drawSwitchZoneAtT(Canvas canvas, SwitchPoint sp) {
    // Midpoint of the switch in trackT
    final midT = sp.trackPosition + sp.windowSize / 2;
    final midTrackX = (kLocalTrackX + kExpressTrackX) / 2;
    final pos = worldPosForT(midT, midTrackX);
    final straightY = _worldY(midT);
    final tangentAngle = trackAngleAtT(midT, midTrackX);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(tangentAngle);
    canvas.translate(-midTrackX, -straightY);
    _drawSwitchZone(canvas, sp);
    canvas.restore();
  }

  void _drawSwitchZone(Canvas canvas, SwitchPoint sp) {
    final topY    = _worldY(sp.trackPosition);
    final bottomY = _worldY(sp.trackPosition + sp.windowSize);
    final height = topY - bottomY;

    // Draw both S-curves as railroad tracks (bed, ties, rails)
    _drawCurvedTrack(canvas, kLocalTrackX, topY, kExpressTrackX, bottomY, height);
    _drawCurvedTrack(canvas, kExpressTrackX, topY, kLocalTrackX, bottomY, height);
  }

  /// Evaluate a cubic Bézier at parameter t.
  static Offset _bezierAt(double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    final omt = 1 - t;
    return p0 * (omt * omt * omt) +
        p1 * (3 * omt * omt * t) +
        p2 * (3 * omt * t * t) +
        p3 * (t * t * t);
  }

  /// Draw an S-curve switch track with rail bed, cross-ties, and steel rails.
  void _drawCurvedTrack(Canvas canvas, double startX, double startY,
      double endX, double endY, double height) {
    final p0 = Offset(startX, startY);
    final p1 = Offset(startX, startY - height * 0.4);
    final p2 = Offset(endX, endY + height * 0.4);
    final p3 = Offset(endX, endY);

    // Sample points along the curve
    const nSamples = 40;
    final points = List.generate(nSamples + 1, (i) =>
        _bezierAt(i / nSamples, p0, p1, p2, p3));

    // Tangent at each point (for perpendicular ties)
    final tangents = List.generate(nSamples + 1, (i) {
      const eps = 0.001;
      final t = i / nSamples;
      final a = _bezierAt((t - eps).clamp(0.0, 1.0), p0, p1, p2, p3);
      final b = _bezierAt((t + eps).clamp(0.0, 1.0), p0, p1, p2, p3);
      final d = b - a;
      final len = sqrt(d.dx * d.dx + d.dy * d.dy);
      return len > 0 ? Offset(d.dx / len, d.dy / len) : const Offset(0, -1);
    });

    // 1. Rail bed — draw as a thick stroked path
    final bedPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 28.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bedPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i <= nSamples; i++) {
      bedPath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(bedPath, bedPaint);

    // 2. Cross-ties — perpendicular to curve, every ~20px of arc length
    final tiePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 2;
    double arcAccum = 0;
    const tieSpacing = 20.0;
    for (int i = 1; i <= nSamples; i++) {
      final dx = points[i].dx - points[i - 1].dx;
      final dy = points[i].dy - points[i - 1].dy;
      arcAccum += sqrt(dx * dx + dy * dy);
      if (arcAccum >= tieSpacing) {
        arcAccum -= tieSpacing;
        final pt = points[i];
        final tan = tangents[i];
        // Perpendicular direction
        final perpX = -tan.dy;
        final perpY = tan.dx;
        canvas.drawLine(
          Offset(pt.dx + perpX * 14, pt.dy + perpY * 14),
          Offset(pt.dx - perpX * 14, pt.dy - perpY * 14),
          tiePaint,
        );
      }
    }

    // 3. Steel rails — two lines offset perpendicular to the curve
    final railPaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    const railOffset = 9.0;
    for (final sign in [-1.0, 1.0]) {
      final railPath = Path();
      for (int i = 0; i <= nSamples; i++) {
        final pt = points[i];
        final tan = tangents[i];
        final rx = pt.dx + (-tan.dy) * railOffset * sign;
        final ry = pt.dy + tan.dx * railOffset * sign;
        if (i == 0) {
          railPath.moveTo(rx, ry);
        } else {
          railPath.lineTo(rx, ry);
        }
      }
      canvas.drawPath(railPath, railPaint..style = PaintingStyle.stroke);
    }
  }

  /// Draw a station at its worldPosForT position, rotated to follow the track
  /// tangent so it stays stationary relative to the track.
  void _drawStationAtT(Canvas canvas, Station station,
      {required double trackX, required double platLeft, required double platRight}) {
    final t = station.trackPosition;
    final pos = worldPosForT(t, trackX);
    final straightY = _worldY(t);
    final tangentAngle = trackAngleAtT(t, trackX);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(tangentAngle);
    canvas.translate(-trackX, -straightY);
    _drawStation(canvas, station, straightY,
        trackX: trackX, platLeft: platLeft, platRight: platRight);
    canvas.restore();
  }

  void _drawStation(Canvas canvas, Station station, double worldY,
      {required double trackX, required double platLeft, required double platRight}) {
    final paint = Paint();
    final platWidth = platRight - platLeft;

    paint.color = const Color(0xFF999999);
    canvas.drawRect(
      Rect.fromLTWH(platLeft, worldY - platformHalfLen, platWidth, platformHalfLen * 2),
      paint,
    );

    paint.color = const Color(0xFFFFCC00);
    canvas.drawRect(
      Rect.fromLTWH(platLeft, worldY - platformHalfLen, 5, platformHalfLen * 2),
      paint,
    );

    // Station name below the platform
    final namePainter = TextPainter(
      text: TextSpan(
        text: station.name,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: platWidth - 8);
    final nameX = platLeft + 8;
    final nameY = worldY - platformHalfLen - namePainter.height - 6;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(nameX - 4, nameY - 2, namePainter.width + 8, namePainter.height + 4),
      const Radius.circular(3),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xCC222222));
    namePainter.paint(canvas, Offset(nameX, nameY));

    // Draw waiting passengers as small human figures, randomly spread
    if (station.passengers > 0) {
      final areaLeft = platLeft + 8;
      final areaWidth = platWidth - 16;
      final areaTop = worldY - platformHalfLen + 8;
      final areaHeight = platformHalfLen * 2 - 28; // leave room for name at bottom
      // Draw last N figures (passengers board from the front of the list)
      final startIdx = station.figurePositions.length - station.passengers;
      for (int i = startIdx; i < station.figurePositions.length; i++) {
        final (xf, yf) = station.figurePositions[i];
        final fx = areaLeft + xf * areaWidth;
        final fy = areaTop + yf * areaHeight;
        _drawFigure(canvas, fx, fy);
      }
    }
  }

  void _drawFigure(Canvas canvas, double x, double y) {
    canvas.drawCircle(Offset(x, y), 6.0, Paint()..color = const Color(0xFFFFCBA4));
    canvas.drawCircle(Offset(x, y), 6.0, Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  void _drawObstacleAtT(Canvas canvas, Obstacle obs) {
    final t = obs.trackPosition;
    final trackX = obs.track == TrackType.local ? kLocalTrackX : kExpressTrackX;
    final pos = worldPosForT(t, trackX);
    final straightY = _worldY(t);
    final tangentAngle = trackAngleAtT(t, trackX);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(tangentAngle);
    canvas.translate(-trackX, -straightY);
    _drawObstacle(canvas, obs);
    canvas.restore();
  }

  void _drawObstacle(Canvas canvas, Obstacle obs) {
    final trackX = obs.track == TrackType.local ? kLocalTrackX : kExpressTrackX;
    final worldY = _worldY(obs.trackPosition);

    final bgPaint = Paint()..color = const Color(0xFFDD2200);
    canvas.drawRect(Rect.fromLTWH(trackX - 14, worldY - 18, 28, 36), bgPaint);

    final stripePaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..strokeWidth = 4;
    for (int i = -1; i <= 2; i++) {
      final sx = trackX - 14 + i * 14.0;
      canvas.drawLine(Offset(sx, worldY - 18), Offset(sx + 14, worldY + 18), stripePaint);
    }

    canvas.drawRect(
      Rect.fromLTWH(trackX - 14, worldY - 18, 28, 36),
      Paint()..color = const Color(0xAADD2200),
    );

    final xPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(trackX - 8, worldY - 10), Offset(trackX + 8, worldY + 10), xPaint);
    canvas.drawLine(Offset(trackX + 8, worldY - 10), Offset(trackX - 8, worldY + 10), xPaint);

    final glowPaint = Paint()
      ..color = const Color(0x44FF4400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRect(Rect.fromLTWH(trackX - 18, worldY - 22, 36, 44), glowPaint);
  }

  void _renderDebris(Canvas canvas) {
    for (final d in _debris) {
      final basePos = worldPosForT(d.trackT, d.trackX);
      final angle = trackAngleAtT(d.trackT, d.trackX);
      // Offset perpendicular to track
      final px = basePos.dx + d.offsetX * cos(angle);
      final py = basePos.dy - d.offsetX * sin(angle);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(d.rotation + angle);
      canvas.scale(1.8);

      switch (d.type) {
        case _DebrisType.groceryBag:
          // Crinkled plastic bag shape
          final bagPaint = Paint()..color = const Color(0xCCDDDDDD);
          final path = Path()
            ..moveTo(-5, -4)
            ..lineTo(-3, -6)
            ..lineTo(2, -5)
            ..lineTo(5, -3)
            ..lineTo(4, 2)
            ..lineTo(6, 5)
            ..lineTo(1, 4)
            ..lineTo(-2, 6)
            ..lineTo(-5, 3)
            ..lineTo(-6, -1)
            ..close();
          canvas.drawPath(path, bagPaint);
          // Bag handles
          final handlePaint = Paint()
            ..color = const Color(0x88AAAAAA)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8;
          canvas.drawOval(Rect.fromLTWH(-3, -8, 6, 4), handlePaint);
          break;

        case _DebrisType.sodaCup:
          // Cup body
          final cupPaint = Paint()..color = const Color(0xFFEEEEEE);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-3, -4, 6, 8),
              const Radius.circular(1),
            ),
            cupPaint,
          );
          // Colored band (brand stripe)
          canvas.drawRect(
            Rect.fromLTWH(-3, -1, 6, 3),
            Paint()..color = const Color(0xFFCC3333),
          );
          // Lid
          canvas.drawRect(
            Rect.fromLTWH(-3.5, -4.5, 7, 1.5),
            Paint()..color = const Color(0xFFCCCCCC),
          );
          break;
      }

      canvas.restore();
    }
  }

  void _renderRats(Canvas canvas) {
    for (final rat in _rats) {
      final basePos = worldPosForT(rat.trackT, rat.trackX);
      final trackAngle = trackAngleAtT(rat.trackT, rat.trackX);
      final px = basePos.dx + (rat.offsetX + rat.localX) * cos(trackAngle);
      final py = basePos.dy - (rat.offsetX + rat.localX) * sin(trackAngle);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rat.heading + trackAngle);
      canvas.scale(1.8);

      // Body
      final bodyPaint = Paint()..color = const Color(0xFF4A4040);
      canvas.drawOval(Rect.fromLTWH(-4, -2.5, 8, 5), bodyPaint);
      // Head
      canvas.drawOval(Rect.fromLTWH(3, -1.5, 4, 3), bodyPaint);
      // Ears
      final earPaint = Paint()..color = const Color(0xFF5A5050);
      canvas.drawCircle(const Offset(5.5, -2), 1.2, earPaint);
      canvas.drawCircle(const Offset(5.5, 2), 1.2, earPaint);
      // Tail
      final tailPaint = Paint()
        ..color = const Color(0xFF6A5A5A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;
      final tailPath = Path()
        ..moveTo(-4, 0)
        ..cubicTo(-7, -2, -9, 1, -11, -1);
      canvas.drawPath(tailPath, tailPaint);
      // Eyes
      canvas.drawCircle(const Offset(5.5, -0.5), 0.6, Paint()..color = Colors.black);
      canvas.drawCircle(const Offset(5.5, 0.5), 0.6, Paint()..color = Colors.black);

      canvas.restore();
    }
  }
}

// ── Debris ───────────────────────────────────────────────────────────────────

enum _DebrisType { groceryBag, sodaCup }

class _Debris {
  final double trackT;
  final double trackX;
  final double offsetX;
  final _DebrisType type;
  final double rotation;

  const _Debris({
    required this.trackT,
    required this.trackX,
    required this.offsetX,
    required this.type,
    required this.rotation,
  });
}

// ── Rats ─────────────────────────────────────────────────────────────────────

class _Rat {
  final double trackT;
  final double trackX;
  final double offsetX;
  double heading;
  double localX = 0; // small lateral wander
  double _moveTimer = 0;
  double idleTimer;
  double _targetHeading = 0;
  bool _moving = false;
  final Random rng;

  _Rat({
    required this.trackT,
    required this.trackX,
    required this.offsetX,
    required this.heading,
    required this.idleTimer,
    required this.rng,
  });

  void update(double dt) {
    if (_moving) {
      // Scurry in current heading direction
      localX += cos(heading) * 20 * dt;
      localX = localX.clamp(-12, 12);
      // Smoothly turn toward target
      final diff = _targetHeading - heading;
      heading += diff * 4 * dt;
      _moveTimer -= dt;
      if (_moveTimer <= 0) {
        _moving = false;
        idleTimer = 1.0 + rng.nextDouble() * 4.0;
      }
    } else {
      idleTimer -= dt;
      if (idleTimer <= 0) {
        _moving = true;
        _moveTimer = 0.3 + rng.nextDouble() * 0.8;
        _targetHeading = rng.nextDouble() * pi * 2;
      }
    }
  }
}
