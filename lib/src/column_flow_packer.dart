import 'dart:ui';

/// What a fragment is to the packer.
///
/// [head] fragments open a card and are kept together with the first [item];
/// a card is only ever cut between [item] fragments; a [tail] fragment closes
/// the card and travels with the last [item].
enum FlowFragmentKind { head, item, tail }

class FlowFragmentSpec {
  const FlowFragmentSpec({
    required this.cardIndex,
    required this.kind,
    this.leadingGap = 0,
  });

  final int cardIndex;
  final FlowFragmentKind kind;

  /// Space above the fragment when it follows another fragment of its card
  /// in the same column. Dropped when the fragment opens a continuation.
  final double leadingGap;
}

class FlowCardSpec {
  const FlowCardSpec({required this.trailingGap});

  /// Space between the last fragment and the bottom border of the card.
  final double trailingGap;
}

/// One contiguous part of a card inside one column.
class FlowRun {
  const FlowRun({
    required this.cardIndex,
    required this.column,
    required this.top,
    required this.bottom,
    required this.isContinuation,
    required this.continues,
    required this.lockedOverlayBottom,
    required this.fragmentStart,
    required this.fragmentEnd,
  });

  final int cardIndex;
  final int column;

  /// Fragments of this run: `fragmentStart ..< fragmentEnd`.
  final int fragmentStart;
  final int fragmentEnd;

  final double top;
  final double bottom;

  /// Opens with a "Continued" band because the card was cut before it.
  final bool isContinuation;

  /// Closes with a "Continued" band because the card goes on in the next
  /// column.
  final bool continues;

  /// Bottom edge of the lock overlay: the whole run when it is cut, otherwise
  /// the top of the tail fragment (or the inner bottom edge without a tail).
  final double lockedOverlayBottom;
}

class FlowPackResult {
  const FlowPackResult({
    required this.offsets,
    required this.layoutHeights,
    required this.runs,
    required this.usedColumns,
    required this.width,
    required this.hasOverflow,
  });

  final List<Offset> offsets;

  /// Height each fragment is laid out with. Equals the measured height,
  /// except for an item taller than the room left in its column, which is
  /// capped to that room so it can scroll inside.
  final List<double> layoutHeights;
  final List<FlowRun> runs;
  final int usedColumns;
  final double width;

  /// A head or tail fragment was taller than the column and got clipped.
  final bool hasOverflow;
}

/// Packs [fragments] (grouped by card, in order) into columns of
/// [columnWidth] × [columnHeight] separated by [spacing].
///
/// [heights] is the measured height of each fragment. [border] is the card
/// border width; [continuedBandHeight] / [continuedFooterHeight] the bands
/// opening and closing a cut; [cutPadding] the space kept above the closing
/// band; [continuedTopPadding] the space below the opening band.
FlowPackResult packColumnFlow({
  required List<FlowFragmentSpec> fragments,
  required List<double> heights,
  required List<FlowCardSpec> cards,
  required double columnWidth,
  required double columnHeight,
  required double spacing,
  double border = 2,
  double continuedBandHeight = 36,
  double continuedFooterHeight = 36,
  double cutPadding = 8,
  double continuedTopPadding = 8,
}) {
  assert(fragments.length == heights.length);
  final offsets = List<Offset>.filled(fragments.length, Offset.zero);
  final layoutHeights = List<double>.of(heights);
  final runs = <FlowRun>[];
  var hasOverflow = false;

  double innerX(int column) => column * (columnWidth + spacing) + border;

  var column = 0;
  var y = 0.0;
  var fragIndex = 0;
  for (var t = 0; t < cards.length; t++) {
    final start = fragIndex;
    while (fragIndex < fragments.length &&
        fragments[fragIndex].cardIndex == t) {
      fragIndex++;
    }
    final end = fragIndex;
    if (start == end) continue;
    final last = end - 1;

    double closeAfter(int f) =>
        border +
        (f == last ? cards[t].trailingGap : cutPadding + continuedFooterHeight);

    double closeBudget(int f) {
      final nextIsTail =
          f + 1 < end && fragments[f + 1].kind == FlowFragmentKind.tail;
      return nextIsTail
          ? fragments[f + 1].leadingGap + heights[f + 1] + closeAfter(f + 1)
          : closeAfter(f);
    }

    void place(int f) {
      offsets[f] = Offset(innerX(column), y);
      var h = heights[f];
      if (fragments[f].kind == FlowFragmentKind.item) {
        final room = columnHeight - y - closeBudget(f);
        if (h > room) {
          h = room < 0 ? 0 : room;
          if (room < 0) hasOverflow = true;
        }
      }
      layoutHeights[f] = h;
      y += h;
      if (y > columnHeight) hasOverflow = true;
    }

    var headEnd = last;
    for (var f = start; f < end; f++) {
      if (fragments[f].kind == FlowFragmentKind.item) {
        headEnd = f;
        break;
      }
    }
    var headNeed = border + closeAfter(headEnd);
    for (var f = start; f <= headEnd; f++) {
      headNeed += fragments[f].leadingGap + heights[f];
    }
    if (y > 0 && y + headNeed > columnHeight) {
      column++;
      y = 0;
    }

    var runTop = y;
    var runStart = start;
    var isContinuation = false;
    y += border;
    for (var f = start; f <= headEnd; f++) {
      y += fragments[f].leadingGap;
      place(f);
    }

    for (var f = headEnd + 1; f < end; f++) {
      final need = fragments[f].leadingGap + heights[f] + closeBudget(f);
      if (y + need > columnHeight) {
        runs.add(
          FlowRun(
            cardIndex: t,
            column: column,
            top: runTop,
            bottom: y + cutPadding + continuedFooterHeight + border,
            isContinuation: isContinuation,
            continues: true,
            lockedOverlayBottom: y + cutPadding + continuedFooterHeight,
            fragmentStart: runStart,
            fragmentEnd: f,
          ),
        );
        column++;
        y = 0;
        runTop = 0;
        runStart = f;
        isContinuation = true;
        y += border + continuedBandHeight + continuedTopPadding;
      } else {
        y += fragments[f].leadingGap;
      }
      place(f);
    }

    y += cards[t].trailingGap + border;
    final endsWithTail = fragments[last].kind == FlowFragmentKind.tail;
    runs.add(
      FlowRun(
        cardIndex: t,
        column: column,
        top: runTop,
        bottom: y,
        isContinuation: isContinuation,
        continues: false,
        lockedOverlayBottom: endsWithTail ? offsets[last].dy : y - border,
        fragmentStart: runStart,
        fragmentEnd: end,
      ),
    );
    y += spacing;
  }

  final usedColumns = runs.isEmpty ? 0 : column + 1;
  final width = usedColumns == 0
      ? 0.0
      : usedColumns * columnWidth + spacing * (usedColumns - 1);
  return FlowPackResult(
    offsets: offsets,
    layoutHeights: layoutHeights,
    runs: runs,
    usedColumns: usedColumns,
    width: width,
    hasOverflow: hasOverflow,
  );
}
