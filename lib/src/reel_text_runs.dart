part of 'reel_text.dart';

class _SettledReelText extends StatelessWidget {
  const _SettledReelText({
    super.key,
    required this.content,
    required this.layout,
  });

  final _ReelTextContent content;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    final run = _MeasuredReelTextRun.of(
      context: context,
      content: content,
      layout: layout,
    );
    final runMetrics = run.metrics;
    final tokenRow = Row(
      key: const ValueKey('reel_text_settled_glyphs'),
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        for (final index in runMetrics.visualOrder)
          _SettledTokenSlot(
            run.content.tokens[index],
            width: runMetrics.widthAt(index),
            height: runMetrics.height,
            layout: layout,
            index: index,
          ),
      ],
    );

    return _SettledTokenRowViewport(
      height: runMetrics.height,
      alignment: layout.inlineStartAlignment,
      child: tokenRow,
    );
  }
}

class _SettledTokenRowViewport extends SingleChildRenderObjectWidget {
  const _SettledTokenRowViewport({
    required this.height,
    required this.alignment,
    required super.child,
  });

  final double height;
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSettledTokenRowViewport(
      height: height,
      alignment: alignment,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSettledTokenRowViewport renderObject,
  ) {
    renderObject
      ..height = height
      ..alignment = alignment;
  }
}

class _RenderSettledTokenRowViewport extends RenderShiftedBox {
  _RenderSettledTokenRowViewport({
    required double height,
    required Alignment alignment,
  })  : _height = height,
        _alignment = alignment,
        super(null);

  double _height;
  Alignment _alignment;

  double get height => _height;

  set height(double value) {
    if (_height == value) {
      return;
    }
    _height = value;
    markNeedsLayout();
  }

  Alignment get alignment => _alignment;

  set alignment(Alignment value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, height));
      return;
    }

    child.layout(
      BoxConstraints(
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: height,
        maxHeight: height,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(child.size.width, height));

    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = alignment.alongOffset(
      Offset(
        size.width - child.size.width,
        size.height - child.size.height,
      ),
    );
  }
}

class _RollingReelText extends StatelessWidget {
  const _RollingReelText({
    required this.plan,
    required this.fromRun,
    required this.toRun,
    required this.animation,
    required this.textAlign,
    required this.layout,
  });

  final _RollPlan plan;
  final _MeasuredReelTextRun fromRun;
  final _MeasuredReelTextRun toRun;
  final Animation<double> animation;
  final TextAlign textAlign;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    final hasWidgetSlots = fromRun.hasWidgets || toRun.hasWidgets;
    final height = math.max(fromRun.height, toRun.height);
    final anchorShrinkingRight =
        _alignsToRight(textAlign, layout.textDirection) &&
            toRun.width < fromRun.width;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progressMs = animation.value * plan.totalDuration.inMilliseconds;
        final width = _rollingWidth(progressMs);
        final viewportWidth = anchorShrinkingRight ? toRun.width : width;
        final rollingRow = Row(
          key: const ValueKey('reel_text_rolling'),
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            for (final slot in plan.slots)
              _RollingTokenSlot(
                slot: slot,
                fromRun: fromRun,
                toRun: toRun,
                progressMs: progressMs,
                layout: layout,
              ),
          ],
        );
        if (hasWidgetSlots) {
          return ClipRect(
            child: Align(
              alignment: anchorShrinkingRight
                  ? layout.inlineStartAlignment
                  : _alignmentForTextAlign(textAlign, layout.textDirection),
              widthFactor: 1,
              heightFactor: 1,
              child: rollingRow,
            ),
          );
        }
        return SizedBox(
          width: viewportWidth,
          height: height,
          child: OverflowBox(
            alignment: anchorShrinkingRight
                ? layout.inlineStartAlignment
                : _alignmentForTextAlign(textAlign, layout.textDirection),
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: height,
            maxHeight: height,
            child: rollingRow,
          ),
        );
      },
    );
  }

  double _rollingWidth(double progressMs) {
    return plan.slots.fold<double>(0, (sum, slot) {
      final fromWidth = fromRun.widthFor(slot.from);
      final toWidth = toRun.widthFor(slot.to);
      if (!slot.changed) {
        return sum + toWidth;
      }
      return sum + ui.lerpDouble(fromWidth, toWidth, slot.widthT(progressMs))!;
    });
  }
}
