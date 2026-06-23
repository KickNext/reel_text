part of 'reel_text.dart';

class _TextTokenFace extends StatelessWidget {
  const _TextTokenFace(
    this.text, {
    required this.width,
    required this.height,
    this.horizontalBleed = 0,
    required this.style,
    required this.layout,
  });

  final String text;
  final double width;
  final double height;
  final double horizontalBleed;
  final TextStyle style;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    final paintWidth = width + horizontalBleed;
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        alignment: layout.inlineStartAlignment,
        minWidth: paintWidth,
        maxWidth: paintWidth,
        minHeight: height,
        maxHeight: height,
        child: SizedBox(
          width: paintWidth,
          height: height,
          child: ExcludeSemantics(
            child: _TextTokenText(
              text,
              style: style,
              layout: layout,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextTokenText extends StatelessWidget {
  const _TextTokenText(
    this.text, {
    required this.style,
    required this.layout,
  });

  final String text;
  final TextStyle style;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textDirection: layout.textDirection,
      textAlign: TextAlign.start,
      locale: layout.locale,
      strutStyle: layout.strutStyle,
      softWrap: false,
    );
  }
}

class _WidgetSpanFace extends StatelessWidget {
  const _WidgetSpanFace(
    this.span, {
    required this.index,
    required this.style,
    required this.lineHeight,
    required this.lineBaseline,
    required this.layout,
  });

  final WidgetSpan span;
  final int index;
  final TextStyle style;
  final double lineHeight;
  final double lineBaseline;
  final _ReelTextLayoutContext layout;

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = _widgetSpanTextScaleFactor(
      MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
      style,
    );
    final observer = _WidgetSpanSizeObserver(
      identity: span,
      onMetricsChanged: (metrics) =>
          layout.onWidgetSpanMetricsChanged(index, span, metrics),
      child: _ScaledWidgetSpanChild(
        span: span,
        textScaleFactor: textScaleFactor,
        child: span.child,
      ),
    );
    final defaultFace = Align(
      widthFactor: 1,
      heightFactor: 1,
      alignment: _placeholderAlignment(span.alignment),
      child: observer,
    );
    final metrics = layout.widgetSpanMetricsFor(index, span);
    if (metrics == null) {
      return defaultFace;
    }

    return SizedBox(
      width: metrics.size.width,
      height: lineHeight,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(
            0,
            _placeholderOffsetY(span, metrics),
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            alignment: Alignment.topCenter,
            child: observer,
          ),
        ),
      ),
    );
  }

  double _placeholderOffsetY(WidgetSpan span, _WidgetSpanMetrics metrics) {
    final height = metrics.size.height;
    return switch (span.alignment) {
      ui.PlaceholderAlignment.top => 0,
      ui.PlaceholderAlignment.middle => (lineHeight - height) / 2,
      ui.PlaceholderAlignment.bottom => lineHeight - height,
      ui.PlaceholderAlignment.baseline =>
        lineBaseline - (metrics.baselineOffset ?? height),
      ui.PlaceholderAlignment.aboveBaseline => lineBaseline - height,
      ui.PlaceholderAlignment.belowBaseline => lineBaseline,
    };
  }
}

class _ScaledWidgetSpanChild extends SingleChildRenderObjectWidget {
  const _ScaledWidgetSpanChild({
    required this.span,
    required this.textScaleFactor,
    required super.child,
  });

  final WidgetSpan span;
  final double textScaleFactor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScaledWidgetSpanChild(textScaleFactor);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderScaledWidgetSpanChild renderObject,
  ) {
    renderObject.scale = textScaleFactor;
  }
}

class _RenderScaledWidgetSpanChild extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderScaledWidgetSpanChild(double scale) : _scale = scale;

  double get scale => _scale;
  double _scale;
  set scale(double value) {
    if (_scale == value) {
      return;
    }
    _scale = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    child.layout(
      BoxConstraints(maxWidth: constraints.maxWidth / scale),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(child.size.width * scale, child.size.height * scale),
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final childBaseline = child?.getDistanceToActualBaseline(baseline);
    return childBaseline == null ? null : childBaseline * scale;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(Matrix4.diagonal3Values(scale, scale, scale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      layer = null;
      return;
    }
    if (scale == 1) {
      context.paintChild(child, offset);
      layer = null;
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(scale, scale, 1),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) {
      return false;
    }
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(scale, scale, 1),
      position: position,
      hitTest: (result, transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }
}

class _WidgetSpanSizeObserver extends SingleChildRenderObjectWidget {
  const _WidgetSpanSizeObserver({
    required this.identity,
    required this.onMetricsChanged,
    required super.child,
  });

  final WidgetSpan identity;
  final ValueChanged<_WidgetSpanMetrics> onMetricsChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderWidgetSpanSizeObserver(identity, onMetricsChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWidgetSpanSizeObserver renderObject,
  ) {
    renderObject
      ..identity = identity
      ..onMetricsChanged = onMetricsChanged;
  }
}

class _RenderWidgetSpanSizeObserver extends RenderProxyBox {
  _RenderWidgetSpanSizeObserver(
    WidgetSpan identity,
    this.onMetricsChanged,
  ) : _identity = identity;

  WidgetSpan _identity;
  ValueChanged<_WidgetSpanMetrics> onMetricsChanged;
  _WidgetSpanMetrics? _reportedMetrics;

  set identity(WidgetSpan value) {
    if (identical(_identity, value)) {
      return;
    }
    _identity = value;
    _reportedMetrics = null;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    final metrics = _WidgetSpanMetrics(
      size: Size(size.width, size.height),
      baselineOffset: _baselineOffsetForChild(),
    );
    if (_reportedMetrics == metrics) {
      return;
    }
    _reportedMetrics = metrics;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onMetricsChanged(metrics);
    });
  }

  double? _baselineOffsetForChild() {
    if (_identity.alignment != ui.PlaceholderAlignment.baseline) {
      return null;
    }
    final baseline = _identity.baseline;
    final child = this.child;
    if (baseline == null || child == null) {
      return null;
    }
    return child.getDistanceToBaseline(baseline);
  }
}

Alignment _placeholderAlignment(ui.PlaceholderAlignment alignment) {
  return switch (alignment) {
    ui.PlaceholderAlignment.top => Alignment.topCenter,
    ui.PlaceholderAlignment.middle => Alignment.center,
    ui.PlaceholderAlignment.bottom ||
    ui.PlaceholderAlignment.baseline ||
    ui.PlaceholderAlignment.aboveBaseline ||
    ui.PlaceholderAlignment.belowBaseline =>
      Alignment.bottomCenter,
  };
}

double _widgetSpanTextScaleFactor(TextScaler textScaler, TextStyle style) {
  final fontSize = style.fontSize ?? kDefaultFontSize;
  if (fontSize <= 0 || !fontSize.isFinite) {
    return 1;
  }
  final scaledFontSize = textScaler.scale(fontSize);
  if (scaledFontSize <= 0 || !scaledFontSize.isFinite) {
    return 1;
  }
  return scaledFontSize / fontSize;
}
