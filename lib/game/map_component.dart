import 'package:flutter/material.dart';
import 'models.dart';

// Shared layout constants
const double kTrackX = 130.0;
const double kTrackTopY = 100.0;
const double kTrackBottomY = 2800.0;
const double kTrackLength = kTrackBottomY - kTrackTopY;

const double kPlatformLeft = kTrackX + 18.0;
const double kPlatformRight = kPlatformLeft + 180.0;
const double kPlatformHalfLen = 130.0;

double stationWorldY(double trackT) =>
    kTrackBottomY - trackT * kTrackLength;

class MapComponent {
  final List<Station> stations;
  late final List<double> stationYs;

  MapComponent({required this.stations}) {
    stationYs = stations.map((s) => stationWorldY(s.trackPosition)).toList();
  }

  /// Render in world space. Canvas has already been translated by the caller.
  void render(Canvas canvas) {
    _drawTrack(canvas);
    for (int i = 0; i < stations.length; i++) {
      _drawStation(canvas, stations[i], stationYs[i]);
    }
  }

  void _drawTrack(Canvas canvas) {
    // Tunnel floor between rails
    canvas.drawRect(
      Rect.fromLTWH(kTrackX - 16, kTrackTopY, 32, kTrackLength),
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
      canvas.drawLine(
          Offset(kTrackX - 14, y), Offset(kTrackX + 14, y), tiePaint);
    }

    // Rails
    final railPaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(kTrackX - 9, kTrackTopY),
        Offset(kTrackX - 9, kTrackBottomY), railPaint);
    canvas.drawLine(Offset(kTrackX + 9, kTrackTopY),
        Offset(kTrackX + 9, kTrackBottomY), railPaint);
  }

  void _drawStation(Canvas canvas, Station station, double worldY) {
    final paint = Paint();

    // Platform body
    paint.color = const Color(0xFF999999);
    canvas.drawRect(
      Rect.fromLTWH(kPlatformLeft, worldY - kPlatformHalfLen,
          kPlatformRight - kPlatformLeft, kPlatformHalfLen * 2),
      paint,
    );

    // Yellow safety edge
    paint.color = const Color(0xFFFFCC00);
    canvas.drawRect(
      Rect.fromLTWH(kPlatformLeft, worldY - kPlatformHalfLen,
          6, kPlatformHalfLen * 2),
      paint,
    );

    // Station dot on track
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(kTrackX, worldY), 8, paint);
    paint.color = const Color(0xFF0039A6);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.5;
    canvas.drawCircle(Offset(kTrackX, worldY), 8, paint);
    paint.style = PaintingStyle.fill;

    // Station name
    final namePainter = TextPainter(
      text: TextSpan(
        text: station.name,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: kPlatformRight - kPlatformLeft - 16);
    namePainter.paint(
        canvas, Offset(kPlatformLeft + 12, worldY - namePainter.height / 2));

    // Passenger badge
    if (station.passengers > 0) {
      final badgeX = kPlatformRight - 22;
      paint.color = const Color(0xFFFFCC00);
      canvas.drawCircle(Offset(badgeX, worldY), 14, paint);
      final numPainter = TextPainter(
        text: TextSpan(
          text: '${station.passengers}',
          style: const TextStyle(
              color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numPainter.paint(canvas,
          Offset(badgeX - numPainter.width / 2, worldY - numPainter.height / 2));
    }
  }
}
