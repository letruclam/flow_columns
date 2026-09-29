# flow_columns

[![pub package](https://img.shields.io/pub/v/flow_columns.svg)](https://pub.dev/packages/flow_columns)

Lay cards out in fixed-width columns and flow a card that does not fit across
the next columns, the way a newspaper continues an article. Each cut gets a
"Continued" band at the bottom of the cut part and at the top of the part that
follows. Built for kitchen display screens, where a long order must never be
hidden behind an inner scroll but must also never split an item from its
modifiers.

![A 15-item ticket flowing across three columns on a kitchen display](https://raw.githubusercontent.com/letruclam/flow_columns/main/screenshots/kitchen_board.jpg)

```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Ticket #1233 │ │ Continued... │ │ Ticket #1240 │
│ 1  Salmon    │ │ 3  Soy sauce │ │ 2  Ramen     │
│    x Wasabi  │ │ 1  Green tea │ │              │
│ 2  Tuna roll │ │──────────────│ └──────────────┘
│──────────────│ │ Not submitted│
│ Continued... │ └──────────────┘
└──────────────┘
```

The "Continued..." bands belong to the board and can be relabelled or hidden.
"Not submitted" is a tail fragment supplied by the app, like every other row.

## Features

- Fixed-width columns filled top to bottom; a full column wraps to the next
  one on the right, so the board grows horizontally.
- A card is cut only **between item fragments**. Head fragments (header,
  bands) stay together with the first item, and a tail fragment (footer)
  travels with the last item, so neither is ever left alone at the top of a
  column.
- An item taller than the room left in a column is capped to that room and
  **scrolls inside** instead of being clipped.
- Bands at each cut with a default or per-fragment label ("Split #2 ·
  Continued", for example).
- Optional lock overlay per card.
- The packing algorithm is a pure Dart function you can unit test on its own.

## Usage

Every card is a list of `FlowFragment` widgets in display order. Give each one
the card's index, a kind and the gap above it.

```dart
import 'package:flow_columns/flow_columns.dart';

SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: FlowColumnsBoard(
    columnWidth: 320,
    columnHeight: 720,
    spacing: 8,
    cards: [
      for (final order in orders)
        FlowCardStyle(
          borderColor: Colors.grey.shade400,
          isLocked: order.isPending,
          trailingGap: 24,
        ),
    ],
    children: [
      for (final (i, order) in orders.indexed) ...[
        FlowFragment(
          cardIndex: i,
          kind: FlowFragmentKind.head,
          child: OrderHeader(order),
        ),
        for (final (j, line) in order.lines.indexed)
          FlowFragment(
            cardIndex: i,
            kind: FlowFragmentKind.item,
            leadingGap: j == 0 ? 8 : 12,
            child: OrderLine(line),
          ),
        if (order.isPending)
          FlowFragment(
            cardIndex: i,
            kind: FlowFragmentKind.tail,
            leadingGap: 24,
            child: const PendingFooter(),
          ),
      ],
    ],
  ),
)
```

### Fragment kinds

| Kind | Meaning |
|---|---|
| `head` | Opens the card. All head fragments of a card and its first item are kept together: if they do not fit the room left in a column, the whole card moves to the next column. |
| `item` | Where the card may be cut. An item is never split; one taller than the room left in its column is capped and scrolls inside. |
| `tail` | Closes the card and always sits in the same column as the last item. |

`leadingGap` is the space above a fragment when it follows another fragment
of the same card in the same column. It is dropped when the fragment opens a
continuation, which starts right under the band plus `continuedTopPadding`.

`FlowCardStyle.trailingGap` is the space between the last fragment and the
bottom border of the card.

### Bands and labels

`topBand` and `bottomBand` (`FlowBandStyle`) set the height, colour, text
style and text inset of the bands. The bottom band always shows
`FlowColumnsBoard.continuedLabel`. The top band shows the
`FlowFragment.continuedLabel` of the fragment that opens the continuation, or
`continuedLabel` when that is empty. An empty label draws a band without text.

`showTopBand` and `showBottomBand` (default `true`) hide a band entirely: it
is neither drawn nor reserved, so items get its room back. `cutPadding` and
`continuedTopPadding` still apply, so set them to `0` for a flush cut.

```dart
FlowColumnsBoard(
  continuedLabel: 'See next column',
  showBottomBand: false,
  ...
)
```

### Item fragments and dry layout

Item fragments are wrapped in a vertical `SingleChildScrollView` with a
`Scrollbar` and measured with a dry layout, so they must not contain widgets
without one (such as `LayoutBuilder`). Head and tail fragments are laid out
for real and have no such restriction.

### Locked cards

`FlowCardStyle.isLocked` paints `lockOverlayColor` over the card body,
excluding the tail fragment. It does not block input: wrap the fragments in
`AbsorbPointer` yourself if you need that.

### Packing without widgets

`packColumnFlow` is the algorithm behind the board. Feed it fragment specs and
measured heights and it returns offsets, layout heights, runs (the parts each
card is cut into, with their columns and band flags), the number of columns
used and the total width.

```dart
final result = packColumnFlow(
  fragments: [
    const FlowFragmentSpec(cardIndex: 0, kind: FlowFragmentKind.head),
    const FlowFragmentSpec(cardIndex: 0, kind: FlowFragmentKind.item, leadingGap: 8),
    const FlowFragmentSpec(cardIndex: 0, kind: FlowFragmentKind.item, leadingGap: 12),
  ],
  heights: [60, 40, 40],
  cards: const [FlowCardSpec(trailingGap: 24)],
  columnWidth: 320,
  columnHeight: 200,
  spacing: 8,
);
print(result.runs.length); // 1
```

## Testing

`RenderFlowColumnsBoard.debugRuns` and `debugContinuedLabel(run)` are
`@visibleForTesting` and expose the runs of the last layout, so a widget test
can assert where a card was cut and what its band says.
