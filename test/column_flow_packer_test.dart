import 'package:flow_columns/flow_columns.dart';
import 'package:flutter_test/flutter_test.dart';

const _border = 2.0;
const _band = 36.0;
const _foot = 36.0;
const _cut = 8.0;
const _topPad = 8.0;
const _spacing = 8.0;
const _colW = 300.0;

({List<FlowFragmentSpec> frags, List<double> heights, FlowCardSpec ticket})
_ticket(int index, List<double> rows, {bool footer = false}) {
  final frags = <FlowFragmentSpec>[
    FlowFragmentSpec(cardIndex: index, kind: FlowFragmentKind.head),
    FlowFragmentSpec(cardIndex: index, kind: FlowFragmentKind.head),
  ];
  final heights = <double>[60, 45];
  for (var i = 0; i < rows.length; i++) {
    frags.add(
      FlowFragmentSpec(
        cardIndex: index,
        kind: FlowFragmentKind.item,
        leadingGap: i == 0 ? 8 : 12,
      ),
    );
    heights.add(rows[i]);
  }
  if (footer) {
    frags.add(
      FlowFragmentSpec(
        cardIndex: index,
        kind: FlowFragmentKind.tail,
        leadingGap: 24,
      ),
    );
    heights.add(48);
  }
  final trailing = footer ? 0.0 : (rows.isEmpty ? 32.0 : 24.0);
  return (
    frags: frags,
    heights: heights,
    ticket: FlowCardSpec(trailingGap: trailing),
  );
}

FlowPackResult _pack(
  List<
    ({List<FlowFragmentSpec> frags, List<double> heights, FlowCardSpec ticket})
  >
  cards, {
  required double height,
}) {
  return packColumnFlow(
    fragments: [for (final c in cards) ...c.frags],
    heights: [for (final c in cards) ...c.heights],
    cards: [for (final c in cards) c.ticket],
    columnWidth: _colW,
    columnHeight: height,
    spacing: _spacing,
    border: _border,
    continuedBandHeight: _band,
    continuedFooterHeight: _foot,
    cutPadding: _cut,
    continuedTopPadding: _topPad,
  );
}

void main() {
  group('packColumnFlow', () {
    test('ticket that fits stays in one run', () {
      final r = _pack([
        _ticket(0, [40, 40]),
      ], height: 600);
      expect(r.runs.length, 1);
      expect(r.usedColumns, 1);
      expect(r.width, _colW);
      final run = r.runs.single;
      expect(run.isContinuation, isFalse);
      expect(run.continues, isFalse);
      expect(r.offsets[0], const Offset(_border, _border));
      expect(r.offsets[1], const Offset(_border, _border + 60));
      expect(r.offsets[2], const Offset(_border, _border + 60 + 45 + 8));
      expect(r.offsets[3], Offset(_border, r.offsets[2].dy + 40 + 12));
      expect(run.bottom, r.offsets[3].dy + 40 + 24 + _border);
      expect(run.lockedOverlayBottom, run.bottom - _border);
    });

    test('second ticket follows the first after spacing', () {
      final r = _pack([
        _ticket(0, [40]),
        _ticket(1, [40]),
      ], height: 600);
      expect(r.runs.length, 2);
      expect(r.runs[1].column, 0);
      expect(r.runs[1].top, r.runs[0].bottom + _spacing);
    });

    test('overflowing ticket is cut and continues in the next column', () {
      final r = _pack([
        _ticket(0, [40, 40, 40, 40, 40]),
      ], height: 300);
      expect(r.runs.length, 2);
      expect(r.usedColumns, 2);
      expect(r.width, _colW * 2 + _spacing);
      final first = r.runs[0];
      final second = r.runs[1];
      expect(first.continues, isTrue);
      expect(first.isContinuation, isFalse);
      expect(second.isContinuation, isTrue);
      expect(second.continues, isFalse);
      expect(second.column, 1);
      expect(second.top, 0);
      expect(r.offsets[3].dy, 155 + 12);
      expect(first.bottom, 207 + _cut + _foot + _border);
      expect(first.lockedOverlayBottom, first.bottom - _border);
      expect(
        r.offsets[4],
        Offset(_colW + _spacing + _border, _border + _band + _topPad),
      );
    });

    test('a row that only fits without the footer band is cut before', () {
      // Head ends at y = 155; the next row needs 12 + 40 plus the footer
      // band (8 + 36 + 2), so 250 is too short even though the row alone
      // would fit.
      final r = _pack([
        _ticket(0, [40, 40, 40]),
      ], height: 250);
      expect(r.runs.length, 2);
      expect(r.runs[0].fragmentEnd, 3);
      expect(r.runs[0].bottom, 155 + _cut + _foot + _border);
    });

    test('orphan rule: head that does not fit moves the whole ticket', () {
      final r = _pack([
        _ticket(0, [40, 40, 40, 40]),
        _ticket(1, [40]),
      ], height: 400);
      expect(r.runs[0].column, 0);
      expect(r.runs[0].continues, isFalse);
      expect(r.runs[1].column, 1);
      expect(r.runs[1].top, 0);
      expect(r.runs[1].isContinuation, isFalse);
    });

    test('a row taller than an empty column is capped, not clipped', () {
      // Head: border 2 + header 60 + band 45 + gap 8 = 115, then the row.
      // Last row closes with trailing 24 + border 2, so it gets 250-115-26.
      final r = _pack([
        _ticket(0, [400]),
      ], height: 250);
      expect(r.runs.length, 1);
      expect(r.runs.single.column, 0);
      expect(r.hasOverflow, isFalse);
      expect(r.layoutHeights[2], 250 - 115 - 26);
      expect(r.runs.single.bottom, 250);
    });

    test('rows that fit keep their measured height', () {
      final r = _pack([
        _ticket(0, [40, 40]),
      ], height: 300);
      expect(r.layoutHeights, [60, 45, 40, 40]);
    });

    test('a capped middle row still sends the next rows to a new column', () {
      // Row 1 (400) opens column 1 after the head, is capped to leave room
      // for the footer band, and row 2 continues in column 2.
      final r = _pack([
        _ticket(0, [40, 400, 40]),
      ], height: 250);
      expect(r.runs.length, 3);
      expect(r.runs[1].column, 1);
      expect(r.runs[1].isContinuation, isTrue);
      expect(r.runs[1].continues, isTrue);
      final rowTop = _border + _band + _topPad;
      expect(r.offsets[3].dy, rowTop);
      expect(r.layoutHeights[3], 250 - rowTop - (_cut + _foot + _border));
      expect(r.runs[1].bottom, 250);
      expect(r.runs[2].column, 2);
      expect(r.hasOverflow, isFalse);
    });

    test('a capped last row keeps its footer in the same column', () {
      final r = _pack([
        _ticket(0, [400], footer: true),
      ], height: 250);
      expect(r.runs.length, 1);
      final footerNeed = 24 + 48 + _border;
      expect(r.layoutHeights[2], 250 - 115 - footerNeed);
      expect(r.offsets[3].dy, 250 - 48 - _border);
      expect(r.runs.single.bottom, 250);
      expect(r.hasOverflow, isFalse);
    });

    test('header taller than the column is still flagged', () {
      final r = packColumnFlow(
        fragments: const [
          FlowFragmentSpec(cardIndex: 0, kind: FlowFragmentKind.head),
        ],
        heights: const [300],
        cards: const [FlowCardSpec(trailingGap: 32)],
        columnWidth: _colW,
        columnHeight: 250,
        spacing: _spacing,
      );
      expect(r.hasOverflow, isTrue);
      expect(r.layoutHeights, [300]);
    });

    test('footer moves together with the last row', () {
      final r = _pack([
        _ticket(0, [40, 40], footer: true),
      ], height: 280);
      expect(r.runs.length, 2);
      expect(r.offsets[3].dx, _colW + _spacing + _border);
      expect(r.offsets[4].dx, _colW + _spacing + _border);
      expect(r.runs[0].bottom, 155 + _cut + _foot + _border);
      expect(r.runs[1].lockedOverlayBottom, r.offsets[4].dy);
    });

    test('a long ticket spans three columns with two continued bands', () {
      final r = _pack([_ticket(0, List.filled(7, 40))], height: 250);
      expect(r.usedColumns, 3);
      expect(r.runs.length, 3);
      expect(r.runs.where((run) => run.isContinuation).length, 2);
      expect(r.runs.where((run) => run.continues).length, 2);
    });

    test('no tickets gives zero columns and width', () {
      final r = _pack([], height: 250);
      expect(r.usedColumns, 0);
      expect(r.width, 0);
      expect(r.runs, isEmpty);
    });

    test('ticket without rows uses its trailing gap', () {
      final r = _pack([_ticket(0, [])], height: 250);
      expect(r.runs.single.bottom, _border + 60 + 45 + 32 + _border);
    });
  });
}
