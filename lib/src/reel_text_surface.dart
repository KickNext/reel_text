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
        textAlign = TextAlign.start,
        defaultTextColor = Colors.black;

  const _ReelTextSurfaceData.rolling({
    required _RollPlan this.plan,
    required _MeasuredReelTextRun this.fromRun,
    required _MeasuredReelTextRun this.toRun,
    required Animation<double> this.animation,
    required this.textAlign,
    required this.layout,
    required this.defaultTextColor,
  }) : settledRun = null;

  final _MeasuredReelTextRun? settledRun;
  final _RollPlan? plan;
  final _MeasuredReelTextRun? fromRun;
  final _MeasuredReelTextRun? toRun;
  final Animation<double>? animation;
  final TextAlign textAlign;
  final _ReelTextLayoutContext layout;

  /// Colour painted for incoming faces whose token style carries no colour
  /// (for example `inherit: false` spans); mirrors the ambient
  /// [DefaultTextStyle] colour the way the previous per-slot renderer did.
  final Color defaultTextColor;

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
  _ReelTextSurfaceGeometry(int itemCount)
      : itemWidths = List<double>.filled(itemCount, 0),
        itemLefts = List<double>.filled(itemCount, 0);

  final List<double> itemWidths;
  final List<double> itemLefts;
  double rowWidth = 0;
  double desiredWidth = 0;
  double height = 0;
  double progressMs = double.nan;
  bool widthsSettled = false;
  Alignment rowAlignment = Alignment.centerLeft;

  double rowLeftFor(Size size) {
    return (size.width - rowWidth) * (rowAlignment.x + 1) / 2;
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

enum _ReelPreparedFaceLane { settled, from, to, coloredTo }

/// Identity of a prepared face: everything [_RenderReelTextSurface._createFace]
/// bakes into the painter apart from the layout context, which clears the
/// whole cache when it changes.
class _PreparedFaceKey {
  const _PreparedFaceKey({
    required this.span,
    required this.width,
    required this.height,
  });

  final TextSpan span;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) {
    return other is _PreparedFaceKey &&
        other.span == span &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(span, width, height);
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
  _ReelTextSurfaceGeometry? _laidOutGeometry;
  int _geometryCalculationCount = 0;

  int get debugGeometryCalculationCount => _geometryCalculationCount;
  List<_PreparedTextFace?>? _settledFaces;
  List<_PreparedTextFace?>? _fromFaces;
  List<_PreparedTextFace?>? _toFaces;
  List<_PreparedTextFace?>? _coloredToFaces;

  /// Prepared faces keyed by their layout inputs. The lane lists above only
  /// index into this map, which survives settled/rolling data swaps so that
  /// repeated rolls (counters cycling through the same glyphs) reuse laid-out
  /// text instead of laying it out again on every transition.
  final _faceCache = <_PreparedFaceKey, _PreparedTextFace>{};
  static const _minCachedFaces = 96;
  var _preparedFaceLayoutCount = 0;
  var _disposedPreparedFaceLayoutCount = 0;
  var _disposedTransientFaceLayoutCount = 0;
  double _debugPreparedToFaceDx = double.nan;
  double _debugCurrentToFaceDx = double.nan;
  List<Map<String, Object>> _debugVisibleGlyphBounds = const [];

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
    final layoutChanged = !_sameFaceLayoutInputs(_data.layout, value.layout);
    _data = value;
    _invalidateMeasuredRuns();
    if (layoutChanged) {
      _clearPreparedFaces();
    } else {
      _resetFaceLanes();
    }
    markNeedsLayout();
    markNeedsPaint();
  }

  bool _sameFaceLayoutInputs(
    _ReelTextLayoutContext previous,
    _ReelTextLayoutContext next,
  ) {
    return previous.textDirection == next.textDirection &&
        previous.locale == next.locale &&
        previous.strutStyle == next.strutStyle;
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
        previous.defaultTextColor == next.defaultTextColor &&
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

  double get debugNaturalRowWidth => _currentGeometry.rowWidth;

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

  List<Map<String, Object>> get debugVisibleGlyphBounds =>
      _debugVisibleGlyphBounds;

  double get _travelDistance => _height + _verticalSlotBleed(_height) * 2;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _data.animation?.addListener(_handleAnimationTick);
  }

  @override
  void detach() {
    _data.animation?.removeListener(_handleAnimationTick);
    // Prepared faces are plain TextPainters with no owner-bound resources, so
    // they survive the reparenting that happens when the surface moves
    // between the settled and rolling subtrees. dispose() releases them.
    super.detach();
  }

  @override
  void dispose() {
    _clearPreparedFaces();
    super.dispose();
  }

  void _handleAnimationTick() {
    if (_repaintWithoutLayout()) {
      markNeedsPaint();
      return;
    }
    markNeedsLayout();
    markNeedsPaint();
  }

  /// Advances the rolling geometry to the current animation value and
  /// reports whether the natural (unconstrained) size is unchanged, in which
  /// case neither this box nor any ancestor that depends on its intrinsics
  /// can change, so the tick only needs a repaint. Inline widgets are
  /// positioned during layout, so rows containing them always relayout.
  bool _repaintWithoutLayout() {
    final laidOut = _laidOutGeometry;
    if (laidOut == null || !hasSize || _data.hasWidgetSlots) {
      return false;
    }
    final previous = Size(laidOut.desiredWidth, laidOut.height);
    final geometry = _geometry(reuse: laidOut);
    if (Size(geometry.desiredWidth, geometry.height) != previous) {
      return false;
    }
    _laidOutGeometry = geometry;
    return true;
  }

  void _invalidateMeasuredRuns() {
    _laidOutGeometry = null;
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

  _ReelTextSurfaceGeometry _geometry({
    _ReelTextSurfaceGeometry? reuse,
  }) {
    // Plain-text geometry has no constraint-dependent child measurements.
    // Reuse the tick's calculation during layout, and retain final widths
    // while glyph motion or color fading continues. Data/scaler changes
    // invalidate _laidOutGeometry before this can be reused.
    if (reuse != null && !_data.hasWidgetSlots) {
      final now = _data.progressMs;
      if (now == reuse.progressMs ||
          (reuse.widthsSettled && now >= reuse.progressMs)) {
        return reuse;
      }
    }
    _syncMeasuredRuns();
    return _geometryFor((
      settled: _data.isRolling ? null : _settledRun,
      from: _data.isRolling ? _fromRun : null,
      to: _data.isRolling ? _toRun : null,
    ), reuse: reuse);
  }

  _ReelTextSurfaceGeometry get _currentGeometry =>
      _laidOutGeometry ?? _geometry();

  _ReelTextSurfaceGeometry _geometryFor(
    _ReelTextSurfaceRuns runs, {
    _ReelTextSurfaceGeometry? reuse,
  }) {
    assert(() {
      _geometryCalculationCount++;
      return true;
    }());
    if (!_data.isRolling) {
      final run = runs.settled!;
      final itemCount = run.visualOrder.length;
      final geometry = _geometryBuffer(reuse, itemCount);
      var rowWidth = 0.0;
      for (var item = 0; item < itemCount; item++) {
        final width = run.widthAt(run.visualOrder[item]);
        geometry.itemWidths[item] = width;
        geometry.itemLefts[item] = rowWidth;
        rowWidth += width;
      }
      geometry
        ..rowWidth = rowWidth
        ..desiredWidth = rowWidth
        ..height = run.height
        ..rowAlignment = _data.layout.inlineStartAlignment;
      return geometry;
    }

    final plan = _data.plan!;
    final fromRun = runs.from!;
    final toRun = runs.to!;
    final progressMs = _data.progressMs;
    final itemCount = plan.slots.length;
    final geometry = _geometryBuffer(reuse, itemCount);
    var widthsSettled = true;
    var rowWidth = 0.0;
    for (var item = 0; item < itemCount; item++) {
      final slot = plan.slots[item];
      final fromToken = fromRun.tokenFor(slot.from);
      final toToken = toRun.tokenFor(slot.to);
      final hasWidgetEndpoint =
          (fromToken?.isWidget ?? false) || (toToken?.isWidget ?? false);
      final fromWidth = fromRun.widthFor(slot.from);
      final toWidth = toRun.widthFor(slot.to);
      late final double width;
      if (hasWidgetEndpoint) {
        width = slot.to == null ? fromWidth : toWidth;
      } else if (!slot.changed) {
        width = toWidth;
      } else {
        final widthT = slot.widthT(progressMs);
        if (fromWidth != toWidth && widthT < 1) {
          widthsSettled = false;
        }
        width = ui.lerpDouble(
          fromWidth,
          toWidth,
          widthT,
        )!;
      }
      geometry.itemWidths[item] = width;
      geometry.itemLefts[item] = rowWidth;
      rowWidth += width;
    }
    final anchorShrinkingRight =
        _alignsToRight(_data.textAlign, _data.layout.textDirection) &&
            toRun.width < fromRun.width;
    final desiredWidth = (fromRun.hasWidgets || toRun.hasWidgets)
        ? rowWidth
        : anchorShrinkingRight
            ? toRun.width
            : rowWidth;
    geometry
      ..progressMs = progressMs
      ..widthsSettled = widthsSettled
      ..rowWidth = rowWidth
      ..desiredWidth = desiredWidth
      ..height = math.max(fromRun.height, toRun.height)
      ..rowAlignment = anchorShrinkingRight
          ? _data.layout.inlineStartAlignment
          : _alignmentForTextAlign(
              _data.textAlign,
              _data.layout.textDirection,
            );
    return geometry;
  }

  _ReelTextSurfaceGeometry _geometryBuffer(
    _ReelTextSurfaceGeometry? reuse,
    int itemCount,
  ) {
    return reuse != null && reuse.itemWidths.length == itemCount
        ? reuse
        : _ReelTextSurfaceGeometry(itemCount);
  }

  List<PlaceholderDimensions> _layoutInlineChildren(
    double maxWidth,
    ChildLayouter layoutChild, {
    required bool dry,
  }) {
    final childConstraints = BoxConstraints(maxWidth: maxWidth);
    return <PlaceholderDimensions>[
      for (RenderBox? child = firstChild;
          child != null;
          child = childAfter(child))
        _inlineChildDimensions(
          child,
          childConstraints,
          layoutChild,
          dry: dry,
        ),
    ];
  }

  PlaceholderDimensions _inlineChildDimensions(
    RenderBox child,
    BoxConstraints childConstraints,
    ChildLayouter layoutChild, {
    required bool dry,
  }) {
    final parentData = child.parentData! as TextParentData;
    final span = parentData.span;
    assert(span != null);
    if (span == null) {
      return PlaceholderDimensions.empty;
    }

    final childSize = layoutChild(child, childConstraints);
    return PlaceholderDimensions(
      size: childSize,
      alignment: span.alignment,
      baseline: span.baseline,
      baselineOffset: switch (span.alignment) {
        ui.PlaceholderAlignment.aboveBaseline ||
        ui.PlaceholderAlignment.belowBaseline ||
        ui.PlaceholderAlignment.bottom ||
        ui.PlaceholderAlignment.middle ||
        ui.PlaceholderAlignment.top =>
          null,
        ui.PlaceholderAlignment.baseline => dry
            ? _dryBaselineForInlineChild(
                child,
                childConstraints,
                span.baseline!,
                childSize,
              )
            : child.getDistanceToBaseline(span.baseline!),
      },
    );
  }

  double _dryBaselineForInlineChild(
    RenderBox child,
    BoxConstraints childConstraints,
    TextBaseline baseline,
    Size childSize,
  ) {
    // Placeholder children without a baseline (plain boxes) cannot compute a
    // dry baseline and would throw in debug builds. Flutter's own intrinsic
    // checks silence that assertion through debugCheckingIntrinsics; do the
    // same so such children fall back to their bottom edge instead of
    // failing the whole layout pass.
    var restoreDebugFlag = false;
    assert(() {
      restoreDebugFlag = !RenderObject.debugCheckingIntrinsics;
      RenderObject.debugCheckingIntrinsics = true;
      return true;
    }());
    try {
      final value = (child as dynamic).getDryBaseline(
        childConstraints,
        baseline,
      ) as double?;
      return value ?? childSize.height;
    } on NoSuchMethodError {
      // Flutter before 3.24 has no dry-baseline API. Its own inline-child
      // helper treated a missing baseline as the bottom of the placeholder.
      return childSize.height;
    } finally {
      assert(() {
        if (restoreDebugFlag) {
          RenderObject.debugCheckingIntrinsics = false;
        }
        return true;
      }());
    }
  }

  @override
  void performLayout() {
    final hasInlineWidgets = _data.hasWidgetSlots;
    if (hasInlineWidgets) {
      final dimensions = _layoutInlineChildren(
        double.infinity,
        ChildLayoutHelper.layoutChild,
        dry: false,
      );
      _recordInlineWidgetMetrics(dimensions);
    }
    final geometry = _geometry(reuse: _laidOutGeometry);
    _laidOutGeometry = geometry;
    size = constraints.constrain(
      Size(geometry.desiredWidth, geometry.height),
    );
    if (!hasInlineWidgets) {
      return;
    }
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
    final dimensions = _layoutInlineChildren(
      double.infinity,
      ChildLayoutHelper.dryLayoutChild,
      dry: true,
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

  // Flutter 3.16 does not declare this hook yet. Keeping the method (and the
  // ignored annotation) lets newer SDKs use it without dropping 3.16 support.
  @override
  // ignore: override_on_non_overriding_member
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return _baselineForRuns(
        _runsForDimensions(_layoutInlineChildren(
          double.infinity,
          ChildLayoutHelper.dryLayoutChild,
          dry: true,
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
    assert(() {
      _debugVisibleGlyphBounds = <Map<String, Object>>[];
      return true;
    }());
    final geometry = _currentGeometry;
    final rowLeft = geometry.rowLeftFor(size);
    final canvas = context.canvas;
    // Faces are painted in the enclosing layer's coordinate space, like
    // RenderParagraph does, so style shaders (gradient foregrounds) span the
    // row instead of restarting on every glyph.
    if (_data.isRolling) {
      _paintRollingText(canvas, geometry, rowLeft, offset);
    } else {
      _paintSettledText(canvas, geometry, rowLeft, offset);
    }
    paintInlineChildren(context, offset);
  }

  void _paintSettledText(
    Canvas canvas,
    _ReelTextSurfaceGeometry geometry,
    double rowLeft,
    Offset origin,
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
        debugText: token.text,
        origin: origin,
        face: _preparedFaceAt(
          lane: _ReelPreparedFaceLane.settled,
          item: item,
          token: token,
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
    Offset origin,
  ) {
    final plan = _data.plan!;
    final fromRun = _fromRun;
    final toRun = _toRun;
    final progressMs = _data.progressMs;
    final height = _height;
    final verticalBleed = _verticalSlotBleed(height);
    final travelDistance = height + verticalBleed * 2;
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
          debugText: visibleToken.text,
          origin: origin,
          face: _preparedFaceAt(
            lane: slot.to == null
                ? _ReelPreparedFaceLane.from
                : _ReelPreparedFaceLane.to,
            item: item,
            token: visibleToken,
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

      const horizontalBleed = 100000.0;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          origin.dx + itemLeft - horizontalBleed,
          origin.dy - verticalBleed,
          origin.dx + itemLeft + itemWidth + horizontalBleed,
          origin.dy + height + verticalBleed,
        ),
        doAntiAlias: false,
      );

      if (slot.from != null && fromToken != null && !fromToken.isWidget) {
        final outT = slot.outT(progressMs);
        final directionSign =
            slot.direction == ReelTextDirection.down ? 1.0 : -1.0;
        _paintPreparedFace(
          canvas,
          debugText: fromToken.text,
          origin: origin,
          face: _preparedFaceAt(
            lane: _ReelPreparedFaceLane.from,
            item: item,
            token: fromToken,
            width: fromRun.widthFor(slot.from),
          ),
          itemLeft: itemLeft,
          itemWidth: itemWidth,
          dy: directionSign * travelDistance * outT,
          angle: -slot.tiltRadians * outT,
          opacity: 1 - _smoothstep((outT - 0.78) / 0.22),
        );
      }

      if (slot.to != null && toToken != null && !toToken.isWidget) {
        final targetWidth = toRun.widthFor(slot.to);
        final defaultTextColor = toToken.style.color ?? _data.defaultTextColor;
        final inT = slot.inT(progressMs);
        final directionSign =
            slot.direction == ReelTextDirection.down ? -1.0 : 1.0;
        final dy = directionSign * travelDistance * (1 - inT);
        final angle = slot.tiltRadians * (1 - inT);
        final color = slot.color;
        if (color == null) {
          final face = _preparedFaceAt(
            lane: _ReelPreparedFaceLane.to,
            item: item,
            token: toToken,
            overrideColor:
                toToken.shapedParts == null ? defaultTextColor : null,
            width: targetWidth,
          );
          _paintPreparedFace(
            canvas,
            debugText: toToken.text,
            origin: origin,
            face: face,
            itemLeft: itemLeft,
            itemWidth: itemWidth,
            dy: dy,
            angle: angle,
            opacity: 1,
          );
          _debugPreparedToFaceDx = itemLeft + _faceDxFor(itemWidth, face.width);
        } else {
          final colorT = slot.colorT(progressMs);
          if (colorT <= 0) {
            _paintPreparedFace(
              canvas,
              debugText: toToken.text,
              origin: origin,
              face: _preparedFaceAt(
                lane: _ReelPreparedFaceLane.coloredTo,
                item: item,
                token: toToken,
                overrideColor: color,
                width: targetWidth,
              ),
              itemLeft: itemLeft,
              itemWidth: itemWidth,
              dy: dy,
              angle: angle,
              opacity: 1,
            );
          } else if (colorT >= 1) {
            _paintPreparedFace(
              canvas,
              debugText: toToken.text,
              origin: origin,
              face: _preparedFaceAt(
                lane: _ReelPreparedFaceLane.to,
                item: item,
                token: toToken,
                overrideColor:
                    toToken.shapedParts == null ? defaultTextColor : null,
                width: targetWidth,
              ),
              itemLeft: itemLeft,
              itemWidth: itemWidth,
              dy: dy,
              angle: angle,
              opacity: 1,
            );
          } else {
            _paintTransientFace(
              canvas,
              origin: origin,
              token: toToken,
              tint: color,
              tintProgress: colorT,
              defaultColor: defaultTextColor,
              width: targetWidth,
              itemLeft: itemLeft,
              itemWidth: itemWidth,
              dy: dy,
              angle: angle,
              opacity: 1,
            );
          }
        }
        _debugCurrentToFaceDx = itemLeft + _faceDxFor(itemWidth, targetWidth);
      }
      canvas.restore();
    }
  }

  _PreparedTextFace _preparedFaceAt({
    required _ReelPreparedFaceLane lane,
    required int item,
    required _ReelTextToken token,
    required double width,
    Color? overrideColor,
  }) {
    final lanes = _preparedFaceCache(lane);
    final cached = lanes[item];
    if (cached != null) {
      return cached;
    }
    final span = _paintSpanForToken(token, tint: overrideColor);
    final key = _PreparedFaceKey(
      span: span,
      width: width,
      height: _height,
    );
    var face = _faceCache.remove(key);
    if (face == null) {
      _preparedFaceLayoutCount++;
      face = _createFace(span: span, width: width);
    }
    // Re-inserting keeps the map ordered by recency for eviction.
    _faceCache[key] = face;
    return lanes[item] = face;
  }

  List<_PreparedTextFace?> _preparedFaceCache(
    _ReelPreparedFaceLane lane,
  ) {
    final itemCount = _data.isRolling
        ? _data.plan!.slots.length
        : _settledRun.visualOrder.length;
    return switch (lane) {
      _ReelPreparedFaceLane.settled => _settledFaces ??=
          List<_PreparedTextFace?>.filled(itemCount, null),
      _ReelPreparedFaceLane.from => _fromFaces ??=
          List<_PreparedTextFace?>.filled(itemCount, null),
      _ReelPreparedFaceLane.to => _toFaces ??=
          List<_PreparedTextFace?>.filled(itemCount, null),
      _ReelPreparedFaceLane.coloredTo => _coloredToFaces ??=
          List<_PreparedTextFace?>.filled(itemCount, null),
    };
  }

  _PreparedTextFace _createFace({
    required TextSpan span,
    required double width,
  }) {
    final height = _height;
    final paintWidth = width + _horizontalTextTokenBleed(height);
    final painter = TextPainter(
      text: span,
      textDirection: _data.layout.textDirection,
      textAlign: TextAlign.start,
      textScaler: _textScaler,
      locale: _data.layout.locale,
      strutStyle: _data.layout.strutStyle,
      maxLines: 1,
    )..layout(minWidth: paintWidth, maxWidth: double.infinity);
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
    required Offset origin,
    required _ReelTextToken token,
    required Color tint,
    required double tintProgress,
    required Color defaultColor,
    required double width,
    required double itemLeft,
    required double itemWidth,
    required double dy,
    required double angle,
    required double opacity,
  }) {
    final face = _createFace(
      span: _paintSpanForToken(
        token,
        tint: tint,
        tintProgress: tintProgress,
        defaultColor: defaultColor,
      ),
      width: width,
    );
    try {
      _paintPreparedFace(
        canvas,
        debugText: token.text,
        origin: origin,
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
    required String debugText,
    required Offset origin,
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
    assert(() {
      _recordDebugGlyphBounds(
        text: debugText,
        face: face,
        itemLeft: itemLeft,
        faceDx: faceDx,
        dy: dy,
        angle: angle,
        opacity: opacity,
      );
      return true;
    }());
    var paintOrigin = Offset(origin.dx + itemLeft + faceDx, origin.dy + dy);
    final rotated = angle != 0;
    if (rotated) {
      canvas.save();
      canvas.translate(
        paintOrigin.dx + face.width / 2,
        paintOrigin.dy + face.height / 2,
      );
      canvas.rotate(angle);
      canvas.translate(-face.width / 2, -face.height / 2);
      paintOrigin = Offset.zero;
    }
    final translucent = opacity < 0.999;
    if (translucent) {
      final verticalBleed = _verticalSlotBleed(face.height);
      canvas.saveLayer(
        Rect.fromLTRB(
          paintOrigin.dx + face.paintDx,
          paintOrigin.dy - verticalBleed,
          paintOrigin.dx + face.paintDx + face.paintWidth,
          paintOrigin.dy + face.height + verticalBleed,
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
    final clipOverflow = face.painter.width > face.paintWidth;
    if (clipOverflow) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
        paintOrigin.dx + face.paintDx,
        paintOrigin.dy,
        face.paintWidth,
        face.height,
      ));
    }
    face.painter.paint(
      canvas,
      Offset(paintOrigin.dx + face.paintDx, paintOrigin.dy),
    );
    if (clipOverflow) {
      canvas.restore();
    }
    if (translucent) {
      canvas.restore();
    }
    if (rotated) {
      canvas.restore();
    }
  }

  void _recordDebugGlyphBounds({
    required String text,
    required _PreparedTextFace face,
    required double itemLeft,
    required double faceDx,
    required double dy,
    required double angle,
    required double opacity,
  }) {
    if (text.isEmpty || opacity <= 0.01) {
      return;
    }

    final centerX = itemLeft + faceDx + face.width / 2;
    final centerY = dy + face.height / 2;
    final left = face.paintDx - face.width / 2;
    final right = left + face.paintWidth;
    final top = -face.height / 2;
    final bottom = face.height / 2;
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    final xs = <double>[];
    final ys = <double>[];
    for (final corner in <Offset>[
      Offset(left, top),
      Offset(right, top),
      Offset(right, bottom),
      Offset(left, bottom),
    ]) {
      xs.add(centerX + corner.dx * cosine - corner.dy * sine);
      ys.add(centerY + corner.dx * sine + corner.dy * cosine);
    }
    _debugVisibleGlyphBounds.add({
      'text': text,
      'left': xs.reduce(math.min),
      'right': xs.reduce(math.max),
      'top': ys.reduce(math.min),
      'bottom': ys.reduce(math.max),
    });
  }

  double _faceDxFor(double itemWidth, double faceWidth) {
    return _data.layout.textDirection == TextDirection.rtl
        ? itemWidth - faceWidth
        : 0;
  }

  double _paintDxFor(double width, double paintWidth) {
    return _data.layout.textDirection == TextDirection.rtl
        ? width - paintWidth
        : 0;
  }

  int get _laneItemCount => _data.isRolling
      ? _data.plan!.slots.length
      : _data.settledRun!.visualOrder.length;

  /// Forgets the per-item lane lookups (they are rebuilt from the cache on the
  /// next paint) and trims the cache to a bounded size while nothing points
  /// into it.
  void _resetFaceLanes() {
    _settledFaces = null;
    _fromFaces = null;
    _toFaces = null;
    _coloredToFaces = null;
    final capacity = math.max(_minCachedFaces, 4 * _laneItemCount);
    while (_faceCache.length > capacity) {
      final oldest = _faceCache.keys.first;
      _faceCache.remove(oldest)!.dispose();
      _disposedPreparedFaceLayoutCount++;
    }
  }

  void _clearPreparedFaces() {
    _settledFaces = null;
    _fromFaces = null;
    _toFaces = null;
    _coloredToFaces = null;
    for (final face in _faceCache.values) {
      face.dispose();
      _disposedPreparedFaceLayoutCount++;
    }
    _faceCache.clear();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return hitTestInlineChildren(result, position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    defaultApplyPaintTransform(child, transform);
  }
}
