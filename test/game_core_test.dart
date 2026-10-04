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
      final board = GameBoard.newPlayable(random: Random(4));
      final before = board.cells;
      final move = _findMove(board, shouldCreateMatch: false);

      final result = board.swipe(move.from, move.direction);

      expect(result.accepted, isFalse);
      expect(result.scoreDelta, 0);
      expect(board.cells, before);
    });

    test('accepts a swap that creates a match and returns score', () {
      final board = GameBoard.newPlayable(random: Random(5));
      final move = _findMove(board, shouldCreateMatch: true);

      final result = board.swipe(move.from, move.direction);

      expect(result.accepted, isTrue);
      expect(result.scoreDelta, greaterThanOrEqualTo(3));
      expect(board.hasMatches, isFalse);
      expect(board.hasAvailableMove, isTrue);
    });

    test('returns cascade animation steps for a valid swap', () {
      final board = GameBoard.newPlayable(random: Random(6));
      final move = _findMove(board, shouldCreateMatch: true);

      final result = board.swipeWithSteps(move.from, move.direction);

      expect(result.accepted, isTrue);
      expect(result.steps, isNotEmpty);
      expect(result.steps.first.clearedPositions.length, greaterThanOrEqualTo(3));
      expect(result.steps.first.beforeClearCells, hasLength(boardSize));
      expect(result.steps.first.afterDropCells, hasLength(boardSize));
    });
  });
}

_TestMove _findMove(GameBoard board, {required bool shouldCreateMatch}) {
  final cells = board.cells;
  for (var row = 0; row < boardSize; row++) {
    for (var col = 0; col < boardSize; col++) {
      final from = BoardPosition(row, col);
      for (final direction in Direction.values) {
        final to = from.neighbor(direction);
        if (!to.isInside) {
          continue;
        }

        final copy = [for (final sourceRow in cells) List<int>.of(sourceRow)];
        final temp = copy[from.row][from.col];
        copy[from.row][from.col] = copy[to.row][to.col];
        copy[to.row][to.col] = temp;

        if (_hasMatch(copy) == shouldCreateMatch) {
          return _TestMove(from, direction);
        }
      }
    }
  }

  throw StateError('Unable to find requested test move.');
}

bool _hasMatch(List<List<int>> cells) {
  for (var row = 0; row < boardSize; row++) {
    var run = 1;
    for (var col = 1; col < boardSize; col++) {
      if (cells[row][col] == cells[row][col - 1]) {
        run++;
        if (run >= 3) {
          return true;
        }
      } else {
        run = 1;
      }
    }
  }

  for (var col = 0; col < boardSize; col++) {
    var run = 1;
    for (var row = 1; row < boardSize; row++) {
      if (cells[row][col] == cells[row - 1][col]) {
        run++;
        if (run >= 3) {
          return true;
        }
      } else {
        run = 1;
      }
    }
  }

  return false;
}

class _TestMove {
  const _TestMove(this.from, this.direction);

  final BoardPosition from;
  final Direction direction;
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

