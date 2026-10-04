import 'dart:math';

import 'game_core.dart';

const int demoLevelCount = 5;

class GameSession {
  GameSession._({
    required this.level,
    required this.score,
    required this.board,
    required this.soundEnabled,
  });

  factory GameSession.newGame({Random? random}) {
    return GameSession._(
      level: 1,
      score: 0,
      board: GameBoard.newPlayable(random: random),
      soundEnabled: true,
    );
  }

  factory GameSession.restore({
    required int level,
    required int score,
    required List<List<int>> cells,
    required bool soundEnabled,
    Random? random,
  }) {
    if (level < 1 || level > demoLevelCount) {
      throw ArgumentError('Level must be between 1 and $demoLevelCount.');
    }
    if (score < 0) {
      throw ArgumentError('Score must not be negative.');
    }

    final board = GameBoard.fromCells(cells, random: random);
    board.ensurePlayable();

    return GameSession._(
      level: level,
      score: _clampScore(score),
      board: board,
      soundEnabled: soundEnabled,
    );
  }

  int level;
  int score;
  GameBoard board;
  bool soundEnabled;

  bool get isLevelComplete => score >= levelTargetScore;

  bool get isDemoComplete => isLevelComplete && level == demoLevelCount;

  MoveResult swipe(BoardPosition from, Direction direction) {
    return swipeWithSteps(from, direction);
  }

  MoveResult swipeWithSteps(BoardPosition from, Direction direction) {
    if (isLevelComplete) {
      return const MoveResult(
        accepted: false,
        scoreDelta: 0,
        cascadeCount: 0,
        reshuffled: false,
      );
    }

    final result = board.swipeWithSteps(from, direction);
    if (result.accepted) {
      score = _clampScore(score + result.scoreDelta);
    }
    return result;
  }

  bool startNextLevel({Random? random}) {
    if (!isLevelComplete || level >= demoLevelCount) {
      return false;
    }

    level++;
    score = 0;
    board = GameBoard.newPlayable(random: random);
    return true;
  }

  void setSoundEnabled(bool enabled) {
    soundEnabled = enabled;
  }

  static int _clampScore(int value) {
    return value.clamp(0, levelTargetScore).toInt();
  }
}
