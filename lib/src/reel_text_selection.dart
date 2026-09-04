part of 'reel_text.dart';

class _ReelTextSelection extends StatelessWidget {
  const _ReelTextSelection({
    required this.content,
    required this.textAlign,
    required this.layout,
    required this.excludeVisualSemantics,
    required this.child,
  });

  final _ReelTextContent content;
  final TextAlign textAlign;
  final _ReelTextLayoutContext layout;
  final bool excludeVisualSemantics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final visualChild = SelectionContainer.disabled(child: child);
    final visual = excludeVisualSemantics
        ? ExcludeSemantics(child: visualChild)
        : visualChild;
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) {
      return visual;
    }

    return _ReelTextSelectableStack(
      widgetSpans: layout.widgetSpans,
      children: [
        visual,
        ExcludeSemantics(
          child: RichText(
            key: const ValueKey('reel_text_selection_surface'),
            text: _transparentTextSpan(
              content,
              layout,
              textScaler,
            ),
            textAlign: textAlign,
            textDirection: layout.textDirection,
            locale: layout.locale,
            softWrap: false,
            maxLines: 1,
            strutStyle: layout.strutStyle,
            textScaler: textScaler,
            selectionRegistrar: registrar,
            selectionColor: DefaultSelectionStyle.of(context).selectionColor ??
                DefaultSelectionStyle.defaultColor,
          ),
        ),
      ],
    );
  }
}

/// Lays out the visual reel before its transparent selectable paragraph.
///
/// That ordering lets inline-widget measurements produced by the visual
/// surface be consumed by the selection paragraph in the same layout pass.
class _ReelTextSelectableStack extends MultiChildRenderObjectWidget {
  const _ReelTextSelectableStack({
    required this.widgetSpans,
    required super.children,
  });

  final _WidgetSpanLayoutModel widgetSpans;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderReelTextSelectableStack(widgetSpans);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderReelTextSelectableStack renderObject,
  ) {
    renderObject.widgetSpans = widgetSpans;
  }
}

class _ReelTextSelectableParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderReelTextSelectableStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ReelTextSelectableParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            _ReelTextSelectableParentData> {
  _RenderReelTextSelectableStack(this._widgetSpans);

  _WidgetSpanLayoutModel _widgetSpans;
  int _selectionRevision = -1;

  set widgetSpans(_WidgetSpanLayoutModel value) {
    if (identical(_widgetSpans, value)) {
      return;
    }
    _widgetSpans = value;
    _selectionRevision = -1;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ReelTextSelectableParentData) {
      child.parentData = _ReelTextSelectableParentData();
    }
  }

  @override
  void performLayout() {
    final visual = firstChild;
    if (visual == null) {
      size = constraints.smallest;
      return;
    }

    visual.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(visual.size);
    final visualParentData =
        visual.parentData! as _ReelTextSelectableParentData;
    visualParentData.offset = Offset.zero;

    final selection = childAfter(visual);
    if (selection == null) {
      return;
    }
    if (_selectionRevision != _widgetSpans.revision) {
      invokeLayoutCallback<BoxConstraints>((_) {
        _markSelectionLayoutDirty(selection);
      });
      _selectionRevision = _widgetSpans.revision;
    }
    selection.layout(BoxConstraints.tight(size));
    final selectionParentData =
        selection.parentData! as _ReelTextSelectableParentData;
    selectionParentData.offset = Offset.zero;
  }

  void _markSelectionLayoutDirty(RenderObject renderObject) {
    renderObject.visitChildren(_markSelectionLayoutDirty);
    renderObject.markNeedsLayout();
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final visual = firstChild;
    return visual == null
        ? constraints.smallest
        : constraints.constrain(visual.getDryLayout(constraints));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      firstChild?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      firstChild?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      firstChild?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return firstChild?.getDistanceToActualBaseline(baseline);
  }

  // Flutter 3.16 does not declare this hook yet. Keeping the method (and the
  // ignored annotation) lets newer SDKs use it without dropping 3.16 support.
  @override
  // ignore: override_on_non_overriding_member
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final visual = firstChild;
    if (visual == null) {
      return null;
    }
    return (visual as dynamic).getDryBaseline(constraints, baseline)
        as double?;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final visual = firstChild;
    if (visual != null && _hitTestChild(result, visual, position)) {
      return true;
    }

    final selection = visual == null ? null : childAfter(visual);
    return selection != null && _hitTestChild(result, selection, position);
  }

  bool _hitTestChild(
    BoxHitTestResult result,
    RenderBox child,
    Offset position,
  ) {
    final parentData = child.parentData! as _ReelTextSelectableParentData;
    return result.addWithPaintOffset(
      offset: parentData.offset,
      position: position,
      hitTest: (result, transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final parentData = child.parentData! as _ReelTextSelectableParentData;
    transform.multiply(
      Matrix4.translationValues(parentData.offset.dx, parentData.offset.dy, 0),
    );
  }
}

TextSpan _transparentTextSpan(
  _ReelTextContent content,
  _ReelTextLayoutContext layout,
  TextScaler textScaler,
) {
  return TextSpan(
    children: [
      _transparentInlineSpan(
        content.span,
        _WidgetSpanSelectionCursor(
          content.widgetTokens.toList(),
          layout,
          textScaler,
        ),
      ),
    ],
  );
}

InlineSpan _transparentInlineSpan(
  InlineSpan span,
  _WidgetSpanSelectionCursor sizes,
) {
  if (span is WidgetSpan) {
    return WidgetSpan(
      alignment: span.alignment,
      baseline: span.baseline,
      style: _transparentLayoutStyle(span.style ?? const TextStyle()),
      child: sizes.nextPlaceholder(span),
    );
  }

  if (span is! TextSpan) {
    throw FlutterError(
      'ReelText.rich supports TextSpan trees and WidgetSpan leaves only.',
    );
  }

  final transparentStyle =
      _transparentLayoutStyle(span.style ?? const TextStyle());
  return TextSpan(
    text: span.text,
    style: transparentStyle,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
    children: [
      for (final child in span.children ?? const <InlineSpan>[])
        _transparentInlineSpan(child, sizes),
    ],
  );
}

TextStyle _transparentLayoutStyle(TextStyle style) {
  return TextStyle(
    inherit: style.inherit,
    color: Colors.transparent,
    backgroundColor: Colors.transparent,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    letterSpacing: style.letterSpacing,
    wordSpacing: style.wordSpacing,
    textBaseline: style.textBaseline,
    height: style.height,
    leadingDistribution: style.leadingDistribution,
    locale: style.locale,
    shadows: const <Shadow>[],
    fontFeatures: style.fontFeatures,
    fontVariations: style.fontVariations,
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
    fontFamily: style.fontFamily,
    fontFamilyFallback: style.fontFamilyFallback,
    overflow: style.overflow,
  );
}

class _WidgetSpanSelectionCursor {
  _WidgetSpanSelectionCursor(this.widgetTokens, this.layout, this.textScaler);

  final List<_ReelTextWidgetToken> widgetTokens;
  final _ReelTextLayoutContext layout;
  final TextScaler textScaler;
  var _widgetOrdinal = 0;

  Widget nextPlaceholder(WidgetSpan fallbackSpan) {
    if (_widgetOrdinal >= widgetTokens.length) {
      return _WidgetSpanSelectionPlaceholder(
        widgetSpans: layout.widgetSpans,
        tokenIndex: -1,
        span: fallbackSpan,
        textScaleFactor: 1,
      );
    }
    final token = widgetTokens[_widgetOrdinal++];
    return _WidgetSpanSelectionPlaceholder(
      widgetSpans: layout.widgetSpans,
      tokenIndex: token.index,
      span: token.span,
      textScaleFactor: _widgetSpanTextScaleFactor(textScaler, token.style),
    );
  }
}

double _widgetSpanTextScaleFactor(TextScaler textScaler, TextStyle style) {
  const defaultFontSize = 14.0;
  final fontSize = style.fontSize ?? defaultFontSize;
  if (fontSize <= 0 || !fontSize.isFinite) {
    return 1;
  }
  final scaledFontSize = textScaler.scale(fontSize);
  if (scaledFontSize <= 0 || !scaledFontSize.isFinite) {
    return 1;
  }
  return scaledFontSize / fontSize;
}

class _WidgetSpanSelectionPlaceholder extends LeafRenderObjectWidget {
  const _WidgetSpanSelectionPlaceholder({
    required this.widgetSpans,
    required this.tokenIndex,
    required this.span,
    required this.textScaleFactor,
  });

  final _WidgetSpanLayoutModel widgetSpans;
  final int tokenIndex;
  final WidgetSpan span;
  final double textScaleFactor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderWidgetSpanSelectionPlaceholder(
      widgetSpans: widgetSpans,
      tokenIndex: tokenIndex,
      span: span,
      textScaleFactor: textScaleFactor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWidgetSpanSelectionPlaceholder renderObject,
  ) {
    renderObject
      ..widgetSpans = widgetSpans
      ..tokenIndex = tokenIndex
      ..span = span
      ..textScaleFactor = textScaleFactor;
  }
}

class _RenderWidgetSpanSelectionPlaceholder extends RenderBox {
  _RenderWidgetSpanSelectionPlaceholder({
    required _WidgetSpanLayoutModel widgetSpans,
    required int tokenIndex,
    required WidgetSpan span,
    required double textScaleFactor,
  })  : _widgetSpans = widgetSpans,
        _tokenIndex = tokenIndex,
        _span = span,
        _textScaleFactor = textScaleFactor;

  _WidgetSpanLayoutModel _widgetSpans;
  int _tokenIndex;
  WidgetSpan _span;
  double _textScaleFactor;

  set widgetSpans(_WidgetSpanLayoutModel value) {
    if (identical(_widgetSpans, value)) {
      return;
    }
    _widgetSpans = value;
    markNeedsLayout();
  }

  set tokenIndex(int value) {
    if (_tokenIndex == value) {
      return;
    }
    _tokenIndex = value;
    markNeedsLayout();
  }

  set span(WidgetSpan value) {
    if (identical(_span, value)) {
      return;
    }
    _span = value;
    markNeedsLayout();
  }

  set textScaleFactor(double value) {
    if (_textScaleFactor == value) {
      return;
    }
    _textScaleFactor = value;
    markNeedsLayout();
  }

  _WidgetSpanMetrics get _metrics {
    final scaled = _widgetSpans.metricsFor(_tokenIndex, _span) ??
        const _WidgetSpanMetrics(size: Size.zero, baselineOffset: null);
    return scaled.unscaledBy(_textScaleFactor);
  }

  @override
  void performLayout() {
    size = constraints.constrain(_metrics.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.constrain(_metrics.size);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (_span.baseline == baseline) {
      return _metrics.baselineOffset;
    }
    return null;
  }
}
