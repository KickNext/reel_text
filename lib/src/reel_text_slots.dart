part of 'reel_text.dart';

class _SettledTokenSlot extends StatelessWidget {
  const _SettledTokenSlot(
    this.token, {
    required this.width,
    required this.height,
    required this.baselineFor,
    required this.layout,
    required this.index,
  });

  final _ReelTextToken token;
  final double width;
  final double height;
  final double Function(TextBaseline? baseline) baselineFor;
  final _ReelTextLayoutContext layout;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (token.isWidget) {
      return _WidgetSpanFace(
        token.widgetSpan!,
        index: index,
        style: token.style,
        lineHeight: height,
        lineBaseline: baselineFor(token.widgetSpan!.baseline),
        layout: layout,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: layout.inlineStartAlignment,
        child: _TextTokenFace(
          token.text,
          width: width,
          height: height,
          horizontalBleed: _horizontalTextTokenBleed(height),
          style: token.style,
          layout: layout,
        ),
      ),
    );
  }
}

class _RollingTokenSlot extends StatelessWidget {
  const _RollingTokenSlot({
    required this.slot,
    required this.fromRun,
    required this.toRun,
    required this.animation,
    required this.totalDurationMs,
    required this.layout,
  });

  final _SlotPlan slot;
  final _MeasuredReelTextRun fromRun;
  final _MeasuredReelTextRun toRun;
  final Animation<double> animation;
  final int totalDurationMs;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    final data = _TokenSlotRenderData(
      slot: slot,
      fromEndpoint: slot.from,
      toEndpoint: slot.to,
      fromToken: fromRun.tokenFor(slot.from),
      toToken: toRun.tokenFor(slot.to),
      metrics: _SlotMetrics(
        fromWidth: fromRun.widthFor(slot.from),
        toWidth: toRun.widthFor(slot.to),
        height: math.max(fromRun.height, toRun.height),
      ),
    );
    if (!slot.changed) {
      return _buildUnchanged(data);
    }
    if (data.hasWidgetEndpoint) {
      return _buildAtomicSwap(data);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progressMs = animation.value * totalDurationMs;
        return _buildRollingText(context, data, progressMs);
      },
    );
  }

  Widget _buildUnchanged(_TokenSlotRenderData data) {
    if (data.toToken?.isWidget ?? false) {
      return _WidgetSpanFace(
        data.toToken!.widgetSpan!,
        index: data.toEndpoint!.index,
        style: data.toToken!.style,
        lineHeight: data.metrics.height,
        lineBaseline:
            toRun.metrics.baselineFor(data.toToken!.widgetSpan!.baseline),
        layout: layout,
      );
    }

    return SizedBox(
      width: data.metrics.toWidth,
      height: data.metrics.height,
      child: _TextTokenFace(
        data.toText,
        width: data.metrics.toWidth,
        height: data.metrics.height,
        horizontalBleed: _horizontalTextTokenBleed(data.metrics.height),
        style: data.effectiveToStyle,
        layout: layout,
      ),
    );
  }

  Widget _buildAtomicSwap(_TokenSlotRenderData data) {
    final visibleToken = data.toToken ?? data.fromToken;
    final visibleWidth =
        data.toEndpoint == null ? data.metrics.fromWidth : data.metrics.toWidth;
    final visibleIndex = data.toEndpoint?.index ?? data.fromEndpoint?.index;
    if (visibleToken == null || visibleIndex == null) {
      return const SizedBox.shrink();
    }
    if (visibleToken.isWidget) {
      final visibleRun = data.toEndpoint == null ? fromRun : toRun;
      return _WidgetSpanFace(
        visibleToken.widgetSpan!,
        index: visibleIndex,
        style: visibleToken.style,
        lineHeight: data.metrics.height,
        lineBaseline: visibleRun.metrics.baselineFor(
          visibleToken.widgetSpan!.baseline,
        ),
        layout: layout,
      );
    }
    return SizedBox(
      width: visibleWidth,
      height: data.metrics.height,
      child: _TextTokenFace(
        visibleToken.text,
        width: visibleWidth,
        height: data.metrics.height,
        horizontalBleed: _horizontalTextTokenBleed(data.metrics.height),
        style: visibleToken.style,
        layout: layout,
      ),
    );
  }

  Widget _buildRollingText(
    BuildContext context,
    _TokenSlotRenderData data,
    double progressMs,
  ) {
    final width = ui.lerpDouble(
      data.metrics.fromWidth,
      data.metrics.toWidth,
      slot.widthT(progressMs),
    )!;
    final textColor = data.effectiveToStyle.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    final incomingColor = slot.color == null
        ? textColor
        : Color.lerp(slot.color, textColor, slot.colorT(progressMs))!;

    return ClipRect(
      clipper: const _VerticalSlotClipper(),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: data.metrics.height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: layout.inlineStartAlignment,
          children: [
            if (data.fromEndpoint != null)
              Opacity(
                opacity: slot.outOpacity(progressMs),
                child: Transform.translate(
                  offset: Offset(0, slot.outY(progressMs, data.travelDistance)),
                  child: Transform.rotate(
                    angle: -slot.tiltRadians * slot.outT(progressMs),
                    child: _TextTokenFace(
                      data.fromText,
                      width: data.metrics.fromWidth,
                      height: data.metrics.height,
                      horizontalBleed: _horizontalTextTokenBleed(
                        data.metrics.height,
                      ),
                      style: data.effectiveFromStyle,
                      layout: layout,
                    ),
                  ),
                ),
              ),
            if (data.toEndpoint != null)
              Transform.translate(
                offset: Offset(0, slot.inY(progressMs, data.travelDistance)),
                child: Transform.rotate(
                  angle: slot.tiltRadians * (1 - slot.inT(progressMs)),
                  child: _TextTokenFace(
                    data.toText,
                    width: data.metrics.toWidth,
                    height: data.metrics.height,
                    horizontalBleed: _horizontalTextTokenBleed(
                      data.metrics.height,
                    ),
                    style: data.effectiveToStyle.copyWith(
                      color: incomingColor,
                    ),
                    layout: layout,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TokenSlotRenderData {
  const _TokenSlotRenderData({
    required this.slot,
    required this.fromEndpoint,
    required this.toEndpoint,
    required this.fromToken,
    required this.toToken,
    required this.metrics,
  });

  final _SlotPlan slot;
  final _SlotEndpoint? fromEndpoint;
  final _SlotEndpoint? toEndpoint;
  final _ReelTextToken? fromToken;
  final _ReelTextToken? toToken;
  final _SlotMetrics metrics;

  bool get hasWidgetEndpoint =>
      (fromToken?.isWidget ?? false) || (toToken?.isWidget ?? false);

  String get fromText => fromToken?.text ?? fromEndpoint?.text ?? '';

  String get toText => toToken?.text ?? toEndpoint?.text ?? '';

  TextStyle get effectiveToStyle =>
      toToken?.style ?? fromToken?.style ?? const TextStyle();

  TextStyle get effectiveFromStyle => fromToken?.style ?? effectiveToStyle;

  double get travelDistance =>
      metrics.height + _verticalSlotBleed(metrics.height) * 2;
}

class _VerticalSlotClipper extends CustomClipper<Rect> {
  const _VerticalSlotClipper();

  @override
  Rect getClip(Size size) {
    const horizontalBleed = 100000.0;
    final verticalBleed = _verticalSlotBleed(size.height);
    return Rect.fromLTRB(
      -horizontalBleed,
      -verticalBleed,
      size.width + horizontalBleed,
      size.height + verticalBleed,
    );
  }

  @override
  bool shouldReclip(covariant _VerticalSlotClipper oldClipper) => false;
}

double _verticalSlotBleed(double height) => math.max(12, height * 0.38);
double _horizontalTextTokenBleed(double height) => math.max(4, height * 0.08);
