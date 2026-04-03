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
const double kLocalPlatLeft    = kLocalTrackX + 16.0;
const double kLocalPlatRight   = 365.0;

class MapComponent {
  final List<Station> localStations;
  final List<Station> expressStations;
  final List<SwitchPoint> switchPoints;
  final List<Obstacle> obstacles;
  final double platformHalfLen;
  final double trackLength;
  final double trackBottomY;

  // Bend
  final double bendStartT;
  final double bendEndT;
  final bool hasBend;

  MapComponent({
    required this.localStations,
    required this.expressStations,
    required this.switchPoints,
    required this.obstacles,
    required this.trackLength,
    required this.trackBottomY,
    this.platformHalfLen = 130.0,
    this.bendStartT = 0,
    this.bendEndT = 0,
    this.hasBend = false,
  });

  double _worldY(double trackT) => trackBottomY - trackT * trackLength;

  /// Reference X used as the arc center for bends (midpoint of the two tracks).
  static const double _bendCenterX = (kLocalTrackX + kExpressTrackX) / 2;

  /// World position for a trackT, accounting for the 90° left bend.
  /// Both tracks curve around a shared center so they remain parallel
  /// (concentric arcs with different radii).
  Offset worldPosForT(double trackT, double baseX) {
    if (!hasBend || trackT <= bendStartT) {
      return Offset(baseX, _worldY(trackT));
    }

    final bendStartY = _worldY(bendStartT);
    final bendPixels = (bendEndT - bendStartT) * trackLength;
    // Reference radius for the midpoint track
    final refRadius = bendPixels * 2 / pi;
    // Per-track radius: offset from the shared center
    // Center is to the left of _bendCenterX by refRadius
    final cx = _bendCenterX - refRadius;
    final cy = bendStartY;
    final radius = baseX - cx; // larger for tracks further right

    if (trackT >= bendEndT) {
      // After the bend: horizontal continuation to the left
      final overshoot = (trackT - bendEndT) * trackLength;
      return Offset(cx - overshoot, cy - radius);
    }

    // During the bend: quarter-circle arc
    final bendProgress = (trackT - bendStartT) / (bendEndT - bendStartT);
    final angle = bendProgress * pi / 2;
    return Offset(cx + radius * cos(angle), cy - radius * sin(angle));
  }

  /// Track tangent angle at a given trackT position.
  /// Returns 0 for straight (upward) sections, pi/2 after the bend (leftward).
  double trackAngleAtT(double trackT, double baseX) {
    const eps = 0.0001;
    final posA = worldPosForT(trackT + eps, baseX);
    final posB = worldPosForT(trackT - eps, baseX);
    final dx = posA.dx - posB.dx;
    final dy = posA.dy - posB.dy;
    // atan2(dx, -dy) gives 0 when direction is (0, -1) i.e. upward
    return atan2(dx, -dy);
  }

  void render(Canvas canvas) {
    _drawTrack(canvas, kLocalTrackX);
    _drawTrack(canvas, kExpressTrackX);

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
      ..color = const Color(0xFF3D2B1A)
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
      ..color = const Color(0xFF3D2B1A)
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

    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(trackX, worldY), 7, paint);
    paint
      ..color = station.track == TrackType.express
          ? const Color(0xFFAA4400)
          : const Color(0xFF0039A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(trackX, worldY), 7, paint);
    paint.style = PaintingStyle.fill;

    final namePainter = TextPainter(
      text: TextSpan(
        text: station.name,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: platWidth - 24);
    namePainter.paint(canvas, Offset(platLeft + 8, worldY + platformHalfLen - namePainter.height - 6));

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
    canvas.drawCircle(Offset(x, y), 4.0, Paint()..color = const Color(0xFFFFCBA4));
    canvas.drawCircle(Offset(x, y), 4.0, Paint()
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
}
