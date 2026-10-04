import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waha_match3/core/game_session.dart';
import 'package:waha_match3/core/session_store.dart';

void main() {
  test('saved session restores level, score, exact board, and sound', () {
    final board = GameSession.newGame(random: Random(11)).board.cells;
    final original = GameSession.restore(
      level: 3,
      score: 42,
      cells: board,
      soundEnabled: false,
    );
    final restored = SessionStore.decode(SessionStore.encode(original));

    expect(restored.level, original.level);
    expect(restored.score, original.score);
    expect(restored.board.cells, original.board.cells);
    expect(restored.soundEnabled, original.soundEnabled);
  });

  test('invalid save is rejected', () {
    expect(() => SessionStore.decode('{"version":2}'), throwsFormatException);
    expect(
      () => SessionStore.decode('{"version":1,"cells":[]}'),
      throwsArgumentError,
    );
  });
}

