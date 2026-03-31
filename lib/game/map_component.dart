import 'package:flutter/material.dart';
import 'models.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double kExpressTrackX = 80.0;
const double kLocalTrackX   = 210.0;
const double kTrackTopY     = 100.0;

// Pixel distance between adjacent stations (derived from original 7-station setup:
// 0.96 * 5400px / 6 gaps = 864px per gap; 864 / 0.96 = 900 per unit).
const double kStationSpacing = 864.0;

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

  late final List<double> _localYs;
  late final List<double> _expressYs;

  MapComponent({
    required this.localStations,
    required this.expressStations,
    required this.switchPoints,
    required this.obstacles,
    required this.trackLength,
    required this.trackBottomY,
    this.platformHalfLen = 130.0,
  }) {
    _localYs   = localStations.map((s) => _worldY(s.trackPosition)).toList();
    _expressYs = expressStations.map((s) => _worldY(s.trackPosition)).toList();
  }

  double _worldY(double trackT) => trackBottomY - trackT * trackLength;

  void render(Canvas canvas) {
    _drawTrack(canvas, kLocalTrackX);
    _drawTrack(canvas, kExpressTrackX);

    for (final sp in switchPoints) {
      _drawSwitchZone(canvas, sp);
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
    for (final obs in obstacles) {
      _drawObstacle(canvas, obs);
    }
  }

  void _drawTrack(Canvas canvas, double trackX) {
    canvas.drawRect(
      Rect.fromLTWH(trackX - 16, kTrackTopY, 32, trackLength),
      Paint()..color = const Color(0xFF2A2A2A),
    );
    final tiePaint = Paint()
      ..color = const Color(0xFF3D2B1A)
      ..strokeWidth = 2;
    const tieStep = 20.0;
    final tieCount = (trackLength / tieStep).ceil();
    for (int i = 0; i <= tieCount; i++) {
      final y = kTrackTopY + i * tieStep;
      canvas.drawLine(Offset(trackX - 14, y), Offset(trackX + 14, y), tiePaint);
    }
    final railPaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(trackX - 9, kTrackTopY), Offset(trackX - 9, trackBottomY), railPaint);
    canvas.drawLine(Offset(trackX + 9, kTrackTopY), Offset(trackX + 9, trackBottomY), railPaint);
  }

  void _drawSwitchZone(Canvas canvas, SwitchPoint sp) {
    final topY    = _worldY(sp.trackPosition);
    final bottomY = _worldY(sp.trackPosition + sp.windowSize);
    final midY = (topY + bottomY) / 2;
    final midX = (kLocalTrackX + kExpressTrackX) / 2;

    final linePaint = Paint()
      ..color = const Color(0xFFFFDD00).withValues(alpha: 0.6)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(kLocalTrackX, topY),   Offset(kExpressTrackX, bottomY), linePaint);
    canvas.drawLine(Offset(kExpressTrackX, topY), Offset(kLocalTrackX, bottomY),   linePaint);

    final path = Path()
      ..moveTo(midX, midY - 10)
      ..lineTo(midX + 9, midY)
      ..lineTo(midX, midY + 10)
      ..lineTo(midX - 9, midY)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFDD00));

    final tp = TextPainter(
      text: const TextSpan(
        text: 'SW',
        style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(midX - tp.width / 2, midY - tp.height / 2));
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
    final paint = Paint()..color = const Color(0xFFEEEEEE);
    // Head
    canvas.drawCircle(Offset(x, y), 3.0, paint);
    // Body
    canvas.drawLine(Offset(x, y + 3), Offset(x, y + 10),
        paint..strokeWidth = 1.5..style = PaintingStyle.stroke);
    // Arms
    canvas.drawLine(Offset(x - 3, y + 6), Offset(x + 3, y + 6), paint);
    // Legs
    canvas.drawLine(Offset(x, y + 10), Offset(x - 2.5, y + 15), paint);
    canvas.drawLine(Offset(x, y + 10), Offset(x + 2.5, y + 15), paint);
    paint.style = PaintingStyle.fill;
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
