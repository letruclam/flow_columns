import 'package:flow_columns/flow_columns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _boardWidth = 1000.0;
const _spacing = 8.0;
const _columns = 2;
const _columnWidth = (_boardWidth - _spacing * (_columns - 1)) / _columns;

/// A card: a 60px head, [items] item boxes of [itemHeight], optional 40px tail.
List<Widget> _card(
  int index, {
  required int items,
  double itemHeight = 40,
  bool tail = false,
  String label = '',
}) {
  return [
    FlowFragment(
      key: ValueKey('$index:head'),
      cardIndex: index,
      kind: FlowFragmentKind.head,
      child: SizedBox(height: 60, child: Text('Card $index')),
    ),
    for (var i = 0; i < items; i++)
      FlowFragment(
        key: ValueKey('$index:item:$i'),
        cardIndex: index,
        kind: FlowFragmentKind.item,
        leadingGap: i == 0 ? 8 : 12,
        continuedLabel: label,
        child: SizedBox(height: itemHeight, child: Text('Card $index Item $i')),
      ),
    if (tail)
      FlowFragment(
        key: ValueKey('$index:tail'),
        cardIndex: index,
        kind: FlowFragmentKind.tail,
        leadingGap: 24,
        child: const SizedBox(height: 40, child: Text('Tail')),
      ),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  required List<FlowCardStyle> cards,
  required List<Widget> children,
  required double height,
}) async {
  tester.view.physicalSize = const Size(2400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _boardWidth,
            height: height,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FlowColumnsBoard(
                cards: cards,
                columnWidth: _columnWidth,
                columnHeight: height,
                spacing: _spacing,
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderFlowColumnsBoard _board(WidgetTester tester) =>
    tester.renderObject<RenderFlowColumnsBoard>(find.byType(FlowColumnsBoard));

const _plain = FlowCardStyle(borderColor: Colors.black, trailingGap: 24);

void main() {
  testWidgets('short card renders as one run in the first column', (
    tester,
  ) async {
    await _pump(
      tester,
      cards: const [_plain],
      children: _card(0, items: 3),
      height: 400,
    );
    final runs = _board(tester).debugRuns;
    expect(runs.length, 1);
    expect(runs.single.column, 0);
    expect(runs.single.continues, isFalse);
    expect(_board(tester).size.width, _columnWidth);
  });

  testWidgets('long card continues into the next column under the label', (
    tester,
  ) async {
    // Head 2+60+8+40 = 110, then 52 per item with 46 kept for the bottom
    // band: items 0-2 fit column 0, items 3-5 continue in column 1.
    await _pump(
      tester,
      cards: const [_plain],
      children: _card(0, items: 6),
      height: 300,
    );
    final board = _board(tester);
    final runs = board.debugRuns;
    expect(runs.length, 2);
    expect(runs[0].continues, isTrue);
    expect(runs[1].isContinuation, isTrue);
    expect(runs[1].column, 1);
    expect(board.debugContinuedLabel(runs[1]), 'Continued...');
    for (final run in runs) {
      expect(run.bottom, lessThanOrEqualTo(300));
    }
    expect(
      tester.getTopLeft(find.text('Card 0 Item 3')).dx,
      greaterThanOrEqualTo(_columnWidth + _spacing),
    );
    expect(board.size.width, _columnWidth * 2 + _spacing);
  });

  testWidgets('fragment label overrides the board label', (tester) async {
    await _pump(
      tester,
      cards: const [_plain],
      children: _card(0, items: 6, label: 'Part 2'),
      height: 300,
    );
    final board = _board(tester);
    expect(board.debugContinuedLabel(board.debugRuns[1]), 'Part 2');
    expect(board.debugContinuedLabel(board.debugRuns[0]), isNull);
  });

  testWidgets('second card starts below the first or in the next column', (
    tester,
  ) async {
    await _pump(
      tester,
      cards: const [_plain, _plain],
      children: [..._card(0, items: 2), ..._card(1, items: 2)],
      height: 600,
    );
    final runs = _board(tester).debugRuns;
    expect(runs.length, 2);
    expect(runs[1].top, runs[0].bottom + _spacing);
  });

  testWidgets('an item taller than the column is capped and scrolls', (
    tester,
  ) async {
    await _pump(
      tester,
      cards: const [_plain],
      children: [
        FlowFragment(
          cardIndex: 0,
          kind: FlowFragmentKind.head,
          child: const SizedBox(height: 60, child: Text('Head')),
        ),
        FlowFragment(
          cardIndex: 0,
          kind: FlowFragmentKind.item,
          leadingGap: 8,
          child: Column(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 30, child: Text('Line $i')),
            ],
          ),
        ),
      ],
      height: 300,
    );
    final board = _board(tester);
    expect(board.debugRuns.length, 1);
    expect(board.debugRuns.single.bottom, lessThanOrEqualTo(300));
    expect(tester.getTopLeft(find.text('Line 39')).dy, greaterThan(300));

    await tester.drag(find.text('Line 0'), const Offset(0, -3000));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getBottomLeft(find.text('Line 39')).dy,
      lessThanOrEqualTo(300),
    );
  });

  testWidgets('tail travels with the last item', (tester) async {
    await _pump(
      tester,
      cards: const [FlowCardStyle(borderColor: Colors.black, trailingGap: 0)],
      children: _card(0, items: 5, tail: true),
      height: 300,
    );
    final runs = _board(tester).debugRuns;
    final last = runs.last;
    final tailTop = tester.getTopLeft(find.text('Tail'));
    final lastItemTop = tester.getTopLeft(find.text('Card 0 Item 4'));
    expect(tailTop.dx, lastItemTop.dx);
    expect(last.lockedOverlayBottom, lessThan(last.bottom));
  });

  testWidgets('empty board has zero width', (tester) async {
    await _pump(tester, cards: const [], children: const [], height: 300);
    expect(_board(tester).size.width, 0);
  });
}
