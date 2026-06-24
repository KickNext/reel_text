part of 'reel_text.dart';

const _kRollingTextColorFaceSteps = 8;

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
    return _buildPaintedRollingText(context, data);
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

  Widget _buildPaintedRollingText(
    BuildContext context,
    _TokenSlotRenderData data,
  ) {
    final textColor = data.effectiveToStyle.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;

    return ClipRect(
      clipper: const _VerticalSlotClipper(),
      clipBehavior: Clip.hardEdge,
      child: _RollingTextSlotFace(
        key: const ValueKey('reel_text_rolling_text_slot'),
        data: data,
        animation: animation,
        totalDurationMs: totalDurationMs,
        layout: layout,
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        defaultTextColor: textColor,
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

class _RollingTextSlotFace extends LeafRenderObjectWidget {
  const _RollingTextSlotFace({
    super.key,
    required this.data,
    required this.animation,
    required this.totalDurationMs,
    required this.layout,
    required this.textScaler,
    required this.defaultTextColor,
  });

  final _TokenSlotRenderData data;
  final Animation<double> animation;
  final int totalDurationMs;
  final _ReelTextLayoutContext layout;
  final TextScaler textScaler;
  final Color defaultTextColor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderRollingTextSlotFace(
      data: data,
      animation: animation,
      totalDurationMs: totalDurationMs,
      layout: layout,
      textScaler: textScaler,
      defaultTextColor: defaultTextColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRollingTextSlotFace renderObject,
  ) {
    renderObject
      ..data = data
      ..animation = animation
      ..totalDurationMs = totalDurationMs
      ..layoutContext = layout
      ..textScaler = textScaler
      ..defaultTextColor = defaultTextColor;
  }
}

class _RenderRollingTextSlotFace extends RenderBox {
  _RenderRollingTextSlotFace({
    required _TokenSlotRenderData data,
    required Animation<double> animation,
    required int totalDurationMs,
    required _ReelTextLayoutContext layout,
    required TextScaler textScaler,
    required Color defaultTextColor,
  })  : _data = data,
        _animation = animation,
        _totalDurationMs = totalDurationMs,
        _layout = layout,
        _textScaler = textScaler,
        _defaultTextColor = defaultTextColor;

  _TokenSlotRenderData _data;
  Animation<double> _animation;
  int _totalDurationMs;
  _ReelTextLayoutContext _layout;
  TextScaler _textScaler;
  Color _defaultTextColor;
  _PreparedTextFace? _fromFace;
  _PreparedTextFace? _toFace;
  final _toColorFaces = <int, _PreparedTextFace>{};
  var _preparedFaceLayoutCount = 0;

  _TokenSlotRenderData get data => _data;

  set data(_TokenSlotRenderData value) {
    if (identical(_data, value)) {
      return;
    }
    _data = value;
    _clearPreparedFaces();
    markNeedsLayout();
    markNeedsPaint();
  }

  Animation<double> get animation => _animation;

  set animation(Animation<double> value) {
    if (identical(_animation, value)) {
      return;
    }
    if (attached) {
      _animation.removeListener(_handleAnimationTick);
    }
    _animation = value;
    if (attached) {
      _animation.addListener(_handleAnimationTick);
    }
    markNeedsLayout();
    markNeedsPaint();
  }

  int get totalDurationMs => _totalDurationMs;

  set totalDurationMs(int value) {
    if (_totalDurationMs == value) {
      return;
    }
    _totalDurationMs = value;
    markNeedsLayout();
    markNeedsPaint();
  }

  _ReelTextLayoutContext get layoutContext => _layout;

  set layoutContext(_ReelTextLayoutContext value) {
    if (identical(_layout, value)) {
      return;
    }
    _layout = value;
    _clearPreparedFaces();
    markNeedsPaint();
  }

  TextScaler get textScaler => _textScaler;

  set textScaler(TextScaler value) {
    if (_textScaler == value) {
      return;
    }
    _textScaler = value;
    _clearPreparedFaces();
    markNeedsPaint();
  }

  Color get defaultTextColor => _defaultTextColor;

  set defaultTextColor(Color value) {
    if (_defaultTextColor == value) {
      return;
    }
    _defaultTextColor = value;
    _clearPreparedFaces();
    markNeedsPaint();
  }

  double get debugIncomingY =>
      _data.slot.inY(_progressMs, _data.travelDistance);

  int get debugPreparedFaceLayoutCount => _preparedFaceLayoutCount;

  double get debugHorizontalBleed =>
      _horizontalTextTokenBleed(_data.metrics.height);

  List<Map<String, Object>> get debugVisibleGlyphBounds {
    final progressMs = _progressMs;
    final entries = <Map<String, Object>>[];
    if (_data.fromEndpoint != null) {
      _addDebugGlyphBounds(
        entries,
        text: _data.fromText,
        width: _data.metrics.fromWidth,
        dy: _data.slot.outY(progressMs, _data.travelDistance),
        opacity: _data.slot.outOpacity(progressMs),
      );
    }
    if (_data.toEndpoint != null) {
      _addDebugGlyphBounds(
        entries,
        text: _data.toText,
        width: _data.metrics.toWidth,
        dy: _data.slot.inY(progressMs, _data.travelDistance),
        opacity: 1,
      );
    }
    return entries;
  }

  void _addDebugGlyphBounds(
    List<Map<String, Object>> entries, {
    required String text,
    required double width,
    required double dy,
    required double opacity,
  }) {
    if (text.isEmpty || opacity <= 0.01) {
      return;
    }
    final height = _data.metrics.height;
    final paintWidth = width + _horizontalTextTokenBleed(height);
    entries.add({
      'text': text,
      'left': _faceDxFor(width) + _paintDxFor(width, paintWidth),
      'top': dy,
      'bottom': dy + height,
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_handleAnimationTick);
  }

  @override
  void detach() {
    _animation.removeListener(_handleAnimationTick);
    super.detach();
  }

  void _handleAnimationTick() {
    markNeedsLayout();
    markNeedsPaint();
  }

  double get _progressMs => _animation.value * _totalDurationMs;

  double get _currentWidth {
    return ui.lerpDouble(
      _data.metrics.fromWidth,
      _data.metrics.toWidth,
      _data.slot.widthT(_progressMs),
    )!;
  }

  @override
  void performLayout() {
    size = constraints.constrain(
      Size(_currentWidth, _data.metrics.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final progressMs = _progressMs;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    if (_data.fromEndpoint != null) {
      _paintPreparedTokenFace(
        canvas,
        face: _fromFace ??= _prepareTokenFace(
          text: _data.fromText,
          style: _data.effectiveFromStyle,
          width: _data.metrics.fromWidth,
        ),
        dy: _data.slot.outY(progressMs, _data.travelDistance),
        angle: -_data.slot.tiltRadians * _data.slot.outT(progressMs),
        opacity: _data.slot.outOpacity(progressMs),
      );
    }
    if (_data.toEndpoint != null) {
      final incomingColor = _data.slot.color == null
          ? _defaultTextColor
          : Color.lerp(
              _data.slot.color,
              _defaultTextColor,
              _data.slot.colorT(progressMs),
            )!;
      final angle = _data.slot.tiltRadians * (1 - _data.slot.inT(progressMs));
      final dy = _data.slot.inY(progressMs, _data.travelDistance);
      if (_data.slot.color == null) {
        _paintPreparedTokenFace(
          canvas,
          face: _toFace ??= _prepareTokenFace(
            text: _data.toText,
            style: _data.effectiveToStyle.copyWith(color: incomingColor),
            width: _data.metrics.toWidth,
          ),
          dy: dy,
          angle: angle,
          opacity: 1,
        );
      } else {
        final face = _preparedToColorFace(incomingColor);
        _paintPreparedTokenFace(
          canvas,
          face: face,
          dy: dy,
          angle: angle,
          opacity: 1,
        );
      }
    }

    canvas.restore();
  }

  _PreparedTextFace _prepareTokenFace({
    required String text,
    required TextStyle style,
    required double width,
  }) {
    final height = _data.metrics.height;
    final horizontalBleed = _horizontalTextTokenBleed(height);
    final paintWidth = width + horizontalBleed;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: _layout.textDirection,
      textAlign: TextAlign.start,
      textScaler: _textScaler,
      locale: _layout.locale,
      strutStyle: _layout.strutStyle,
      maxLines: 1,
    )..layout(minWidth: paintWidth, maxWidth: paintWidth);
    _preparedFaceLayoutCount++;
    return _PreparedTextFace(
      painter: painter,
      width: width,
      height: height,
      paintWidth: paintWidth,
      faceDx: _faceDxFor(width),
      paintDx: _paintDxFor(width, paintWidth),
    );
  }

  _PreparedTextFace _preparedToColorFace(Color color) {
    final key = _colorCacheKey(color);
    return _toColorFaces.putIfAbsent(
      key,
      () => _prepareTokenFace(
        text: _data.toText,
        style: _data.effectiveToStyle.copyWith(
          color: _quantizedColor(color),
        ),
        width: _data.metrics.toWidth,
      ),
    );
  }

  void _paintPreparedTokenFace(
    Canvas canvas, {
    required _PreparedTextFace face,
    required double dy,
    required double angle,
    required double opacity,
  }) {
    if (opacity <= 0.001) {
      return;
    }

    canvas.save();
    canvas.translate(face.faceDx + face.width / 2, dy + face.height / 2);
    if (angle != 0) {
      canvas.rotate(angle);
    }
    canvas.translate(-face.width / 2, -face.height / 2);

    if (opacity < 0.999) {
      canvas.saveLayer(
        Rect.fromLTWH(face.paintDx, 0, face.paintWidth, face.height),
        Paint()
          ..color = Color.fromARGB(
            (opacity.clamp(0.0, 1.0) * 255).round(),
            255,
            255,
            255,
          ),
      );
    }

    face.painter.paint(canvas, Offset(face.paintDx, 0));

    if (opacity < 0.999) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _clearPreparedFaces() {
    _fromFace = null;
    _toFace = null;
    _toColorFaces.clear();
  }

  double _faceDxFor(double width) {
    return _layout.inlineStartAlignment
        .alongOffset(
          Offset(size.width - width, 0),
        )
        .dx;
  }

  double _paintDxFor(double width, double paintWidth) {
    return _layout.textDirection == TextDirection.rtl
        ? width - paintWidth
        : 0.0;
  }
}

int _colorCacheKey(Color color) => _quantizedColor(color).toARGB32();

Color _quantizedColor(Color color) {
  double quantize(double value) =>
      (value * _kRollingTextColorFaceSteps).round() /
      _kRollingTextColorFaceSteps;
  return Color.from(
    alpha: quantize(color.a),
    red: quantize(color.r),
    green: quantize(color.g),
    blue: quantize(color.b),
  );
}

class _PreparedTextFace {
  const _PreparedTextFace({
    required this.painter,
    required this.width,
    required this.height,
    required this.paintWidth,
    required this.faceDx,
    required this.paintDx,
  });

  final TextPainter painter;
  final double width;
  final double height;
  final double paintWidth;
  final double faceDx;
  final double paintDx;
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
