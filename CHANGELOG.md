## 0.2.2

- Show the kitchen board screenshot in README.

## 0.2.1

- Add a pub.dev screenshot of the board on a kitchen display.
- Exclude `CLAUDE.md` from the published package.

## 0.2.0

- `FlowColumnsBoard.showTopBand` / `showBottomBand` hide a band without
  drawing or reserving it.
- README states that the tail row is app-supplied and how to relabel or
  hide the bands.

## 0.1.0

- Initial release.
- `packColumnFlow`: pure Dart packing of card fragments into columns, cutting
  a card only between item fragments and keeping head/tail fragments with
  their neighbours.
- `FlowColumnsBoard` / `FlowFragment`: render the packed cards with a
  "Continued" band at each cut, a lock overlay per card and item fragments
  that scroll when taller than the room left in a column.
