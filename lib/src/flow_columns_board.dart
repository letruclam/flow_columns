import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'column_flow_packer.dart';

/// Look of the grey band that opens or closes a cut card.
class FlowBandStyle {
  const FlowBandStyle({
    this.height = 36,
    this.color = const Color(0xFFF5F5F5),
    this.textStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF000000),
    ),
    this.textInset = 12,
  });

  final double height;
  final Color color;
  final TextStyle textStyle;

  /// Horizontal inset of the label inside the band.
  final double textInset;

  @override
  bool operator ==(Object other) =>
      other is FlowBandStyle &&
      other.height == height &&
      other.color == color &&
      other.textStyle == textStyle &&
      other.textInset == textInset;

  @override
  int get hashCode => Object.hash(height, color, textStyle, textInset);
}

/// Per-card look. Blocking input on a locked card is up to the caller (wrap
/// its fragments in [AbsorbPointer]); [isLocked] only paints the overlay.
class FlowCardStyle {
  const FlowCardStyle({
    required this.borderColor,
    this.isLocked = false,
    required this.trailingGap,
  });

  final Color borderColor;
  final bool isLocked;

  /// Space between the last fragment and the bottom border of the card.
  final double trailingGap;
}

class FlowColumnsParentData extends ContainerBoxParentData<RenderBox> {
  int cardIndex = 0;
  FlowFragmentKind kind = FlowFragmentKind.item;
  double leadingGap = 0;

  /// Text of the opening band when a continuation starts with this fragment.
  String continuedLabel = '';
}

/// A fragment of a card on a [FlowColumnsBoard].
///
/// An [FlowFragmentKind.item] fragment is wrapped in a vertical scroll view:
/// it scrolls when the board caps it to the room left in its column. Item
/// fragments are measured with a dry layout, so they must not contain widgets
/// without one (for example [LayoutBuilder]); head and tail fragments may.
class FlowFragment extends StatelessWidget {
  const FlowFragment({
    super.key,
    required this.cardIndex,
    required this.kind,
    this.leadingGap = 0,
    this.continuedLabel = '',
    required this.child,
  });

  final int cardIndex;
  final FlowFragmentKind kind;
  final double leadingGap;

  /// Text of the opening band if a continuation starts with this fragment.
  /// Empty falls back to [FlowColumnsBoard.continuedLabel].
  final String continuedLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _FlowFragmentParentData(
      cardIndex: cardIndex,
      kind: kind,
      leadingGap: leadingGap,
      continuedLabel: continuedLabel,
      child: kind == FlowFragmentKind.item
          ? Scrollbar(child: SingleChildScrollView(child: child))
          : child,
    );
  }
}

class _FlowFragmentParentData extends ParentDataWidget<FlowColumnsParentData> {
  const _FlowFragmentParentData({
    required this.cardIndex,
    required this.kind,
    required this.leadingGap,
    required this.continuedLabel,
    required super.child,
  });

  final int cardIndex;
  final FlowFragmentKind kind;
  final double leadingGap;
  final String continuedLabel;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData;
    if (parentData is! FlowColumnsParentData) return;
    final target = renderObject.parent;
    if (parentData.cardIndex != cardIndex ||
        parentData.kind != kind ||
        parentData.leadingGap != leadingGap) {
      parentData.cardIndex = cardIndex;
      parentData.kind = kind;
      parentData.leadingGap = leadingGap;
      parentData.continuedLabel = continuedLabel;
      if (target is RenderObject) target.markNeedsLayout();
    } else if (parentData.continuedLabel != continuedLabel) {
      parentData.continuedLabel = continuedLabel;
      if (target is RenderObject) target.markNeedsPaint();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FlowColumnsBoard;
}

/// Lays [FlowFragment] children out in columns of [columnWidth] ×
/// [columnHeight]. Fragments are grouped by card, in order; a card that does
/// not fit the room left in its column is cut between item fragments and
/// continues in the next column under a band. The board is as wide as the
/// columns it uses, so it usually sits in a horizontal scroll view.
class FlowColumnsBoard extends MultiChildRenderObjectWidget {
  const FlowColumnsBoard({
    super.key,
    required this.cards,
    required this.columnWidth,
    required this.columnHeight,
    required this.spacing,
    this.borderWidth = 2,
    this.radius = 16,
    this.fillColor = const Color(0xFFFFFFFF),
    this.lockOverlayColor = const Color(0x809E9E9E),
    this.topBand = const FlowBandStyle(),
    this.bottomBand = const FlowBandStyle(),
    this.showTopBand = true,
    this.showBottomBand = true,
    this.continuedLabel = 'Continued...',
    this.cutPadding = 8,
    this.continuedTopPadding = 8,
    super.children,
  });

  final List<FlowCardStyle> cards;
  final double columnWidth;
  final double columnHeight;
  final double spacing;
  final double borderWidth;
  final double radius;
  final Color fillColor;
  final Color lockOverlayColor;

  /// Band opening a continuation; its text is the fragment's
  /// [FlowFragment.continuedLabel] or [continuedLabel].
  final FlowBandStyle topBand;

  /// Band closing a cut run; its text is always [continuedLabel].
  final FlowBandStyle bottomBand;

  /// Whether [topBand] is drawn and reserved above a continuation.
  final bool showTopBand;

  /// Whether [bottomBand] is drawn and reserved at the bottom of a cut run.
  final bool showBottomBand;
  final String continuedLabel;

  /// Space kept between the last fragment of a cut run and the bottom band.
  final double cutPadding;

  /// Space between the top band and the first fragment of a continuation.
  final double continuedTopPadding;

  @override
  RenderFlowColumnsBoard createRenderObject(BuildContext context) {
    return RenderFlowColumnsBoard(
      cards: cards,
      columnWidth: columnWidth,
      columnHeight: columnHeight,
      spacing: spacing,
      borderWidth: borderWidth,
      radius: radius,
      fillColor: fillColor,
      lockOverlayColor: lockOverlayColor,
      topBand: topBand,
      bottomBand: bottomBand,
      showTopBand: showTopBand,
      showBottomBand: showBottomBand,
      continuedLabel: continuedLabel,
      cutPadding: cutPadding,
      continuedTopPadding: continuedTopPadding,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFlowColumnsBoard renderObject,
  ) {
    renderObject
      ..cards = cards
      ..columnWidth = columnWidth
      ..columnHeight = columnHeight
      ..spacing = spacing
      ..borderWidth = borderWidth
      ..radius = radius
      ..fillColor = fillColor
      ..lockOverlayColor = lockOverlayColor
      ..topBand = topBand
      ..bottomBand = bottomBand
      ..showTopBand = showTopBand
      ..showBottomBand = showBottomBand
      ..continuedLabel = continuedLabel
      ..cutPadding = cutPadding
      ..continuedTopPadding = continuedTopPadding
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context);
  }
}

class RenderFlowColumnsBoard extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FlowColumnsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FlowColumnsParentData> {
  RenderFlowColumnsBoard({
    required List<FlowCardStyle> cards,
    required double columnWidth,
    required double columnHeight,
    required double spacing,
    required double borderWidth,
    required double radius,
    required Color fillColor,
    required Color lockOverlayColor,
    required FlowBandStyle topBand,
    required FlowBandStyle bottomBand,
    required bool showTopBand,
    required bool showBottomBand,
    required String continuedLabel,
    required double cutPadding,
    required double continuedTopPadding,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) : _cards = cards,
       _columnWidth = columnWidth,
       _columnHeight = columnHeight,
       _spacing = spacing,
       _borderWidth = borderWidth,
       _radius = radius,
       _fillColor = fillColor,
       _lockOverlayColor = lockOverlayColor,
       _topBand = topBand,
       _bottomBand = bottomBand,
       _showTopBand = showTopBand,
       _showBottomBand = showBottomBand,
       _continuedLabel = continuedLabel,
       _cutPadding = cutPadding,
       _continuedTopPadding = continuedTopPadding,
       _textDirection = textDirection,
       _textScaler = textScaler;

  List<FlowCardStyle> _cards;
  set cards(List<FlowCardStyle> value) {
    if (identical(_cards, value)) return;
    final needsLayout =
        value.length != _cards.length ||
        Iterable<int>.generate(
          value.length,
        ).any((i) => value[i].trailingGap != _cards[i].trailingGap);
    _cards = value;
    needsLayout ? markNeedsLayout() : markNeedsPaint();
  }

  double _columnWidth;
  set columnWidth(double value) {
    if (_columnWidth == value) return;
    _columnWidth = value;
    _disposePainters();
    markNeedsLayout();
  }

  double _columnHeight;
  set columnHeight(double value) {
    if (_columnHeight == value) return;
    _columnHeight = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _borderWidth;
  set borderWidth(double value) {
    if (_borderWidth == value) return;
    _borderWidth = value;
    _disposePainters();
    markNeedsLayout();
  }

  double _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  Color _fillColor;
  set fillColor(Color value) {
    if (_fillColor == value) return;
    _fillColor = value;
    markNeedsPaint();
  }

  Color _lockOverlayColor;
  set lockOverlayColor(Color value) {
    if (_lockOverlayColor == value) return;
    _lockOverlayColor = value;
    markNeedsPaint();
  }

  FlowBandStyle _topBand;
  set topBand(FlowBandStyle value) {
    if (_topBand == value) return;
    final needsLayout = _topBand.height != value.height;
    _topBand = value;
    _disposePainters();
    needsLayout ? markNeedsLayout() : markNeedsPaint();
  }

  FlowBandStyle _bottomBand;
  set bottomBand(FlowBandStyle value) {
    if (_bottomBand == value) return;
    final needsLayout = _bottomBand.height != value.height;
    _bottomBand = value;
    _disposePainters();
    needsLayout ? markNeedsLayout() : markNeedsPaint();
  }

  bool _showTopBand;
  set showTopBand(bool value) {
    if (_showTopBand == value) return;
    _showTopBand = value;
    markNeedsLayout();
  }

  bool _showBottomBand;
  set showBottomBand(bool value) {
    if (_showBottomBand == value) return;
    _showBottomBand = value;
    markNeedsLayout();
  }

  String _continuedLabel;
  set continuedLabel(String value) {
    if (_continuedLabel == value) return;
    _continuedLabel = value;
    markNeedsPaint();
  }

  double _cutPadding;
  set cutPadding(double value) {
    if (_cutPadding == value) return;
    _cutPadding = value;
    markNeedsLayout();
  }

  double _continuedTopPadding;
  set continuedTopPadding(double value) {
    if (_continuedTopPadding == value) return;
    _continuedTopPadding = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _disposePainters();
    markNeedsPaint();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    _disposePainters();
    markNeedsPaint();
  }

  FlowPackResult? _pack;
  final Map<(String, FlowBandStyle), TextPainter> _painters = {};

  void _disposePainters() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }

  /// Runs of the last layout.
  @visibleForTesting
  List<FlowRun> get debugRuns => _pack?.runs ?? const [];

  /// Text of the band opening [run], or null when [run] is not a
  /// continuation or the top band is hidden.
  @visibleForTesting
  String? debugContinuedLabel(FlowRun run) {
    if (!run.isContinuation || !_showTopBand) return null;
    return _labelFor(_fragmentAt(run.fragmentStart));
  }

  String _labelFor(FlowColumnsParentData pd) =>
      pd.continuedLabel.isEmpty ? _continuedLabel : pd.continuedLabel;

  FlowColumnsParentData _fragmentAt(int index) {
    var child = firstChild;
    for (var i = 0; i < index; i++) {
      child = childAfter(child!);
    }
    return child!.parentData! as FlowColumnsParentData;
  }

  double get _innerWidth => _columnWidth - 2 * _borderWidth;

  BoxConstraints get _childConstraints =>
      BoxConstraints.tightFor(width: _innerWidth);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FlowColumnsParentData) {
      child.parentData = FlowColumnsParentData();
    }
  }

  FlowPackResult _packWith(List<double> heights) {
    final fragments = <FlowFragmentSpec>[];
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as FlowColumnsParentData;
      fragments.add(
        FlowFragmentSpec(
          cardIndex: pd.cardIndex,
          kind: pd.kind,
          leadingGap: pd.leadingGap,
        ),
      );
      child = pd.nextSibling;
    }
    return packColumnFlow(
      fragments: fragments,
      heights: heights,
      cards: [
        for (final card in _cards) FlowCardSpec(trailingGap: card.trailingGap),
      ],
      columnWidth: _columnWidth,
      columnHeight: _columnHeight,
      spacing: _spacing,
      border: _borderWidth,
      continuedBandHeight: _showTopBand ? _topBand.height : 0,
      continuedFooterHeight: _showBottomBand ? _bottomBand.height : 0,
      cutPadding: _cutPadding,
      continuedTopPadding: _continuedTopPadding,
    );
  }

  @override
  void performLayout() {
    final heights = <double>[];
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as FlowColumnsParentData;
      if (pd.kind == FlowFragmentKind.item) {
        heights.add(child.getDryLayout(_childConstraints).height);
      } else {
        child.layout(_childConstraints, parentUsesSize: true);
        heights.add(child.size.height);
      }
      child = pd.nextSibling;
    }
    final pack = _packWith(heights);
    _pack = pack;

    var i = 0;
    child = firstChild;
    while (child != null) {
      final pd = child.parentData! as FlowColumnsParentData;
      if (pd.kind == FlowFragmentKind.item) {
        final layoutHeight = pack.layoutHeights[i];
        child.layout(
          layoutHeight < heights[i]
              ? BoxConstraints.tightFor(
                  width: _innerWidth,
                  height: layoutHeight,
                )
              : _childConstraints,
          parentUsesSize: true,
        );
      }
      pd.offset = pack.offsets[i++];
      child = pd.nextSibling;
    }
    size = constraints.constrain(Size(pack.width, _columnHeight));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final heights = <double>[];
    var child = firstChild;
    while (child != null) {
      heights.add(child.getDryLayout(_childConstraints).height);
      child = childAfter(child);
    }
    return constraints.constrain(Size(_packWith(heights).width, _columnHeight));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      childCount == 0 ? 0 : _columnWidth;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeDryLayout(const BoxConstraints()).width;

  @override
  double computeMinIntrinsicHeight(double width) => _columnHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _columnHeight;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  TextPainter _painterFor(String label, FlowBandStyle band) {
    return _painters[(label, band)] ??= TextPainter(
      text: TextSpan(text: label, style: band.textStyle),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: _innerWidth - 2 * band.textInset);
  }

  void _paintBand(
    Canvas canvas,
    Rect runRect, {
    required double top,
    required FlowBandStyle band,
    required String label,
  }) {
    final rect = Rect.fromLTWH(
      runRect.left + _borderWidth,
      top,
      _innerWidth,
      band.height,
    );
    canvas.drawRect(rect, Paint()..color = band.color);
    final painter = _painterFor(label, band);
    painter.paint(
      canvas,
      Offset(
        rect.left + band.textInset,
        rect.top + (band.height - painter.height) / 2,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final pack = _pack;
    if (pack == null) return;
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => _paintRuns(context, offset, pack),
    );
  }

  void _paintRuns(PaintingContext context, Offset offset, FlowPackResult pack) {
    final children = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }

    final fill = Paint()..color = _fillColor;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;
    final lockOverlay = Paint()..color = _lockOverlayColor;

    for (final run in pack.runs) {
      final card = _cards[run.cardIndex];
      final left = offset.dx + run.column * (_columnWidth + _spacing);
      final rect = Rect.fromLTRB(
        left,
        offset.dy + run.top,
        left + _columnWidth,
        offset.dy + run.bottom,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(_radius));

      context.pushClipRRect(needsCompositing, Offset.zero, rect, rrect, (
        context,
        _,
      ) {
        final canvas = context.canvas;
        canvas.drawRRect(rrect, fill);

        if (run.isContinuation && _showTopBand) {
          _paintBand(
            canvas,
            rect,
            top: rect.top + _borderWidth,
            band: _topBand,
            label: _labelFor(
              children[run.fragmentStart].parentData! as FlowColumnsParentData,
            ),
          );
        }
        if (run.continues && _showBottomBand) {
          _paintBand(
            canvas,
            rect,
            top: rect.bottom - _borderWidth - _bottomBand.height,
            band: _bottomBand,
            label: _continuedLabel,
          );
        }

        for (var i = run.fragmentStart; i < run.fragmentEnd; i++) {
          final fragment = children[i];
          final pd = fragment.parentData! as FlowColumnsParentData;
          context.paintChild(fragment, pd.offset + offset);
        }

        final overlayCanvas = context.canvas;
        if (card.isLocked) {
          overlayCanvas.drawRect(
            Rect.fromLTRB(
              rect.left + _borderWidth,
              rect.top + _borderWidth,
              rect.right - _borderWidth,
              offset.dy + run.lockedOverlayBottom,
            ),
            lockOverlay,
          );
        }

        overlayCanvas.drawRRect(
          rrect.deflate(_borderWidth / 2),
          stroke..color = card.borderColor,
        );
      });
    }
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }
}
