## 0.1.0

- Initial release.
- `packColumnFlow`: pure Dart packing of card fragments into columns, cutting
  a card only between item fragments and keeping head/tail fragments with
  their neighbours.
- `FlowColumnsBoard` / `FlowFragment`: render the packed cards with a
  "Continued" band at each cut, a lock overlay per card and item fragments
  that scroll when taller than the room left in a column.
