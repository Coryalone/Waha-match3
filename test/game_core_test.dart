import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waha_match3/core/game_core.dart';

void main() {
  group('GameBoard generation', () {
    test('creates an 8x8 board without initial matches', () {
      final board = GameBoard.newPlayable(random: Random(1));

      expect(board.cells, hasLength(boardSize));
      expect(board.cells.every((row) => row.length == boardSize), isTrue);
      expect(board.findMatches(), isEmpty);
    });

    test('creates a board with at least one available move', () {
      final board = GameBoard.newPlayable(random: Random(2));

      expect(board.hasAvailableMove, isTrue);
    });
  });

  group('Match detection', () {
    test('finds horizontal and vertical matches', () {
      final board = GameBoard.fromCells(_boardWithCrossMatch());

      final matchedPositions = {
        for (final group in board.findMatches()) ...group.positions,
      };

      expect(matchedPositions.length, 5);
      expect(matchedPositions, contains(const BoardPosition(0, 0)));
      expect(matchedPositions, contains(const BoardPosition(0, 1)));
      expect(matchedPositions, contains(const BoardPosition(0, 2)));
      expect(matchedPositions, contains(const BoardPosition(1, 1)));
      expect(matchedPositions, contains(const BoardPosition(2, 1)));
    });
  });

  group('Swaps', () {
    test('rejects a swap that does not create a match', () {
      final board = GameBoard.fromCells(_stableBoard());
      final before = board.cells;

      final result = board.swipe(const BoardPosition(0, 0), Direction.right);

      expect(result.accepted, isFalse);
      expect(result.scoreDelta, 0);
      expect(board.cells, before);
    });

    test('accepts a swap that creates a match and returns score', () {
      final board = GameBoard.fromCells([
        [0, 1, 0, 2, 3, 4, 5, 1],
        [2, 0, 1, 3, 4, 5, 0, 2],
        [3, 4, 0, 5, 1, 2, 3, 4],
        [4, 5, 2, 0, 2, 3, 4, 5],
        [5, 2, 3, 4, 0, 1, 2, 3],
        [1, 3, 4, 5, 2, 0, 1, 2],
        [2, 4, 5, 1, 3, 4, 5, 0],
        [3, 5, 1, 2, 4, 5, 0, 1],
      ], random: Random(3));

      final result = board.swipe(const BoardPosition(0, 1), Direction.right);

      expect(result.accepted, isTrue);
      expect(result.scoreDelta, greaterThanOrEqualTo(3));
      expect(board.hasMatches, isFalse);
      expect(board.hasAvailableMove, isTrue);
    });
  });
}

List<List<int>> _stableBoard() {
  return [
    [0, 1, 2, 3, 4, 5, 0, 1],
    [2, 3, 4, 5, 0, 1, 2, 3],
    [4, 5, 0, 1, 2, 3, 4, 5],
    [1, 2, 3, 4, 5, 0, 1, 2],
    [3, 4, 5, 0, 1, 2, 3, 4],
    [5, 0, 1, 2, 3, 4, 5, 0],
    [0, 1, 2, 3, 4, 5, 0, 1],
    [2, 3, 4, 5, 0, 1, 2, 3],
  ];
}

List<List<int>> _boardWithCrossMatch() {
  return [
    [0, 0, 0, 2, 3, 4, 5, 1],
    [2, 0, 1, 3, 4, 5, 0, 2],
    [3, 0, 2, 5, 1, 2, 3, 4],
    [4, 5, 3, 0, 2, 3, 4, 5],
    [5, 2, 4, 4, 0, 1, 2, 3],
    [1, 3, 5, 5, 2, 0, 1, 2],
    [2, 4, 1, 1, 3, 4, 5, 0],
    [3, 5, 2, 2, 4, 5, 0, 1],
  ];
}
