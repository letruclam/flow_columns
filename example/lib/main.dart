import 'package:flow_columns/flow_columns.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BoardPage(),
    );
  }
}

/// Orders of different lengths; the third one is long enough to be cut.
final _orders = <({String title, List<String> lines, bool pending})>[
  (title: 'Ticket #1233', lines: ['Salmon sushi', 'Green tea'], pending: false),
  (
    title: 'Ticket #1234',
    lines: [for (var i = 1; i <= 6; i++) 'Dish $i'],
    pending: true,
  ),
  (
    title: 'Ticket #1235',
    lines: [for (var i = 1; i <= 24; i++) 'Dish $i'],
    pending: false,
  ),
  (title: 'Ticket #1236', lines: ['Ramen', 'Gyoza', 'Beer'], pending: false),
];

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  int _columns = 3;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('flow_columns'),
        actions: [
          for (final n in [2, 3, 4])
            TextButton(
              onPressed: () => setState(() => _columns = n),
              child: Text(
                '$n col',
                style: TextStyle(
                  fontWeight: n == _columns ? FontWeight.bold : null,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(spacing),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth =
                (constraints.maxWidth - spacing * (_columns - 1)) / _columns;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FlowColumnsBoard(
                columnWidth: columnWidth,
                columnHeight: constraints.maxHeight,
                spacing: spacing,
                cards: [
                  for (final order in _orders)
                    FlowCardStyle(
                      borderColor: Colors.blueGrey.shade200,
                      isLocked: order.pending,
                      trailingGap: order.pending ? 0 : 16,
                    ),
                ],
                children: [
                  for (final (i, order) in _orders.indexed) ...[
                    FlowFragment(
                      cardIndex: i,
                      kind: FlowFragmentKind.head,
                      child: _Header(
                        order.title,
                        itemCount: order.lines.length,
                      ),
                    ),
                    for (final (j, line) in order.lines.indexed)
                      FlowFragment(
                        cardIndex: i,
                        kind: FlowFragmentKind.item,
                        leadingGap: j == 0 ? 8 : 12,
                        child: _Line(index: j + 1, text: line),
                      ),
                    if (order.pending)
                      FlowFragment(
                        cardIndex: i,
                        kind: FlowFragmentKind.tail,
                        leadingGap: 16,
                        child: const _Footer(),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {required this.itemCount});

  final String title;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Text(
            '$itemCount items',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$index'),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: const Text(
        'Not submitted',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }
}
