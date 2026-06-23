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

    if (content.hasWidgets) {
      return tokenRow;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? math.min(runMetrics.width, constraints.maxWidth)
            : runMetrics.width;
        return SizedBox(
          width: viewportWidth,
          height: runMetrics.height,
          child: OverflowBox(
            alignment: layout.inlineStartAlignment,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: runMetrics.height,
            maxHeight: runMetrics.height,
            child: tokenRow,
          ),
        );
      },
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
