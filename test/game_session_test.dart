import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waha_match3/core/game_core.dart';
import 'package:waha_match3/core/game_session.dart';

void main() {
  test('new game starts at level 1 with empty score and sound enabled', () {
    final session = GameSession.newGame(random: Random(1));

    expect(session.level, 1);
    expect(session.score, 0);
    expect(session.soundEnabled, isTrue);
    expect(session.isLevelComplete, isFalse);
    expect(session.isDemoComplete, isFalse);
  });

  test('restore clamps score to the level target', () {
    final session = GameSession.restore(
      level: 2,
      score: 999,
      cells: GameBoard.newPlayable(random: Random(2)).cells,
      soundEnabled: false,
      random: Random(3),
    );

    expect(session.level, 2);
    expect(session.score, levelTargetScore);
    expect(session.soundEnabled, isFalse);
    expect(session.isLevelComplete, isTrue);
  });

  test('completed non-final level can advance to the next level', () {
    final session = GameSession.restore(
      level: 1,
      score: levelTargetScore,
      cells: GameBoard.newPlayable(random: Random(4)).cells,
      soundEnabled: true,
      random: Random(5),
    );

    final advanced = session.startNextLevel(random: Random(6));

    expect(advanced, isTrue);
    expect(session.level, 2);
    expect(session.score, 0);
    expect(session.isLevelComplete, isFalse);
    expect(session.board.hasMatches, isFalse);
    expect(session.board.hasAvailableMove, isTrue);
  });

  test('final completed level marks the demo complete', () {
    final session = GameSession.restore(
      level: demoLevelCount,
      score: levelTargetScore,
      cells: GameBoard.newPlayable(random: Random(7)).cells,
      soundEnabled: true,
      random: Random(8),
    );

    expect(session.isDemoComplete, isTrue);
    expect(session.startNextLevel(random: Random(9)), isFalse);
    expect(session.level, demoLevelCount);
  });
}
