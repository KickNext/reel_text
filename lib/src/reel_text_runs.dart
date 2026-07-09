part of 'reel_text.dart';

class _SettledReelText extends StatelessWidget {
  const _SettledReelText({
    super.key,
    required this.run,
    required this.layout,
  });

  final _MeasuredReelTextRun run;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
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
            baselineFor: runMetrics.baselineFor,
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
        minHeight: 0,
        maxHeight: double.infinity,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(child.size.width, math.max(height, child.size.height)),
    );

    final childParentData = child.parentData! as BoxParentData;
    childParentData.offset = alignment.alongOffset(
      Offset(
        size.width - child.size.width,
        size.height - child.size.height,
      ),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.constrain(Size(0, height));
    }

    final childSize = child.getDryLayout(
      const BoxConstraints(
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: double.infinity,
      ),
    );
    return constraints.constrain(
      Size(childSize.width, math.max(height, childSize.height)),
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
            animation: animation,
            totalDurationMs: plan.totalDuration.inMilliseconds,
            layout: layout,
          ),
      ],
    );
    return AnimatedBuilder(
      animation: animation,
      child: rollingRow,
      builder: (context, child) {
        final progressMs = animation.value * plan.totalDuration.inMilliseconds;
        final width = _rollingWidth(progressMs);
        if (hasWidgetSlots) {
          return _SettledTokenRowViewport(
            height: height,
            alignment: anchorShrinkingRight
                ? layout.inlineStartAlignment
                : _alignmentForTextAlign(textAlign, layout.textDirection),
            child: child!,
          );
        }
        final viewportWidth = anchorShrinkingRight ? toRun.width : width;
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
            maxHeight: double.infinity,
            child: child!,
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
