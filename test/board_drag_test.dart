import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waha_match3/core/game_core.dart';
import 'package:waha_match3/main.dart';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      '$kind captures on press and follows absolute pointer position',
      (tester) async {
        var commits = 0;
        final cells = List.generate(
          boardSize,
          (row) =>
              List.generate(boardSize, (col) => (row + col) % gemTypeCount),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 400,
                  child: GameBoardView(
                    cells: cells,
                    enabled: true,
                    vanishingPositions: const {},
                    onSwipe: (_, _) {
                      commits++;
                      return false;
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        final source = find.byKey(const ValueKey(BoardPosition(3, 3)));
        final distant = find.byKey(const ValueKey(BoardPosition(7, 7)));
        final start = tester.getTopLeft(source);
        final distantStart = tester.getRect(distant);
        final press = tester.getCenter(source);
        final pitch =
            tester
                .getTopLeft(find.byKey(const ValueKey(BoardPosition(3, 4))))
                .dx -
            start.dx;
        final gesture = await tester.createGesture(kind: kind);
        await gesture.down(press);
        await tester.pump();

        await gesture.moveTo(press + Offset(pitch * .25, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(source).dx,
          closeTo(start.dx + pitch * .25, .1),
        );
        expect(commits, 0);

        await gesture.moveTo(press + Offset(pitch * .8, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(source).dx,
          closeTo(start.dx + pitch * .8, .1),
        );
        expect(tester.getRect(distant), distantStart);
        expect(commits, 0);

        // The same press can reverse across the origin and change axes.
        await gesture.moveTo(press + Offset(0, -pitch * .75));
        await tester.pump();
        expect(
          tester.getTopLeft(source).dy,
          closeTo(start.dy - pitch * .75, .1),
        );
        expect(tester.getTopLeft(source).dx, closeTo(start.dx, .1));
        expect(commits, 0);

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 170));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 170));
        await tester.pump();
        expect(commits, 1);
        expect(tester.getTopLeft(source), start);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

