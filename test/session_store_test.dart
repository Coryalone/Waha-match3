import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waha_match3/core/game_session.dart';
import 'package:waha_match3/core/session_store.dart';

void main() {
  test('saved session restores level, score, exact board, and sound', () {
    final original = GameSession.newGame(random: Random(11));
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
      throwsA(isA<FormatException>()),
    );
  });
}

