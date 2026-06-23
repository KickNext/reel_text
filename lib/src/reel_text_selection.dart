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

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        visual,
        Positioned.fill(
          child: ExcludeSemantics(
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
              selectionColor:
                  DefaultSelectionStyle.of(context).selectionColor ??
                      DefaultSelectionStyle.defaultColor,
            ),
          ),
        ),
      ],
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
        _WidgetSpanSizeCursor(
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
  _WidgetSpanSizeCursor sizes,
) {
  if (span is WidgetSpan) {
    final metrics = sizes.nextMetrics();
    return WidgetSpan(
      alignment: span.alignment,
      baseline: span.baseline,
      style: span.style,
      child: _WidgetSpanSelectionPlaceholder(
        metrics: metrics,
        baseline: span.baseline,
      ),
    );
  }

  if (span is! TextSpan) {
    throw FlutterError(
      'ReelText.rich supports TextSpan trees and WidgetSpan leaves only.',
    );
  }

  final transparentStyle = (span.style ?? const TextStyle()).copyWith(
    color: Colors.transparent,
    decorationColor: Colors.transparent,
  );
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

class _WidgetSpanSizeCursor {
  _WidgetSpanSizeCursor(this.widgetTokens, this.layout, this.textScaler);

  final List<_ReelTextWidgetToken> widgetTokens;
  final _ReelTextLayoutContext layout;
  final TextScaler textScaler;
  var _widgetOrdinal = 0;

  _WidgetSpanMetrics nextMetrics() {
    if (_widgetOrdinal >= widgetTokens.length) {
      return const _WidgetSpanMetrics(size: Size.zero, baselineOffset: null);
    }
    final token = widgetTokens[_widgetOrdinal++];
    final metrics = layout.widgetSpanMetricsFor(token.index, token.span) ??
        const _WidgetSpanMetrics(size: Size.zero, baselineOffset: null);
    final scale = _widgetSpanTextScaleFactor(textScaler, token.style);
    return metrics.unscaledBy(scale);
  }
}

class _WidgetSpanSelectionPlaceholder extends LeafRenderObjectWidget {
  const _WidgetSpanSelectionPlaceholder({
    required this.metrics,
    required this.baseline,
  });

  final _WidgetSpanMetrics metrics;
  final TextBaseline? baseline;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderWidgetSpanSelectionPlaceholder(
      metrics: metrics,
      baseline: baseline,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderWidgetSpanSelectionPlaceholder renderObject,
  ) {
    renderObject
      ..metrics = metrics
      ..baseline = baseline;
  }
}

class _RenderWidgetSpanSelectionPlaceholder extends RenderBox {
  _RenderWidgetSpanSelectionPlaceholder({
    required _WidgetSpanMetrics metrics,
    required TextBaseline? baseline,
  })  : _metrics = metrics,
        _baseline = baseline;

  _WidgetSpanMetrics _metrics;
  TextBaseline? _baseline;

  set metrics(_WidgetSpanMetrics value) {
    if (_metrics == value) {
      return;
    }
    _metrics = value;
    markNeedsLayout();
  }

  set baseline(TextBaseline? value) {
    if (_baseline == value) {
      return;
    }
    _baseline = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.constrain(_metrics.size);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (_baseline == baseline) {
      return _metrics.baselineOffset;
    }
    return null;
  }
}
