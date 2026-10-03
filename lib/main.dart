import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/game_core.dart';
import 'core/game_session.dart';

void main() {
  runApp(const WahaMatch3App());
}

class WahaMatch3App extends StatelessWidget {
  const WahaMatch3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waha Match-3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFBFA76A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111318),
        useMaterial3: true,
      ),
      home: const WahaHomePage(),
    );
  }
}

class WahaHomePage extends StatefulWidget {
  const WahaHomePage({super.key});

  @override
  State<WahaHomePage> createState() => _WahaHomePageState();
}

class _WahaHomePageState extends State<WahaHomePage> {
  final AudioPlayer _musicPlayer = AudioPlayer();

  GameSession? _session;
  bool _isPlaying = false;
  bool _inputLocked = false;
  String? _message;
  Set<BoardPosition> _vanishingPositions = {};

  void _startGame() {
    setState(() {
      _session ??= GameSession.newGame();
      _isPlaying = true;
      _message = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
    unawaited(_syncBackgroundMusic());
  }

  void _goHome() {
    setState(() {
      _isPlaying = false;
      _message = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
    unawaited(_syncBackgroundMusic());
  }

  void _nextLevel() {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      session.startNextLevel();
      _message = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
  }

  void _toggleSound() {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      session.setSoundEnabled(!session.soundEnabled);
    });
    unawaited(_syncBackgroundMusic());
  }

  Future<void> _syncBackgroundMusic() async {
    final session = _session;
    if (_isPlaying && session != null && session.soundEnabled) {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.35);
      await _musicPlayer.play(AssetSource('audio/background.mp3'));
    } else {
      await _musicPlayer.stop();
    }
  }

  Future<void> _handleSwipe(BoardPosition position, Direction direction) async {
    final session = _session;
    if (session == null || session.isLevelComplete || _inputLocked) {
      return;
    }

    final before = session.board.cells;
    late final MoveResult result;
    setState(() {
      _inputLocked = true;
      _vanishingPositions = {};
      result = session.swipe(position, direction);
      if (!result.accepted) {
        _message = 'Ход не собрал 3 в ряд';
        _inputLocked = false;
      } else if (result.reshuffled) {
        _message = 'Нет доступных ходов. Перемешиваем!';
      } else {
        _message = null;
      }
    });

    if (!result.accepted) {
      return;
    }

    if (session.soundEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }

    final changed = _changedPositions(before, session.board.cells);
    if (changed.isNotEmpty && mounted) {
      setState(() {
        _vanishingPositions = changed;
      });
      await Future<void>.delayed(const Duration(milliseconds: 190));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _vanishingPositions = {};
      _inputLocked = false;
    });
  }

  Set<BoardPosition> _changedPositions(List<List<int>> before, List<List<int>> after) {
    final changed = <BoardPosition>{};
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        if (before[row][col] != after[row][col]) {
          changed.add(BoardPosition(row, col));
        }
      }
    }
    return changed;
  }

  @override
  void dispose() {
    unawaited(_musicPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (_isPlaying && session != null) {
      return GamePage(
        session: session,
        message: _message,
        inputLocked: _inputLocked,
        vanishingPositions: _vanishingPositions,
        onHome: _goHome,
        onNextLevel: _nextLevel,
        onToggleSound: _toggleSound,
        onSwipe: _handleSwipe,
      );
    }

    return MainMenuPage(
      hasSession: session != null,
      savedLevel: session?.level,
      onPlay: _startGame,
    );
  }
}

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({
    required this.hasSession,
    required this.savedLevel,
    required this.onPlay,
    super.key,
  });

  final bool hasSession;
  final int? savedLevel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Waha Match-3',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Минималистичная офлайн-игра: цвет, знак, 3 в ряд.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: onPlay,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      hasSession ? 'Продолжить — уровень $savedLevel' : 'Играть',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GamePage extends StatelessWidget {
  const GamePage({
    required this.session,
    required this.message,
    required this.inputLocked,
    required this.vanishingPositions,
    required this.onHome,
    required this.onNextLevel,
    required this.onToggleSound,
    required this.onSwipe,
    super.key,
  });

  final GameSession session;
  final String? message;
  final bool inputLocked;
  final Set<BoardPosition> vanishingPositions;
  final VoidCallback onHome;
  final VoidCallback onNextLevel;
  final VoidCallback onToggleSound;
  final void Function(BoardPosition position, Direction direction) onSwipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardExtent = constraints.maxWidth.clamp(280.0, 560.0).toDouble();
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'На главную',
                          onPressed: onHome,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: session.soundEnabled ? 'Выключить звук' : 'Включить звук',
                          onPressed: onToggleSound,
                          icon: Icon(session.soundEnabled ? Icons.volume_up : Icons.volume_off),
                        ),
                      ],
                    ),
                    Text(
                      'Уровень ${session.level}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Очки: ${session.score} / $levelTargetScore',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: boardExtent,
                      height: boardExtent,
                      child: GameBoardView(
                        board: session.board,
                        enabled: !session.isLevelComplete && !inputLocked,
                        vanishingPositions: vanishingPositions,
                        onSwipe: onSwipe,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        message ?? 'Свайпайте кристаллы, чтобы собрать 3 в ряд',
                        key: ValueKey(message ?? 'hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: message == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (session.isLevelComplete) ...[
                      const SizedBox(height: 18),
                      Text(
                        session.isDemoComplete ? 'Демо пройдено' : 'Уровень пройден',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (!session.isDemoComplete)
                            FilledButton(
                              onPressed: onNextLevel,
                              child: const Text('Следующий'),
                            ),
                          OutlinedButton(
                            onPressed: onHome,
                            child: const Text('На главную'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GameBoardView extends StatelessWidget {
  const GameBoardView({
    required this.board,
    required this.enabled,
    required this.vanishingPositions,
    required this.onSwipe,
    super.key,
  });

  final GameBoard board;
  final bool enabled;
  final Set<BoardPosition> vanishingPositions;
  final void Function(BoardPosition position, Direction direction) onSwipe;

  @override
  Widget build(BuildContext context) {
    final cells = board.cells;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E26),
        border: Border.all(color: const Color(0xFFBFA76A), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: boardSize,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: boardSize * boardSize,
        itemBuilder: (context, index) {
          final row = index ~/ boardSize;
          final col = index % boardSize;
          final position = BoardPosition(row, col);
          return GemTile(
            gem: cells[row][col],
            enabled: enabled,
            disappearing: vanishingPositions.contains(position),
            onSwipe: (direction) => onSwipe(position, direction),
          );
        },
      ),
    );
  }
}

class GemTile extends StatefulWidget {
  const GemTile({
    required this.gem,
    required this.enabled,
    required this.disappearing,
    required this.onSwipe,
    super.key,
  });

  final int gem;
  final bool enabled;
  final bool disappearing;
  final void Function(Direction direction) onSwipe;

  @override
  State<GemTile> createState() => _GemTileState();
}

class _GemTileState extends State<GemTile> {
  static const double _dragThreshold = 18;

  Offset _dragOffset = Offset.zero;
  bool _sentSwipe = false;

  void _resetDrag() {
    _dragOffset = Offset.zero;
    _sentSwipe = false;
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!widget.enabled || _sentSwipe) {
      return;
    }

    _dragOffset += details.delta;
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    if (dx.abs() < _dragThreshold && dy.abs() < _dragThreshold) {
      return;
    }

    _sentSwipe = true;
    if (dx.abs() > dy.abs()) {
      widget.onSwipe(dx > 0 ? Direction.right : Direction.left);
    } else {
      widget.onSwipe(dy > 0 ? Direction.down : Direction.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _gemStyles[widget.gem % _gemStyles.length];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: widget.enabled ? (_) => _resetDrag() : null,
      onPanUpdate: widget.enabled ? _updateDrag : null,
      onPanEnd: widget.enabled ? (_) => _resetDrag() : null,
      onPanCancel: widget.enabled ? _resetDrag : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        scale: widget.disappearing ? 0.35 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: widget.disappearing ? 0.12 : 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.74, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: AnimatedContainer(
              key: ValueKey(widget.gem),
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white.withOpacity(0.24)),
                boxShadow: [
                  BoxShadow(
                    color: style.color.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    style.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GemStyle {
  const _GemStyle(this.color, this.symbol);

  final Color color;
  final String symbol;
}

const _gemStyles = [
  _GemStyle(Color(0xFF9E2F3F), '◆'),
  _GemStyle(Color(0xFF2F6F9E), '✦'),
  _GemStyle(Color(0xFF3F7D4A), '▲'),
  _GemStyle(Color(0xFFB88A2E), '●'),
  _GemStyle(Color(0xFF7A4FA3), '✚'),
  _GemStyle(Color(0xFFB45C32), '⬡'),
];
