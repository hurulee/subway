import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'game/subway_game.dart';
import 'game/models.dart';
import 'game/line_data.dart';

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
          'readyToStart':  (context, game) => ReadyToStartOverlay(game: game as SubwayGame),
          'levelComplete': (context, game) => LevelCompleteOverlay(game: game as SubwayGame),
          'gameComplete':  (context, game) => GameCompleteOverlay(game: game as SubwayGame),
          'gameOver':      (context, game) => GameOverOverlay(game: game as SubwayGame),
        },
        initialActiveOverlays: const ['hud', 'brake', 'switch'],
      ),
    );
  }
}

class HudOverlay extends StatelessWidget {
  final SubwayGame game;
  const HudOverlay({super.key, required this.game});

  LineInfo? get _lineInfo {
    try {
      return kLines.firstWhere((l) => l.assetPath == game.routeAsset);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineInfo = _lineInfo;
    return ValueListenableBuilder<HudData>(
      valueListenable: game.hudNotifier,
      builder: (context, data, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _hudPill('${data.passengers}', Colors.green),
                  const SizedBox(width: 6),
                  _hearts(data.lives, data.maxLives),
                  const SizedBox(width: 6),
                  if (lineInfo != null) ...[_lineBullet(lineInfo), const SizedBox(width: 6)],
                  _hudPill('LVL ${data.level}', Colors.purple),
                  const Spacer(),
                  _hudPill('${data.elapsed.toStringAsFixed(1)}s', Colors.blue),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _hudPill(
                    data.currentTrack == TrackType.express ? 'EXPRESS' : 'LOCAL',
                    data.currentTrack == TrackType.express
                        ? const Color(0xFFCC4400)
                        : const Color(0xFF0039A6),
                  ),
                  if (data.nextStation.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: _hudPill('Next: ${data.nextStation}', Colors.orange),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _signalLight('EXPRESS', data.expressSignal),
                  const SizedBox(width: 10),
                  _signalLight('LOCAL', data.localSignal),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _lineBullet(LineInfo info) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: info.bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: info.bg.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          info.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: info.fg,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _signalLight(String label, SignalColor signal) {
    final isGreen = signal == SignalColor.green;
    final color = isGreen ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _hearts(int lives, int maxLives) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (i) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          i < lives ? Icons.favorite : Icons.favorite_border,
          color: Colors.red,
          size: 22,
        ),
      )),
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

class ReadyToStartOverlay extends StatelessWidget {
  final SubwayGame game;
  const ReadyToStartOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: ElevatedButton(
          onPressed: () => game.startLevel(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          child: Text(
            'START  LVL ${game.currentLevelNumber}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
                Text('Level ${data.level} Complete!',
                    style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Passengers: ${data.passengers}  (+${data.passengerScore} pts)',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                Text('Time: ${data.elapsed.toStringAsFixed(1)}s  (+${data.timeBonus} pts)',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                if (data.penaltyCount > 0)
                  Text(
                    '${data.penaltyCount}× obstacle  (−${data.penaltyDeduction} pts)',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                const Divider(color: Colors.yellow, height: 32),
                Text('Level Score: ${data.totalScore}',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Total Score: ${game.totalScore}',
                    style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => game.proceedToNextLevel(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black),
                  child: const Text('Next Level',
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

class GameCompleteOverlay extends StatelessWidget {
  final SubwayGame game;
  const GameCompleteOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏁  Game Complete!',
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 30,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('All 15 rounds cleared',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(color: Colors.amber, height: 40),
            ValueListenableBuilder<HudData>(
              valueListenable: game.hudNotifier,
              builder: (context, data, _) => Column(
                children: [
                  Text('Last Level Score: ${data.totalScore}',
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Total Score: ${game.totalScore}',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => game.restartGame(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: const Text('Play Again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final SubwayGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Game Over',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 30,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Level ${game.currentLevelNumber}',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Total Score: ${game.totalScore}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    game.overlays.remove('gameOver');
                    game.overlays.add('brake');
                    game.overlays.add('switch');
                    game.restartLevel();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                  child: const Text('Retry Level',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () => game.restartGame(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text('Restart Game',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
