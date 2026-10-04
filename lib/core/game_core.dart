import 'dart:math';

const int boardSize = 8;
const int gemTypeCount = 6;
const int levelTargetScore = 100;

enum Direction { up, down, left, right }

class BoardPosition {
  const BoardPosition(this.row, this.col);

  final int row;
  final int col;

  BoardPosition neighbor(Direction direction) {
    return switch (direction) {
      Direction.up => BoardPosition(row - 1, col),
      Direction.down => BoardPosition(row + 1, col),
      Direction.left => BoardPosition(row, col - 1),
      Direction.right => BoardPosition(row, col + 1),
    };
  }

  bool get isInside => row >= 0 && row < boardSize && col >= 0 && col < boardSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPosition && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);
}

class MatchGroup {
  const MatchGroup(this.positions);

  final Set<BoardPosition> positions;
}

class CascadeStep {
  const CascadeStep({
    required this.beforeClearCells,
    required this.clearedPositions,
    required this.afterDropCells,
  });

  final List<List<int>> beforeClearCells;
  final Set<BoardPosition> clearedPositions;
  final List<List<int>> afterDropCells;
}

class MoveResult {
  const MoveResult({
    required this.accepted,
    required this.scoreDelta,
    required this.cascadeCount,
    required this.reshuffled,
    this.steps = const [],
  });

  final bool accepted;
  final int scoreDelta;
  final int cascadeCount;
  final bool reshuffled;
  final List<CascadeStep> steps;
}

class GameBoard {
  GameBoard._(this._cells, this._random);

  factory GameBoard.newPlayable({Random? random}) {
    final rng = random ?? Random();

    for (var attempt = 0; attempt < 1000; attempt++) {
      final board = GameBoard._(_emptyCells(), rng);
      for (var row = 0; row < boardSize; row++) {
        for (var col = 0; col < boardSize; col++) {
          board._cells[row][col] = board._randomGemAvoidingInitialMatch(row, col);
        }
      }

      if (board.hasAvailableMove) {
        return board;
      }
    }

    throw StateError('Unable to generate a playable board.');
  }

  factory GameBoard.fromCells(List<List<int>> cells, {Random? random}) {
    _validateCells(cells);
    return GameBoard._(
      [for (final row in cells) List<int>.of(row)],
      random ?? Random(),
    );
  }

  final List<List<int>> _cells;
  final Random _random;

  List<List<int>> get cells => _copyCells(_cells);

  int gemAt(BoardPosition position) => _cells[position.row][position.col];

  bool get hasMatches => findMatches().isNotEmpty;

  bool get hasAvailableMove {
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        final position = BoardPosition(row, col);
        for (final direction in [Direction.right, Direction.down]) {
          final other = position.neighbor(direction);
          if (!other.isInside) {
            continue;
          }
          _swap(position, other);
          final matched = findMatches().isNotEmpty;
          _swap(position, other);
          if (matched) {
            return true;
          }
        }
      }
    }
    return false;
  }

  MoveResult swipe(BoardPosition from, Direction direction) {
    return swipeWithSteps(from, direction);
  }

  MoveResult swipeWithSteps(BoardPosition from, Direction direction) {
    final to = from.neighbor(direction);
    if (!from.isInside || !to.isInside) {
      return _rejectedMove;
    }

    _swap(from, to);
    if (findMatches().isEmpty) {
      _swap(from, to);
      return _rejectedMove;
    }

    final cascade = resolveCascadesWithSteps();
    final didReshuffle = ensurePlayable();
    return MoveResult(
      accepted: true,
      scoreDelta: cascade.scoreDelta,
      cascadeCount: cascade.cascadeCount,
      reshuffled: didReshuffle,
      steps: cascade.steps,
    );
  }

  CascadeResult resolveCascades() {
    return resolveCascadesWithSteps();
  }

  CascadeResult resolveCascadesWithSteps() {
    var totalScore = 0;
    var cascadeCount = 0;
    final steps = <CascadeStep>[];

    while (true) {
      final matchedPositions = _uniqueMatchedPositions();
      if (matchedPositions.isEmpty) {
        break;
      }

      final beforeClear = cells;
      totalScore += matchedPositions.length;
      cascadeCount++;
      _clear(matchedPositions);
      _applyGravityAndRefill();
      steps.add(CascadeStep(
        beforeClearCells: beforeClear,
        clearedPositions: Set<BoardPosition>.of(matchedPositions),
        afterDropCells: cells,
      ));
    }

    return CascadeResult(
      scoreDelta: totalScore,
      cascadeCount: cascadeCount,
      steps: steps,
    );
  }

  bool ensurePlayable() {
    if (!hasMatches && hasAvailableMove) {
      return false;
    }

    final replacement = GameBoard.newPlayable(random: _random);
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        _cells[row][col] = replacement._cells[row][col];
      }
    }
    return true;
  }

  List<MatchGroup> findMatches() {
    final groups = <MatchGroup>[];

    for (var row = 0; row < boardSize; row++) {
      var start = 0;
      for (var col = 1; col <= boardSize; col++) {
        if (col < boardSize && _cells[row][col] == _cells[row][start]) {
          continue;
        }
        if (col - start >= 3) {
          groups.add(MatchGroup({
            for (var matchCol = start; matchCol < col; matchCol++) BoardPosition(row, matchCol),
          }));
        }
        start = col;
      }
    }

    for (var col = 0; col < boardSize; col++) {
      var start = 0;
      for (var row = 1; row <= boardSize; row++) {
        if (row < boardSize && _cells[row][col] == _cells[start][col]) {
          continue;
        }
        if (row - start >= 3) {
          groups.add(MatchGroup({
            for (var matchRow = start; matchRow < row; matchRow++) BoardPosition(matchRow, col),
          }));
        }
        start = row;
      }
    }

    return groups;
  }

  Set<BoardPosition> _uniqueMatchedPositions() {
    return {
      for (final group in findMatches()) ...group.positions,
    };
  }

  int _randomGemAvoidingInitialMatch(int row, int col) {
    final candidates = List<int>.generate(gemTypeCount, (index) => index)..shuffle(_random);

    for (final candidate in candidates) {
      final createsHorizontal = col >= 2 &&
          _cells[row][col - 1] == candidate &&
          _cells[row][col - 2] == candidate;
      final createsVertical = row >= 2 &&
          _cells[row - 1][col] == candidate &&
          _cells[row - 2][col] == candidate;
      if (!createsHorizontal && !createsVertical) {
        return candidate;
      }
    }

    return candidates.first;
  }

  void _swap(BoardPosition first, BoardPosition second) {
    final temp = _cells[first.row][first.col];
    _cells[first.row][first.col] = _cells[second.row][second.col];
    _cells[second.row][second.col] = temp;
  }

  void _clear(Set<BoardPosition> positions) {
    for (final position in positions) {
      _cells[position.row][position.col] = -1;
    }
  }

  void _applyGravityAndRefill() {
    for (var col = 0; col < boardSize; col++) {
      final remaining = <int>[];
      for (var row = boardSize - 1; row >= 0; row--) {
        final gem = _cells[row][col];
        if (gem >= 0) {
          remaining.add(gem);
        }
      }

      var writeRow = boardSize - 1;
      for (final gem in remaining) {
        _cells[writeRow][col] = gem;
        writeRow--;
      }
      while (writeRow >= 0) {
        _cells[writeRow][col] = _random.nextInt(gemTypeCount);
        writeRow--;
      }
    }
  }

  static List<List<int>> _emptyCells() {
    return List.generate(boardSize, (_) => List<int>.filled(boardSize, 0));
  }

  static List<List<int>> _copyCells(List<List<int>> cells) {
    return [for (final row in cells) List<int>.of(row)];
  }

  static void _validateCells(List<List<int>> cells) {
    if (cells.length != boardSize || cells.any((row) => row.length != boardSize)) {
      throw ArgumentError('Board must be ${boardSize}x$boardSize.');
    }

    for (final row in cells) {
      for (final gem in row) {
        if (gem < 0 || gem >= gemTypeCount) {
          throw ArgumentError('Gem values must be between 0 and ${gemTypeCount - 1}.');
        }
      }
    }
  }
}

class CascadeResult {
  const CascadeResult({
    required this.scoreDelta,
    required this.cascadeCount,
    this.steps = const [],
  });

  final int scoreDelta;
  final int cascadeCount;
  final List<CascadeStep> steps;
}

const _rejectedMove = MoveResult(
  accepted: false,
  scoreDelta: 0,
  cascadeCount: 0,
  reshuffled: false,
);
