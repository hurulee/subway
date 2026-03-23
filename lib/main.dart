import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'game/subway_game.dart';
import 'game/models.dart';

void main() {
  runApp(const SubwayApp());
}

class SubwayApp extends StatelessWidget {
  const SubwayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SubwayGame _game;

  @override
  void initState() {
    super.initState();
    _game = SubwayGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':           (context, game) => HudOverlay(game: game as SubwayGame),
          'brake':         (context, game) => BrakeButton(game: game as SubwayGame),
          'switch':        (context, game) => SwitchButton(game: game as SubwayGame),
          'levelComplete': (context, game) => LevelCompleteOverlay(game: game as SubwayGame),
        },
        initialActiveOverlays: const ['hud', 'brake', 'switch'],
      ),
    );
  }
}

class HudOverlay extends StatelessWidget {
  final SubwayGame game;
  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HudData>(
      valueListenable: game.hudNotifier,
      builder: (context, data, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _hudPill('Passengers: ${data.passengers}', Colors.green),
                  _hudPill('Time: ${data.elapsed.toStringAsFixed(1)}s', Colors.blue),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (data.nextStation.isNotEmpty)
                    _hudPill('Next: ${data.nextStation}', Colors.orange),
                  const SizedBox(width: 8),
                  _hudPill(
                    data.currentTrack == TrackType.express ? 'EXPRESS' : 'LOCAL',
                    data.currentTrack == TrackType.express
                        ? const Color(0xFFCC4400)
                        : const Color(0xFF0039A6),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hudPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class BrakeButton extends StatelessWidget {
  final SubwayGame game;
  const BrakeButton({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: GestureDetector(
          onTapDown: (_) => game.setBraking(true),
          onTapUp: (_) => game.setBraking(false),
          onTapCancel: () => game.setBraking(false),
          child: ValueListenableBuilder<bool>(
            valueListenable: game.brakingNotifier,
            builder: (context, braking, _) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: braking ? Colors.red : Colors.red.shade800,
                  boxShadow: braking
                      ? [BoxShadow(
                          color: Colors.red.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 5)]
                      : [],
                ),
                child: const Center(
                  child: Text('BRAKE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SwitchButton extends StatelessWidget {
  final SubwayGame game;
  const SwitchButton({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40, right: 20),
        child: ValueListenableBuilder<bool>(
          valueListenable: game.switchAvailableNotifier,
          builder: (context, available, _) {
            return GestureDetector(
              onTap: available ? () => game.requestSwitch() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: available
                      ? const Color(0xFFFFAA00)
                      : Colors.grey.shade800,
                  boxShadow: available
                      ? [BoxShadow(
                          color: const Color(0xFFFFAA00).withValues(alpha: 0.6),
                          blurRadius: 18,
                          spreadRadius: 4)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'SWITCH\nTRACK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: available ? Colors.black : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LevelCompleteOverlay extends StatelessWidget {
  final SubwayGame game;
  const LevelCompleteOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.yellow, width: 2),
        ),
        child: ValueListenableBuilder<HudData>(
          valueListenable: game.hudNotifier,
          builder: (context, data, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Level Complete!',
                    style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Passengers: ${data.passengers}  (+${data.passengerScore} pts)',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                Text('Time: ${data.elapsed.toStringAsFixed(1)}s  (+${data.timeBonus} pts)',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const Divider(color: Colors.yellow, height: 32),
                Text('Total Score: ${data.totalScore}',
                    style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => game.restartLevel(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black),
                  child: const Text('Play Again',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
