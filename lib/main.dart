import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'core/game_core.dart';
import 'core/game_session.dart';
import 'core/session_store.dart';

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

class _WahaHomePageState extends State<WahaHomePage>
    with WidgetsBindingObserver {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final SessionStore _store = SessionStore();
  Future<void> _pendingSave = Future<void>.value();

  GameSession? _session;
  bool _loading = true;
  bool _isPlaying = false;
  bool _inputLocked = false;
  String? _message;
  List<List<int>>? _animatedCells;
  CascadeStep? _dropStep;
  int _animationGeneration = 0;
  Set<BoardPosition> _vanishingPositions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadSession());
  }

  Future<void> _loadSession() async {
    GameSession? session;
    try {
      session = await _store.load();
    } catch (_) {
      session = null;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  void _persistSession() {
    final session = _session;
    if (session == null) return;
    final data = SessionStore.encode(session);
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      try {
        await _store.saveEncoded(data);
      } catch (_) {
        if (mounted) setState(() => _message = 'Не удалось сохранить игру');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _persistSession();
    }
  }

  void _startGame() {
    _animationGeneration++;
    _dropStep = null;
    setState(() {
      _session ??= GameSession.newGame();
      _isPlaying = true;
      _message = null;
      _animatedCells = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
    _persistSession();
    unawaited(_syncBackgroundMusic());
  }

  void _goHome() {
    _animationGeneration++;
    _dropStep = null;
    setState(() {
      _isPlaying = false;
      _message = null;
      _animatedCells = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
    _persistSession();
    unawaited(_syncBackgroundMusic());
  }

  void _nextLevel() {
    final session = _session;
    if (session == null) {
      return;
    }

    _animationGeneration++;
    _dropStep = null;

    setState(() {
      session.startNextLevel();
      _message = null;
      _animatedCells = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
    _persistSession();
  }

  void _toggleSound() {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      session.setSoundEnabled(!session.soundEnabled);
    });
    _persistSession();
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

  bool _handleSwipe(BoardPosition position, Direction direction) {
    final session = _session;
    if (session == null || session.isLevelComplete || _inputLocked) {
      return false;
    }

    final swapped = session.board.cells;
    final target = position.neighbor(direction);
    if (!target.isInside) return false;
    final gem = swapped[position.row][position.col];
    swapped[position.row][position.col] = swapped[target.row][target.col];
    swapped[target.row][target.col] = gem;
    late final MoveResult result;
    setState(() {
      _inputLocked = true;
      _vanishingPositions = {};
      result = session.swipeWithSteps(position, direction);
      if (!result.accepted) {
        _message = 'Ход не собрал 3 в ряд';
        _inputLocked = false;
      } else if (result.reshuffled) {
        _message = 'Нет доступных ходов. Перемешиваем!';
      } else {
        _message = null;
      }
      _animatedCells = result.accepted ? swapped : null;
    });

    if (!result.accepted) {
      return false;
    }
    _persistSession();

    if (session.soundEnabled) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    unawaited(_finishMove(result.steps, ++_animationGeneration));
    return true;
  }

  Future<void> _finishMove(List<CascadeStep> steps, int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 170));
    if (!mounted || generation != _animationGeneration) return;
    await _playCascadeAnimation(steps, generation);
    if (!mounted || generation != _animationGeneration) return;
    setState(() {
      _animatedCells = null;
      _vanishingPositions = {};
      _inputLocked = false;
    });
  }

  Future<void> _playCascadeAnimation(
    List<CascadeStep> steps,
    int generation,
  ) async {
    for (final step in steps) {
      if (!mounted || generation != _animationGeneration) {
        return;
      }
      setState(() {
        _dropStep = null;
        _animatedCells = step.beforeClearCells;
        _vanishingPositions = step.clearedPositions;
      });
      await Future<void>.delayed(const Duration(milliseconds: 240));

      if (!mounted || generation != _animationGeneration) {
        return;
      }
      setState(() {
        _dropStep = step;
        _animatedCells = step.afterDropCells;
        _vanishingPositions = {};
      });
      await Future<void>.delayed(const Duration(milliseconds: 330));
      if (!mounted || generation != _animationGeneration) return;
      setState(() => _dropStep = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_musicPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (_isPlaying && session != null) {
      return GamePage(
        session: session,
        message: _message,
        inputLocked: _inputLocked,
        displayCells: _animatedCells ?? session.board.cells,
        dropStep: _dropStep,
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
                      hasSession
                          ? 'Продолжить — уровень $savedLevel'
                          : 'Играть',
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
    required this.displayCells,
    required this.dropStep,
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
  final List<List<int>> displayCells;
  final CascadeStep? dropStep;
  final Set<BoardPosition> vanishingPositions;
  final VoidCallback onHome;
  final VoidCallback onNextLevel;
  final VoidCallback onToggleSound;
  final bool Function(BoardPosition position, Direction direction) onSwipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardExtent = constraints.maxWidth
                .clamp(280.0, 560.0)
                .toDouble();
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
                          tooltip: session.soundEnabled
                              ? 'Выключить звук'
                              : 'Включить звук',
                          onPressed: onToggleSound,
                          icon: Icon(
                            session.soundEnabled
                                ? Icons.volume_up
                                : Icons.volume_off,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Уровень ${session.level}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
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
                        cells: displayCells,
                        dropStep: dropStep,
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
                    if (session.isLevelComplete && !inputLocked) ...[
                      const SizedBox(height: 18),
                      Text(
                        session.isDemoComplete
                            ? 'Демо пройдено'
                            : 'Уровень пройден',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
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

class GameBoardView extends StatefulWidget {
  const GameBoardView({
    required this.cells,
    required this.enabled,
    required this.vanishingPositions,
    required this.onSwipe,
    this.dropStep,
    super.key,
  });

  final List<List<int>> cells;
  final bool enabled;
  final Set<BoardPosition> vanishingPositions;
  final bool Function(BoardPosition position, Direction direction) onSwipe;
  final CascadeStep? dropStep;

  @override
  State<GameBoardView> createState() => _GameBoardViewState();
}

class _GameBoardViewState extends State<GameBoardView> {
  static const double _gap = 6;
  static const double _inset = 9.5;
  static const _snapDuration = Duration(milliseconds: 160);

  int? _pointer;
  Offset _pointerOrigin = Offset.zero;
  BoardPosition? _dragFrom;
  BoardPosition? _previewTo;
  Direction? _direction;
  Offset _drag = Offset.zero;
  List<List<int>>? _gestureCells;
  bool _settling = false;
  bool _instantReset = false;

  Direction? _directionFor(Offset delta) {
    if (delta.distance < 0.5) return null;
    if (delta.dx.abs() >= delta.dy.abs()) {
      return delta.dx > 0 ? Direction.right : Direction.left;
    }
    return delta.dy > 0 ? Direction.down : Direction.up;
  }

  void _down(PointerDownEvent event, double cell, double pitch) {
    if (!widget.enabled ||
        _settling ||
        _pointer != null ||
        (event.buttons & kPrimaryButton) == 0)
      return;
    final local = event.localPosition - const Offset(_inset, _inset);
    if (local.dx < 0 || local.dy < 0) return;
    final col = (local.dx / pitch).floor();
    final row = (local.dy / pitch).floor();
    final from = BoardPosition(row, col);
    if (!from.isInside || local.dx % pitch > cell || local.dy % pitch > cell) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _instantReset = false;
      _pointerOrigin = event.position;
      _gestureCells = [for (final row in widget.cells) List<int>.of(row)];
      _dragFrom = from;
      _drag = Offset.zero;
      _direction = null;
      _previewTo = null;
    });
  }

  void _move(PointerMoveEvent event, double pitch) {
    final from = _dragFrom;
    if (event.pointer != _pointer || from == null || _settling) return;
    // Always measure from the original press; clamping must not lose motion.
    final delta = event.position - _pointerOrigin;
    final direction = _directionFor(delta);
    final to = direction == null ? null : from.neighbor(direction);
    final horizontal =
        direction == Direction.left || direction == Direction.right;
    final axis = (horizontal ? delta.dx : delta.dy)
        .clamp(-pitch, pitch)
        .toDouble();
    setState(() {
      _direction = direction;
      _drag = direction == null || to == null || !to.isInside
          ? Offset.zero
          : horizontal
          ? Offset(axis, 0)
          : Offset(0, axis);
      _previewTo = to != null && to.isInside && axis.abs() >= pitch / 2
          ? to
          : null;
    });
  }

  Future<void> _release(
    int pointer,
    double pitch, {
    bool cancelled = false,
  }) async {
    final from = _dragFrom;
    if (pointer != _pointer || from == null || _settling) return;
    final to = cancelled ? null : _previewTo;
    final direction = _direction;
    if (_drag == Offset.zero && to == null) {
      setState(() {
        _pointer = null;
        _dragFrom = null;
        _direction = null;
        _gestureCells = null;
      });
      return;
    }
    final accepted =
        to != null &&
        direction != null &&
        widget.enabled &&
        widget.onSwipe(from, direction);
    setState(() {
      _pointer = null;
      _settling = true;
      _previewTo = accepted ? to : null;
      _drag = accepted ? _offset(direction!, pitch) : Offset.zero;
    });
    await Future<void>.delayed(_snapDuration);
    if (!mounted) return;
    setState(() {
      _instantReset = accepted;
      _gestureCells = null;
      _dragFrom = null;
      _previewTo = null;
      _direction = null;
      _drag = Offset.zero;
      _settling = false;
    });
  }

  Offset _offset(Direction direction, double pitch) => switch (direction) {
    Direction.left => Offset(-pitch, 0),
    Direction.right => Offset(pitch, 0),
    Direction.up => Offset(0, -pitch),
    Direction.down => Offset(0, pitch),
  };

  Widget _cell(BoardPosition position, double cell, double pitch) {
    final selected = position == _dragFrom;
    var displacement = Offset.zero;
    if (selected) {
      displacement = _drag;
    } else if (position == _previewTo && _direction != null) {
      displacement = -_offset(_direction!, pitch);
    }
    return AnimatedPositioned(
      key: ValueKey(position),
      duration: _instantReset || selected && !_settling
          ? Duration.zero
          : _snapDuration,
      curve: Curves.easeOutCubic,
      left: position.col * pitch + displacement.dx,
      top: position.row * pitch + displacement.dy,
      width: cell,
      height: cell,
      child: RepaintBoundary(
        child: GemTile(
          gem: (_gestureCells ?? widget.cells)[position.row][position.col],
          disappearing: widget.vanishingPositions.contains(position),
        ),
      ),
    );
  }

  Widget _fall(GemFall fall, double cell, double pitch) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(fall.to),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInQuad,
      builder: (context, progress, child) => Positioned(
        left: fall.to.col * pitch,
        top: (fall.from.row + (fall.to.row - fall.from.row) * progress) * pitch,
        width: cell,
        height: cell,
        child: child!,
      ),
      child: RepaintBoundary(child: GemTile(gem: fall.gem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = constraints.maxWidth - 2 * _inset;
        final cell = (extent - (boardSize - 1) * _gap) / boardSize;
        final pitch = cell + _gap;
        final drop = widget.dropStep;
        return RawGestureDetector(
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                  (_) {},
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _down(event, cell, pitch),
            onPointerMove: (event) => _move(event, pitch),
            onPointerUp: (event) => _release(event.pointer, pitch),
            onPointerCancel: (event) =>
                _release(event.pointer, pitch, cancelled: true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E26),
                border: Border.all(color: const Color(0xFFBFA76A), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRect(
                child: Stack(
                  children: drop != null
                      ? [
                          for (final fall in drop.falls)
                            _fall(fall, cell, pitch),
                        ]
                      : [
                          for (var row = 0; row < boardSize; row++)
                            for (var col = 0; col < boardSize; col++)
                              if (BoardPosition(row, col) != _dragFrom)
                                _cell(BoardPosition(row, col), cell, pitch),
                          if (_dragFrom != null) _cell(_dragFrom!, cell, pitch),
                        ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GemTile extends StatelessWidget {
  const GemTile({required this.gem, this.disappearing = false, super.key});

  final int gem;
  final bool disappearing;

  @override
  Widget build(BuildContext context) {
    final style = _gemStyles[gem % _gemStyles.length];
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      scale: disappearing ? 0.2 : 1,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: disappearing ? 0 : 1,
        child: Container(
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

