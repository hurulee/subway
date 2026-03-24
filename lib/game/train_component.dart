import 'package:flutter/material.dart';
import 'dart:math';

class TrainComponent {
  double speed = 0.0;
  static const double maxSpeed = 280.0;
  static const double brakeDeceleration = 200.0;
  static const double naturalDeceleration = 18.0;
  static const double acceleration = 120.0;
  bool isBraking = false;
  double targetSpeed = 0.0;
  double trackT = 0.0;

  // Lane / switch animation  (0.0 = local, 1.0 = express)
  double laneOffset = 0.0;
  bool isSwitching = false;
  static const double switchDuration = 0.7;
  double _switchProgress = 0.0;
  double _switchStartOffset = 0.0;
  double _switchTargetOffset = 0.0;

  void switchToTrack(double targetLaneOffset) {
    if (isSwitching) return;
    _switchStartOffset = laneOffset;
    _switchTargetOffset = targetLaneOffset;
    _switchProgress = 0.0;
    isSwitching = true;
  }

  /// Tilt angle (radians) — peaks at midpoint of switch, used by caller for rotation.
  double get switchTiltAngle {
    if (!isSwitching) return 0.0;
    return sin(pi * _switchProgress) *
        (_switchTargetOffset > _switchStartOffset ? 1 : -1) *
        0.14; // ~8 degrees
  }

  // Car dimensions (top-down view)
  static const double carW = 28.0;
  static const double carH = 55.0;
  static const double couplingGap = 6.0;
  static const int numCars = 4;

  // Total bounding box
  static const double w = carW;
  static const double h = numCars * carH + (numCars - 1) * couplingGap; // 238

  final List<_Spark> _sparks = [];
  final Random _rng = Random();

  void update(double dt) {
    // Switch lane animation
    if (isSwitching) {
      _switchProgress += dt / switchDuration;
      if (_switchProgress >= 1.0) {
        _switchProgress = 1.0;
        laneOffset = _switchTargetOffset;
        isSwitching = false;
      } else {
        final t = _switchProgress;
        final eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
        laneOffset = _switchStartOffset +
            (_switchTargetOffset - _switchStartOffset) * eased;
      }
    }

    if (isBraking) {
      speed -= brakeDeceleration * dt;
      if (speed > 10) {
        // Sparks from rear of train (bottom)
        for (int i = 0; i < 3; i++) {
          _sparks.add(_Spark(
            dx: (_rng.nextDouble() - 0.5) * w * 0.8,
            dy: h / 2 + _rng.nextDouble() * 10,
            vx: (_rng.nextDouble() - 0.5) * 50,
            vy: _rng.nextDouble() * 60 + 20,
            life: _rng.nextDouble() * 0.25 + 0.1,
          ));
        }
      }
    } else if (speed < targetSpeed) {
      speed += acceleration * dt;
      if (speed > targetSpeed) speed = targetSpeed;
    } else if (speed > targetSpeed) {
      speed -= naturalDeceleration * dt;
      if (speed < targetSpeed) speed = targetSpeed;
    }
    speed = max(0, min(speed, maxSpeed));

    _sparks.removeWhere((s) => s.life <= 0);
    for (final s in _sparks) {
      s.dx += s.vx * dt;
      s.dy += s.vy * dt;
      s.life -= dt;
    }
  }

  /// Render with origin at top-left of the train bounding box.
  void render(Canvas canvas) {
    for (int i = 0; i < numCars; i++) {
      final carTop = i * (carH + couplingGap);
      _drawCar(canvas, carTop, isFront: i == 0, isRear: i == numCars - 1);

      // Coupling between cars
      if (i < numCars - 1) {
        _drawCoupling(canvas, carTop + carH);
      }
    }

    // Sparks at rear
    final sparkPaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final s in _sparks) {
      final alpha = (s.life / 0.35).clamp(0.0, 1.0);
      sparkPaint.color = Color.fromRGBO(255, 210, 60, alpha);
      canvas.drawLine(
        Offset(w / 2 + s.dx, h / 2 + s.dy),
        Offset(w / 2 + s.dx - s.vx * 0.015, h / 2 + s.dy - s.vy * 0.015),
        sparkPaint,
      );
    }
  }

  void _drawCar(Canvas canvas, double top, {bool isFront = false, bool isRear = false}) {
    final paint = Paint();

    // Body
    paint.color = const Color(0xFFD8D8D8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, carW, carH), const Radius.circular(4)),
      paint,
    );

    // Blue MTA stripe
    paint.color = const Color(0xFF0039A6);
    canvas.drawRect(Rect.fromLTWH(0, top + carH * 0.35, carW, carH * 0.12), paint);

    if (isFront) {
      // Front cab (top = direction of travel)
      paint.color = const Color(0xFF444444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(2, top + 2, carW - 4, carH * 0.16),
            const Radius.circular(3)),
        paint,
      );
      // Headlights
      paint.color = const Color(0xFFFFFF99);
      canvas.drawCircle(Offset(carW * 0.28, top + carH * 0.08), 3, paint);
      canvas.drawCircle(Offset(carW * 0.72, top + carH * 0.08), 3, paint);
    }

    if (isRear) {
      // Rear end marker lights
      paint.color = const Color(0xFFCC0000);
      canvas.drawCircle(Offset(carW * 0.28, top + carH * 0.92), 3, paint);
      canvas.drawCircle(Offset(carW * 0.72, top + carH * 0.92), 3, paint);
    }

    // Roof panel
    paint.color = const Color(0xFFAAAAAA);
    final roofTop = isFront ? top + carH * 0.22 : top + carH * 0.08;
    final roofBottom = isRear ? top + carH * 0.84 : top + carH * 0.92;
    canvas.drawRect(
        Rect.fromLTWH(4, roofTop, carW - 8, roofBottom - roofTop), paint);

    // Bogies
    _drawBogie(canvas, carW / 2, top + carH * 0.2);
    _drawBogie(canvas, carW / 2, top + carH * 0.8);
  }

  void _drawCoupling(Canvas canvas, double y) {
    final paint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(carW * 0.35, y), Offset(carW * 0.35, y + couplingGap), paint);
    canvas.drawLine(
        Offset(carW * 0.65, y), Offset(carW * 0.65, y + couplingGap), paint);
  }

  void _drawBogie(Canvas canvas, double cx, double cy) {
    final paint = Paint()..color = const Color(0xFF333333);
    canvas.drawRect(Rect.fromLTWH(cx - 10, cy - 4, 20, 8), paint);
    paint.color = const Color(0xFF222222);
    canvas.drawCircle(Offset(cx - 8, cy), 4, paint);
    canvas.drawCircle(Offset(cx + 8, cy), 4, paint);
  }
}

class _Spark {
  double dx, dy, vx, vy, life;
  _Spark(
      {required this.dx,
      required this.dy,
      required this.vx,
      required this.vy,
      required this.life});
}
