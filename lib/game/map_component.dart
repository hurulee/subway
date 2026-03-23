import 'package:flutter/material.dart';
import 'dart:math';
import 'models.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double kExpressTrackX = 80.0;
const double kLocalTrackX   = 210.0;
const double kTrackTopY     = 100.0;
const double kTrackBottomY  = 4200.0;
const double kTrackLength   = kTrackBottomY - kTrackTopY;

// Express platform sits in the gap between the two tracks
const double kExpressPlatLeft  = kExpressTrackX + 16.0; //  96
const double kExpressPlatRight = kLocalTrackX - 16.0;   // 194

// Local platform is to the right of the local track
const double kLocalPlatLeft  = kLocalTrackX + 16.0;     // 226
const double kLocalPlatRight = 365.0;

const double kPlatformHalfLen = 130.0;

double stationWorldY(double trackT) => kTrackBottomY - trackT * kTrackLength;

class MapComponent {
  final List<Station> localStations;
  final List<Station> expressStations;
  final List<SwitchPoint> switchPoints;

  late final List<double> _localYs;
  late final List<double> _expressYs;
  late final List<double> _switchYs;

  MapComponent({
    required this.localStations,
    required this.expressStations,
    required this.switchPoints,
  }) {
    _localYs   = localStations.map((s) => stationWorldY(s.trackPosition)).toList();
    _expressYs = expressStations.map((s) => stationWorldY(s.trackPosition)).toList();
    _switchYs  = switchPoints.map((sp) => stationWorldY(sp.trackPosition + sp.windowSize / 2)).toList();
  }

  void render(Canvas canvas) {
    _drawTrack(canvas, kLocalTrackX);
    _drawTrack(canvas, kExpressTrackX);

    for (int i = 0; i < switchPoints.length; i++) {
      _drawSwitchZone(canvas, switchPoints[i]);
    }
    for (int i = 0; i < localStations.length; i++) {
      _drawStation(canvas, localStations[i], _localYs[i],
          trackX: kLocalTrackX,
          platLeft: kLocalPlatLeft,
          platRight: kLocalPlatRight);
    }
    for (int i = 0; i < expressStations.length; i++) {
      _drawStation(canvas, expressStations[i], _expressYs[i],
          trackX: kExpressTrackX,
          platLeft: kExpressPlatLeft,
          platRight: kExpressPlatRight);
    }
  }

  void _drawTrack(Canvas canvas, double trackX) {
    // Tunnel floor
    canvas.drawRect(
      Rect.fromLTWH(trackX - 16, kTrackTopY, 32, kTrackLength),
      Paint()..color = const Color(0xFF2A2A2A),
    );

    // Rail ties
    final tiePaint = Paint()
      ..color = const Color(0xFF3D2B1A)
      ..strokeWidth = 2;
    const tieStep = 20.0;
    final tieCount = (kTrackLength / tieStep).ceil();
    for (int i = 0; i <= tieCount; i++) {
      final y = kTrackTopY + i * tieStep;
      canvas.drawLine(Offset(trackX - 14, y), Offset(trackX + 14, y), tiePaint);
    }

    // Rails
    final railPaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(trackX - 9, kTrackTopY), Offset(trackX - 9, kTrackBottomY), railPaint);
    canvas.drawLine(Offset(trackX + 9, kTrackTopY), Offset(trackX + 9, kTrackBottomY), railPaint);
  }

  void _drawSwitchZone(Canvas canvas, SwitchPoint sp) {
    final topY    = stationWorldY(sp.trackPosition);
    final bottomY = stationWorldY(sp.trackPosition + sp.windowSize);
    final midY    = (topY + bottomY) / 2;
    final midX    = (kLocalTrackX + kExpressTrackX) / 2;

    final linePaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.6)
      ..strokeWidth = 2.0;

    // Diagonal crossover lines
    canvas.drawLine(Offset(kLocalTrackX, topY),    Offset(kExpressTrackX, bottomY), linePaint);
    canvas.drawLine(Offset(kExpressTrackX, topY),  Offset(kLocalTrackX, bottomY),   linePaint);

    // Diamond marker at midpoint
    final path = Path()
      ..moveTo(midX, midY - 10)
      ..lineTo(midX + 9, midY)
      ..lineTo(midX, midY + 10)
      ..lineTo(midX - 9, midY)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFDD00));

    // "SW" label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SW',
        style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(midX - tp.width / 2, midY - tp.height / 2));
  }

  void _drawStation(
    Canvas canvas,
    Station station,
    double worldY, {
    required double trackX,
    required double platLeft,
    required double platRight,
  }) {
    final paint = Paint();
    final platWidth = platRight - platLeft;

    // Platform body
    paint.color = const Color(0xFF999999);
    canvas.drawRect(
      Rect.fromLTWH(platLeft, worldY - kPlatformHalfLen, platWidth, kPlatformHalfLen * 2),
      paint,
    );

    // Yellow safety edge
    paint.color = const Color(0xFFFFCC00);
    canvas.drawRect(
      Rect.fromLTWH(platLeft, worldY - kPlatformHalfLen, 5, kPlatformHalfLen * 2),
      paint,
    );

    // Track dot
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

    // Station name
    final namePainter = TextPainter(
      text: TextSpan(
        text: station.name,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: platWidth - 24);
    namePainter.paint(
        canvas, Offset(platLeft + 8, worldY - namePainter.height / 2));

    // Passenger badge
    if (station.passengers > 0) {
      final badgeX = platRight - 16;
      paint.color = station.track == TrackType.express
          ? const Color(0xFFFF6600)
          : const Color(0xFFFFCC00);
      canvas.drawCircle(Offset(badgeX, worldY), 13, paint);
      final numPainter = TextPainter(
        text: TextSpan(
          text: '${station.passengers}',
          style: const TextStyle(
              color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numPainter.paint(canvas,
          Offset(badgeX - numPainter.width / 2, worldY - numPainter.height / 2));
    }
  }
}
