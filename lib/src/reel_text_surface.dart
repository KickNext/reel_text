part of 'reel_text.dart';

/// One render surface for a complete settled or rolling reel row.
///
/// Text tokens are painted directly by a single render object. Inline widgets
/// remain real render children, so their state, hit testing, and semantics stay
/// owned by Flutter's widget/render trees.
class _ReelTextSurface extends MultiChildRenderObjectWidget {
  _ReelTextSurface({
    super.key,
    required this.data,
    required this.textScaler,
  }) : super(children: _inlineChildrenFor(data, textScaler));

  final _ReelTextSurfaceData data;
  final TextScaler textScaler;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderReelTextSurface(
      data: data,
      textScaler: textScaler,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderReelTextSurface renderObject,
  ) {
    renderObject
      ..data = data
      ..textScaler = textScaler;
  }
}

List<Widget> _inlineChildrenFor(
  _ReelTextSurfaceData data,
  TextScaler textScaler,
) {
  return [
    for (final widget in data.inlineWidgets)
      ...WidgetSpan.extractFromInlineSpan(
        TextSpan(style: widget.style, children: [widget.span]),
        textScaler,
      ),
  ];
}

enum _ReelTextSurfaceRunSide { settled, from, to }

class _ReelTextInlineWidget {
  const _ReelTextInlineWidget({
    required this.itemIndex,
    required this.tokenIndex,
    required this.side,
    required this.span,
    required this.style,
  });

  final int itemIndex;
  final int tokenIndex;
  final _ReelTextSurfaceRunSide side;
  final WidgetSpan span;
  final TextStyle style;
}

typedef _ReelTextSurfaceRuns = ({
  _MeasuredReelTextRun? settled,
  _MeasuredReelTextRun? from,
  _MeasuredReelTextRun? to,
});

typedef _ReelTextInlineMetric = ({
  WidgetSpan span,
  _WidgetSpanMetrics metrics,
});

class _ReelTextSurfaceData {
  const _ReelTextSurfaceData.settled({
    required _MeasuredReelTextRun run,
    required this.layout,
  })  : settledRun = run,
        plan = null,
        fromRun = null,
        toRun = null,
        animation = null,
        textAlign = TextAlign.start;

  const _ReelTextSurfaceData.rolling({
    required _RollPlan this.plan,
    required _MeasuredReelTextRun this.fromRun,
    required _MeasuredReelTextRun this.toRun,
    required Animation<double> this.animation,
    required this.textAlign,
    required this.layout,
  }) : settledRun = null;

  final _MeasuredReelTextRun? settledRun;
  final _RollPlan? plan;
  final _MeasuredReelTextRun? fromRun;
  final _MeasuredReelTextRun? toRun;
  final Animation<double>? animation;
  final TextAlign textAlign;
  final _ReelTextLayoutContext layout;

  bool get isRolling => plan != null;

  int get totalDurationMs => plan?.totalDuration.inMilliseconds ?? 1;

  double get progressMs => (animation?.value ?? 1) * totalDurationMs;

  double get height {
    final settled = settledRun;
    if (settled != null) {
      return settled.height;
    }
    return math.max(fromRun!.height, toRun!.height);
  }

  bool get hasWidgetSlots {
    final settled = settledRun;
    if (settled != null) {
      return settled.hasWidgets;
    }
    return fromRun!.hasWidgets || toRun!.hasWidgets;
  }

  List<_ReelTextInlineWidget> get inlineWidgets {
    final settled = settledRun;
    if (settled != null) {
      return [
        for (final widget in settled.content.widgetTokens)
          _ReelTextInlineWidget(
            itemIndex: settled.visualOrder.indexOf(widget.index),
            tokenIndex: widget.index,
            side: _ReelTextSurfaceRunSide.settled,
            span: widget.span,
            style: widget.style,
          ),
      ];
    }

    final widgets = <_ReelTextInlineWidget>[];
    for (var item = 0; item < plan!.slots.length; item++) {
      final slot = plan!.slots[item];
      final toToken = toRun!.tokenFor(slot.to);
      final fromToken = fromRun!.tokenFor(slot.from);
      final visibleToken = toToken ?? fromToken;
      if (!(visibleToken?.isWidget ?? false)) {
        continue;
      }
      if (toToken != null) {
        widgets.add(_ReelTextInlineWidget(
          itemIndex: item,
          tokenIndex: slot.to!.index,
          side: _ReelTextSurfaceRunSide.to,
          span: visibleToken!.widgetSpan!,
          style: visibleToken.style,
        ));
      } else {
        widgets.add(_ReelTextInlineWidget(
          itemIndex: item,
          tokenIndex: slot.from!.index,
          side: _ReelTextSurfaceRunSide.from,
          span: visibleToken!.widgetSpan!,
          style: visibleToken.style,
        ));
      }
    }
    return widgets;
  }
}

class _ReelTextSurfaceGeometry {
  const _ReelTextSurfaceGeometry({
    required this.itemWidths,
    required this.itemLefts,
    required this.rowWidth,
    required this.desiredWidth,
    required this.height,
    required this.rowAlignment,
  });

  final List<double> itemWidths;
  final List<double> itemLefts;
  final double rowWidth;
  final double desiredWidth;
  final double height;
  final Alignment rowAlignment;

  double rowLeftFor(Size size) {
    return rowAlignment
        .alongOffset(Offset(size.width - rowWidth, size.height - height))
        .dx;
  }
}

/// A laid-out text face retained by the unified reel render surface.
class _PreparedTextFace {
  const _PreparedTextFace({
    required this.painter,
    required this.width,
    required this.height,
    required this.paintWidth,
    required this.paintDx,
  });

  final TextPainter painter;
  final double width;
  final double height;
  final double paintWidth;
  final double paintDx;

  void dispose() => painter.dispose();
}

double _verticalSlotBleed(double height) => math.max(12, height * 0.38);

double _horizontalTextTokenBleed(double height) => math.max(4, height * 0.08);

@immutable
class _ReelPreparedFaceKey {
  const _ReelPreparedFaceKey({
    required this.text,
    required this.style,
    required this.width,
    required this.height,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
    required this.textScaler,
  });

  final String text;
  final TextStyle style;
  final double width;
  final double height;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextScaler textScaler;

  @override
  bool operator ==(Object other) {
    return other is _ReelPreparedFaceKey &&
        other.text == text &&
        other.style == style &&
        other.width == width &&
        other.height == height &&
        other.textDirection == textDirection &&
        other.locale == locale &&
        other.strutStyle == strutStyle &&
        other.textScaler == textScaler;
  }

  @override
  int get hashCode => Object.hash(
        text,
        style,
        width,
        height,
        textDirection,
        locale,
        strutStyle,
        textScaler,
      );
}

class _RenderReelTextSurface extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TextParentData>,
        RenderInlineChildrenContainerDefaults {
  _RenderReelTextSurface({
    required _ReelTextSurfaceData data,
    required TextScaler textScaler,
  })  : _data = data,
        _textScaler = textScaler;

  _ReelTextSurfaceData _data;
  TextScaler _textScaler;
  _MeasuredReelTextRun? _measuredSettledRun;
  _MeasuredReelTextRun? _measuredFromRun;
  _MeasuredReelTextRun? _measuredToRun;
  int _measuredWidgetRevision = -1;
  final _preparedFaces = <_ReelPreparedFaceKey, _PreparedTextFace>{};
  var _preparedFaceLayoutCount = 0;
  var _disposedPreparedFaceLayoutCount = 0;
  var _disposedTransientFaceLayoutCount = 0;
  double _debugPreparedToFaceDx = double.nan;
  double _debugCurrentToFaceDx = double.nan;

  _ReelTextSurfaceData get data => _data;

  set data(_ReelTextSurfaceData value) {
    if (identical(_data, value)) {
      return;
    }
    if (_hasSameRenderInputs(_data, value)) {
      _data = value;
      return;
    }
    final previousAnimation = _data.animation;
    final nextAnimation = value.animation;
    if (attached && !identical(previousAnimation, nextAnimation)) {
      previousAnimation?.removeListener(_handleAnimationTick);
      nextAnimation?.addListener(_handleAnimationTick);
    }
    _data = value;
    _invalidateMeasuredRuns();
    _clearPreparedFaces();
    markNeedsLayout();
    markNeedsPaint();
  }

  bool _hasSameRenderInputs(
    _ReelTextSurfaceData previous,
    _ReelTextSurfaceData next,
  ) {
    final previousLayout = previous.layout;
    final nextLayout = next.layout;
    return identical(previous.settledRun, next.settledRun) &&
        identical(previous.plan, next.plan) &&
        identical(previous.fromRun, next.fromRun) &&
        identical(previous.toRun, next.toRun) &&
        identical(previous.animation, next.animation) &&
        previous.textAlign == next.textAlign &&
        previousLayout.textDirection == nextLayout.textDirection &&
        previousLayout.locale == nextLayout.locale &&
        previousLayout.strutStyle == nextLayout.strutStyle &&
        identical(previousLayout.widgetSpans, nextLayout.widgetSpans);
  }

  TextScaler get textScaler => _textScaler;

  set textScaler(TextScaler value) {
    if (_textScaler == value) {
      return;
    }
    _textScaler = value;
    _invalidateMeasuredRuns();
    _clearPreparedFaces();
    markNeedsLayout();
    markNeedsPaint();
  }

  int get debugPreparedFaceLayoutCount => _preparedFaceLayoutCount;

  int get debugDisposedPreparedFaceLayoutCount =>
      _disposedPreparedFaceLayoutCount;

  int get debugDisposedTransientFaceLayoutCount =>
      _disposedTransientFaceLayoutCount;

  double get debugPreparedToFaceDx => _debugPreparedToFaceDx;

  double get debugCurrentToFaceDx => _debugCurrentToFaceDx;

  _MeasuredReelTextRun get _settledRun =>
      _measuredSettledRun ?? _data.settledRun!;

  _MeasuredReelTextRun get _fromRun => _measuredFromRun ?? _data.fromRun!;

  _MeasuredReelTextRun get _toRun => _measuredToRun ?? _data.toRun!;

  double get _height => _data.isRolling
      ? math.max(_fromRun.height, _toRun.height)
      : _settledRun.height;

  double get debugHorizontalBleed => _horizontalTextTokenBleed(_height);

  double get debugNaturalRowWidth => _geometry().rowWidth;

  Rect get debugVerticalClipRect => Rect.fromLTRB(
        0,
        -_verticalSlotBleed(_height),
        size.width,
        _height + _verticalSlotBleed(_height),
      );

  double get debugIncomingY {
    if (!_data.isRolling) {
      return 0;
    }
    final slot = _data.plan!.slots.firstWhere(
      (slot) => slot.changed && slot.to != null,
      orElse: () => _data.plan!.slots.first,
    );
    return slot.inY(_data.progressMs, _travelDistance);
  }

  List<Map<String, Object>> get debugVisibleGlyphBounds {
    final geometry = _geometry();
    final rowLeft = geometry.rowLeftFor(size);
    final entries = <Map<String, Object>>[];
    if (!_data.isRolling) {
      final run = _settledRun;
      for (var item = 0; item < run.visualOrder.length; item++) {
        final token = run.tokenAt(run.visualOrder[item]);
        if (token == null || token.isWidget || token.text.isEmpty) {
          continue;
        }
        _addDebugGlyphBounds(
          entries,
          text: token.text,
          itemLeft: rowLeft + geometry.itemLefts[item],
          itemWidth: geometry.itemWidths[item],
          faceWidth: geometry.itemWidths[item],
          dy: 0,
          opacity: 1,
        );
      }
      return entries;
    }

    final plan = _data.plan!;
    final fromRun = _fromRun;
    final toRun = _toRun;
    final progressMs = _data.progressMs;
    for (var item = 0; item < plan.slots.length; item++) {
      final slot = plan.slots[item];
      final itemLeft = rowLeft + geometry.itemLefts[item];
      final itemWidth = geometry.itemWidths[item];
      final fromToken = fromRun.tokenFor(slot.from);
      final toToken = toRun.tokenFor(slot.to);
      final hasWidgetEndpoint =
          (fromToken?.isWidget ?? false) || (toToken?.isWidget ?? false);
      if (!slot.changed || hasWidgetEndpoint) {
        final visibleToken = toToken ?? fromToken;
        final visibleWidth = slot.to == null
            ? fromRun.widthFor(slot.from)
            : toRun.widthFor(slot.to);
        if (visibleToken != null && !visibleToken.isWidget) {
          _addDebugGlyphBounds(
            entries,
            text: visibleToken.text,
            itemLeft: itemLeft,
            itemWidth: itemWidth,
            faceWidth: visibleWidth,
            dy: 0,
            opacity: 1,
          );
        }
        continue;
      }
      if (slot.from != null && fromToken != null && !fromToken.isWidget) {
        _addDebugGlyphBounds(
          entries,
          text: fromToken.text,
          itemLeft: itemLeft,
          itemWidth: itemWidth,
          faceWidth: fromRun.widthFor(slot.from),
          dy: slot.outY(progressMs, _travelDistance),
          opacity: slot.outOpacity(progressMs),
        );
      }
      if (slot.to != null && toToken != null && !toToken.isWidget) {
        _addDebugGlyphBounds(
          entries,
          text: toToken.text,
          itemLeft: itemLeft,
          itemWidth: itemWidth,
          faceWidth: toRun.widthFor(slot.to),
          dy: slot.inY(progressMs, _travelDistance),
          opacity: 1,
        );
      }
    }
    return entries;
  }

  double get _travelDistance => _height + _verticalSlotBleed(_height) * 2;

  void _addDebugGlyphBounds(
    List<Map<String, Object>> entries, {
    required String text,
    required double itemLeft,
    required double itemWidth,
    required double faceWidth,
    required double dy,
    required double opacity,
  }) {
    if (text.isEmpty || opacity <= 0.01) {
      return;
    }
    final paintWidth = faceWidth + _horizontalTextTokenBleed(_height);
    final left = itemLeft +
        _faceDxFor(itemWidth, faceWidth) +
        _paintDxFor(faceWidth, paintWidth);
    entries.add({
      'text': text,
      'left': left,
      'right': left + paintWidth,
      'top': dy,
      'bottom': dy + _height,
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _data.animation?.addListener(_handleAnimationTick);
  }

  @override
  void detach() {
    _data.animation?.removeListener(_handleAnimationTick);
    _clearPreparedFaces();
    super.detach();
  }

  @override
  void dispose() {
    _clearPreparedFaces();
    super.dispose();
  }

  void _handleAnimationTick() {
    markNeedsLayout();
    markNeedsPaint();
  }

  void _invalidateMeasuredRuns() {
    _measuredWidgetRevision = -1;
    _measuredSettledRun = null;
    _measuredFromRun = null;
    _measuredToRun = null;
  }

  void _syncMeasuredRuns() {
    final revision = _data.layout.widgetSpans.revision;
    if (_measuredWidgetRevision == revision) {
      return;
    }

    final hadMeasurements = _measuredWidgetRevision >= 0;
    if (_data.hasWidgetSlots) {
      final settled = _data.settledRun;
      _measuredSettledRun = settled == null
          ? null
          : _MeasuredReelTextRun.of(
              content: settled.content,
              layout: _data.layout,
              textScaler: _textScaler,
            );
      final from = _data.fromRun;
      _measuredFromRun = from == null
          ? null
          : _MeasuredReelTextRun.of(
              content: from.content,
              layout: _data.layout,
              textScaler: _textScaler,
            );
      final to = _data.toRun;
      _measuredToRun = to == null
          ? null
          : _MeasuredReelTextRun.of(
              content: to.content,
              layout: _data.layout,
              textScaler: _textScaler,
            );
    } else {
      _measuredSettledRun = null;
      _measuredFromRun = null;
      _measuredToRun = null;
    }
    _measuredWidgetRevision = revision;
    if (hadMeasurements) {
      _clearPreparedFaces();
    }
  }

  _ReelTextSurfaceGeometry _geometry() {
    _syncMeasuredRuns();
    return _geometryFor((
      settled: _data.isRolling ? null : _settledRun,
      from: _data.isRolling ? _fromRun : null,
      to: _data.isRolling ? _toRun : null,
    ));
  }

  _ReelTextSurfaceGeometry _geometryFor(_ReelTextSurfaceRuns runs) {
    if (!_data.isRolling) {
      final run = runs.settled!;
      final widths = <double>[
        for (final tokenIndex in run.visualOrder) run.widthAt(tokenIndex),
      ];
      return _geometryFromWidths(
        widths,
        desiredWidth: widths.fold<double>(0, (sum, width) => sum + width),
        height: run.height,
        rowAlignment: _data.layout.inlineStartAlignment,
      );
    }

    final plan = _data.plan!;
    final fromRun = runs.from!;
    final toRun = runs.to!;
    final progressMs = _data.progressMs;
    final widths = <double>[];
    for (final slot in plan.slots) {
      final fromToken = fromRun.tokenFor(slot.from);
      final toToken = toRun.tokenFor(slot.to);
      final hasWidgetEndpoint =
          (fromToken?.isWidget ?? false) || (toToken?.isWidget ?? false);
      final fromWidth = fromRun.widthFor(slot.from);
      final toWidth = toRun.widthFor(slot.to);
      if (hasWidgetEndpoint) {
        widths.add(slot.to == null ? fromWidth : toWidth);
      } else if (!slot.changed) {
        widths.add(toWidth);
      } else {
        widths.add(
          ui.lerpDouble(fromWidth, toWidth, slot.widthT(progressMs))!,
        );
      }
    }
    final rowWidth = widths.fold<double>(0, (sum, width) => sum + width);
    final anchorShrinkingRight =
        _alignsToRight(_data.textAlign, _data.layout.textDirection) &&
            toRun.width < fromRun.width;
    final desiredWidth = (fromRun.hasWidgets || toRun.hasWidgets)
        ? rowWidth
        : anchorShrinkingRight
            ? toRun.width
            : rowWidth;
    return _geometryFromWidths(
      widths,
      desiredWidth: desiredWidth,
      height: math.max(fromRun.height, toRun.height),
      rowAlignment: anchorShrinkingRight
          ? _data.layout.inlineStartAlignment
          : _alignmentForTextAlign(
              _data.textAlign,
              _data.layout.textDirection,
            ),
    );
  }

  _ReelTextSurfaceGeometry _geometryFromWidths(
    List<double> widths, {
    required double desiredWidth,
    required double height,
    required Alignment rowAlignment,
  }) {
    final lefts = <double>[];
    var left = 0.0;
    for (final width in widths) {
      lefts.add(left);
      left += width;
    }
    return _ReelTextSurfaceGeometry(
      itemWidths: widths,
      itemLefts: lefts,
      rowWidth: left,
      desiredWidth: desiredWidth,
      height: height,
      rowAlignment: rowAlignment,
    );
  }

  Size _layoutSizeFor(BoxConstraints constraints) {
    final geometry = _geometry();
    return constraints.constrain(
      Size(geometry.desiredWidth, geometry.height),
    );
  }

  @override
  void performLayout() {
    final dimensions = layoutInlineChildren(
      double.infinity,
      ChildLayoutHelper.layoutChild,
      ChildLayoutHelper.getBaseline,
    );
    _recordInlineWidgetMetrics(dimensions);
    _syncMeasuredRuns();
    size = _layoutSizeFor(constraints);
    final geometry = _geometry();
    final rowLeft = geometry.rowLeftFor(size);
    final boxes = <ui.TextBox>[];
    final widgets = _data.inlineWidgets;
    RenderBox? child = firstChild;
    for (var childIndex = 0;
        child != null && childIndex < widgets.length;
        childIndex++) {
      final widget = widgets[childIndex];
      final itemIndex = widget.itemIndex;
      if (itemIndex >= 0 && itemIndex < geometry.itemLefts.length) {
        final metrics = _metricsFor(widget);
        final itemWidth = geometry.itemWidths[itemIndex];
        final left = rowLeft +
            geometry.itemLefts[itemIndex] +
            _faceDxFor(itemWidth, metrics.size.width);
        final top = _inlineWidgetTop(widget, metrics);
        boxes.add(
          ui.TextBox.fromLTRBD(
            left,
            top,
            left + child.size.width,
            top + child.size.height,
            _data.layout.textDirection,
          ),
        );
      } else {
        boxes.add(
          ui.TextBox.fromLTRBD(
            0,
            0,
            child.size.width,
            child.size.height,
            _data.layout.textDirection,
          ),
        );
      }
      final parentData = child.parentData! as TextParentData;
      child = parentData.nextSibling;
    }
    positionInlineChildren(boxes);
  }

  void _recordInlineWidgetMetrics(List<PlaceholderDimensions> dimensions) {
    final widgets = _data.inlineWidgets;
    assert(dimensions.length == widgets.length);
    final count = math.min(dimensions.length, widgets.length);
    for (var i = 0; i < count; i++) {
      final dimension = dimensions[i];
      final widget = widgets[i];
      _data.layout.widgetSpans.setMetrics(
        widget.tokenIndex,
        widget.span,
        _metricsFromDimension(dimension),
      );
    }
  }

  _WidgetSpanMetrics _metricsFromDimension(
    PlaceholderDimensions dimension,
  ) {
    return _WidgetSpanMetrics(
      size: Size(dimension.size.width, dimension.size.height),
      baselineOffset: dimension.baselineOffset,
    );
  }

  _ReelTextSurfaceRuns _runsForDimensions(
    List<PlaceholderDimensions> dimensions,
  ) {
    final local = <_ReelTextSurfaceRunSide, Map<int, _ReelTextInlineMetric>>{
      for (final side in _ReelTextSurfaceRunSide.values)
        side: <int, _ReelTextInlineMetric>{},
    };
    final widgets = _data.inlineWidgets;
    final count = math.min(dimensions.length, widgets.length);
    for (var i = 0; i < count; i++) {
      final widget = widgets[i];
      local[widget.side]![widget.tokenIndex] = (
        span: widget.span,
        metrics: _metricsFromDimension(dimensions[i]),
      );
    }

    _MeasuredReelTextRun? measure(
      _MeasuredReelTextRun? run,
      _ReelTextSurfaceRunSide side,
    ) {
      if (run == null || !run.hasWidgets) {
        return run;
      }
      return _MeasuredReelTextRun.of(
        content: run.content,
        layout: _data.layout,
        textScaler: _textScaler,
        widgetSpanMetricsFor: (index, span) {
          final measured = local[side]![index];
          if (measured != null &&
              (identical(measured.span, span) ||
                  _widgetSpansEquivalentForMetrics(measured.span, span))) {
            return measured.metrics;
          }
          return _data.layout.widgetSpans.metricsFor(index, span);
        },
      );
    }

    return (
      settled: measure(
        _data.settledRun,
        _ReelTextSurfaceRunSide.settled,
      ),
      from: measure(_data.fromRun, _ReelTextSurfaceRunSide.from),
      to: measure(_data.toRun, _ReelTextSurfaceRunSide.to),
    );
  }

  _ReelTextSurfaceGeometry _dryGeometry() {
    final dimensions = layoutInlineChildren(
      double.infinity,
      ChildLayoutHelper.dryLayoutChild,
      ChildLayoutHelper.getDryBaseline,
    );
    return _geometryFor(_runsForDimensions(dimensions));
  }

  _WidgetSpanMetrics _metricsFor(_ReelTextInlineWidget widget) {
    return _data.layout.widgetSpans.metricsFor(
          widget.tokenIndex,
          widget.span,
        ) ??
        const _WidgetSpanMetrics(size: Size.zero, baselineOffset: null);
  }

  double _inlineWidgetTop(
    _ReelTextInlineWidget widget,
    _WidgetSpanMetrics metrics,
  ) {
    final run = switch (widget.side) {
      _ReelTextSurfaceRunSide.settled => _settledRun,
      _ReelTextSurfaceRunSide.from => _fromRun,
      _ReelTextSurfaceRunSide.to => _toRun,
    };
    final height = metrics.size.height;
    final baseline = run.metrics.baselineFor(widget.span.baseline);
    return switch (widget.span.alignment) {
      ui.PlaceholderAlignment.top => 0,
      ui.PlaceholderAlignment.middle => (_height - height) / 2,
      ui.PlaceholderAlignment.bottom => _height - height,
      ui.PlaceholderAlignment.baseline =>
        baseline - (metrics.baselineOffset ?? height),
      ui.PlaceholderAlignment.aboveBaseline => baseline - height,
      ui.PlaceholderAlignment.belowBaseline => baseline,
    };
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final geometry = _dryGeometry();
    return constraints.constrain(
      Size(geometry.desiredWidth, geometry.height),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _dryGeometry().desiredWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _dryGeometry().desiredWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _dryGeometry().height;

  @override
  double computeMaxIntrinsicHeight(double width) => _dryGeometry().height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return _baselineFor(baseline);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return _baselineForRuns(
        _runsForDimensions(layoutInlineChildren(
          double.infinity,
          ChildLayoutHelper.dryLayoutChild,
          ChildLayoutHelper.getDryBaseline,
        )),
        baseline);
  }

  double _baselineFor(TextBaseline baseline) {
    _syncMeasuredRuns();
    return _baselineForRuns((
      settled: _data.isRolling ? null : _settledRun,
      from: _data.isRolling ? _fromRun : null,
      to: _data.isRolling ? _toRun : null,
    ), baseline);
  }

  double _baselineForRuns(
    _ReelTextSurfaceRuns runs,
    TextBaseline baseline,
  ) {
    if (!_data.isRolling) {
      return runs.settled!.metrics.baselineFor(baseline);
    }
    return math.max(
      runs.from!.metrics.baselineFor(baseline),
      runs.to!.metrics.baselineFor(baseline),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final geometry = _geometry();
    final rowLeft = geometry.rowLeftFor(size);
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (_data.isRolling) {
      _paintRollingText(canvas, geometry, rowLeft);
    } else {
      _paintSettledText(canvas, geometry, rowLeft);
    }
    canvas.restore();
    paintInlineChildren(context, offset);
  }

  void _paintSettledText(
    Canvas canvas,
    _ReelTextSurfaceGeometry geometry,
    double rowLeft,
  ) {
    final run = _settledRun;
    for (var item = 0; item < run.visualOrder.length; item++) {
      final token = run.tokenAt(run.visualOrder[item]);
      if (token == null || token.isWidget || token.text.isEmpty) {
        continue;
      }
      final width = geometry.itemWidths[item];
      _paintPreparedFace(
        canvas,
        face: _preparedFace(
          text: token.text,
          style: token.style,
          width: width,
        ),
        itemLeft: rowLeft + geometry.itemLefts[item],
        itemWidth: width,
        dy: 0,
        angle: 0,
        opacity: 1,
      );
    }
  }

  void _paintRollingText(
    Canvas canvas,
    _ReelTextSurfaceGeometry geometry,
    double rowLeft,
  ) {
    final plan = _data.plan!;
    final fromRun = _fromRun;
    final toRun = _toRun;
    final progressMs = _data.progressMs;
    for (var item = 0; item < plan.slots.length; item++) {
      final slot = plan.slots[item];
      final itemLeft = rowLeft + geometry.itemLefts[item];
      final itemWidth = geometry.itemWidths[item];
      final fromToken = fromRun.tokenFor(slot.from);
      final toToken = toRun.tokenFor(slot.to);
      final hasWidgetEndpoint =
          (fromToken?.isWidget ?? false) || (toToken?.isWidget ?? false);

      if (!slot.changed || hasWidgetEndpoint) {
        final visibleToken = toToken ?? fromToken;
        if (visibleToken == null || visibleToken.isWidget) {
          continue;
        }
        final visibleWidth = slot.to == null
            ? fromRun.widthFor(slot.from)
            : toRun.widthFor(slot.to);
        _paintPreparedFace(
          canvas,
          face: _preparedFace(
            text: visibleToken.text,
            style: visibleToken.style,
            width: visibleWidth,
          ),
          itemLeft: itemLeft,
          itemWidth: itemWidth,
          dy: 0,
          angle: 0,
          opacity: 1,
        );
        continue;
      }

      final verticalBleed = _verticalSlotBleed(_height);
      const horizontalBleed = 100000.0;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          itemLeft - horizontalBleed,
          -verticalBleed,
          itemLeft + itemWidth + horizontalBleed,
          _height + verticalBleed,
        ),
      );

      if (slot.from != null && fromToken != null && !fromToken.isWidget) {
        _paintPreparedFace(
          canvas,
          face: _preparedFace(
            text: fromToken.text,
            style: fromToken.style,
            width: fromRun.widthFor(slot.from),
          ),
          itemLeft: itemLeft,
          itemWidth: itemWidth,
          dy: slot.outY(progressMs, _travelDistance),
          angle: -slot.tiltRadians * slot.outT(progressMs),
          opacity: slot.outOpacity(progressMs),
        );
      }

      if (slot.to != null && toToken != null && !toToken.isWidget) {
        final targetWidth = toRun.widthFor(slot.to);
        final defaultTextColor = toToken.style.color ?? Colors.black;
        final incomingColor = slot.color == null
            ? defaultTextColor
            : Color.lerp(
                slot.color,
                defaultTextColor,
                slot.colorT(progressMs),
              )!;
        final dy = slot.inY(progressMs, _travelDistance);
        final angle = slot.tiltRadians * (1 - slot.inT(progressMs));
        if (slot.color == null) {
          final face = _preparedFace(
            text: toToken.text,
            style: toToken.style.copyWith(color: incomingColor),
            width: targetWidth,
          );
          _paintPreparedFace(
            canvas,
            face: face,
            itemLeft: itemLeft,
            itemWidth: itemWidth,
            dy: dy,
            angle: angle,
            opacity: 1,
          );
          _debugPreparedToFaceDx = itemLeft + _faceDxFor(itemWidth, face.width);
        } else {
          _paintTransientFace(
            canvas,
            text: toToken.text,
            style: toToken.style.copyWith(color: incomingColor),
            width: targetWidth,
            itemLeft: itemLeft,
            itemWidth: itemWidth,
            dy: dy,
            angle: angle,
            opacity: 1,
          );
        }
        _debugCurrentToFaceDx = itemLeft + _faceDxFor(itemWidth, targetWidth);
      }
      canvas.restore();
    }
  }

  _PreparedTextFace _preparedFace({
    required String text,
    required TextStyle style,
    required double width,
  }) {
    final key = _ReelPreparedFaceKey(
      text: text,
      style: style,
      width: width,
      height: _height,
      textDirection: _data.layout.textDirection,
      locale: _data.layout.locale,
      strutStyle: _data.layout.strutStyle,
      textScaler: _textScaler,
    );
    return _preparedFaces.putIfAbsent(
      key,
      () {
        _preparedFaceLayoutCount++;
        return _createFace(text: text, style: style, width: width);
      },
    );
  }

  _PreparedTextFace _createFace({
    required String text,
    required TextStyle style,
    required double width,
  }) {
    final height = _height;
    final paintWidth = width + _horizontalTextTokenBleed(height);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: _data.layout.textDirection,
      textAlign: TextAlign.start,
      textScaler: _textScaler,
      locale: _data.layout.locale,
      strutStyle: _data.layout.strutStyle,
      maxLines: 1,
    )..layout(minWidth: paintWidth, maxWidth: paintWidth);
    return _PreparedTextFace(
      painter: painter,
      width: width,
      height: height,
      paintWidth: paintWidth,
      paintDx: _paintDxFor(width, paintWidth),
    );
  }

  void _paintTransientFace(
    Canvas canvas, {
    required String text,
    required TextStyle style,
    required double width,
    required double itemLeft,
    required double itemWidth,
    required double dy,
    required double angle,
    required double opacity,
  }) {
    final face = _createFace(text: text, style: style, width: width);
    try {
      _paintPreparedFace(
        canvas,
        face: face,
        itemLeft: itemLeft,
        itemWidth: itemWidth,
        dy: dy,
        angle: angle,
        opacity: opacity,
      );
    } finally {
      face.dispose();
      _disposedTransientFaceLayoutCount++;
    }
  }

  void _paintPreparedFace(
    Canvas canvas, {
    required _PreparedTextFace face,
    required double itemLeft,
    required double itemWidth,
    required double dy,
    required double angle,
    required double opacity,
  }) {
    if (opacity <= 0.001) {
      return;
    }
    final faceDx = _faceDxFor(itemWidth, face.width);
    canvas.save();
    canvas.translate(
      itemLeft + faceDx + face.width / 2,
      dy + face.height / 2,
    );
    if (angle != 0) {
      canvas.rotate(angle);
    }
    canvas.translate(-face.width / 2, -face.height / 2);
    if (opacity < 0.999) {
      final verticalBleed = _verticalSlotBleed(face.height);
      canvas.saveLayer(
        Rect.fromLTRB(
          face.paintDx,
          -verticalBleed,
          face.paintDx + face.paintWidth,
          face.height + verticalBleed,
        ),
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

  double _faceDxFor(double itemWidth, double faceWidth) {
    return _data.layout.inlineStartAlignment
        .alongOffset(Offset(itemWidth - faceWidth, 0))
        .dx;
  }

  double _paintDxFor(double width, double paintWidth) {
    return _data.layout.textDirection == TextDirection.rtl
        ? width - paintWidth
        : 0;
  }

  void _clearPreparedFaces() {
    if (_preparedFaces.isEmpty) {
      return;
    }
    for (final face in _preparedFaces.values) {
      face.dispose();
      _disposedPreparedFaceLayoutCount++;
    }
    _preparedFaces.clear();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return hitTestInlineChildren(result, position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    defaultApplyPaintTransform(child, transform);
  }
}
