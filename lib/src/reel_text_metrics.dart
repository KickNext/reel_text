part of 'reel_text.dart';

class _ReelTextLayoutContext {
  const _ReelTextLayoutContext({
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
    required this.widgetSpanSizeFor,
    required this.onWidgetSpanSizeChanged,
  });

  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final Size? Function(int index, WidgetSpan span) widgetSpanSizeFor;
  final void Function(int index, WidgetSpan span, Size size)
      onWidgetSpanSizeChanged;

  Alignment get inlineStartAlignment => _inlineStartAlignment(textDirection);
}

class _WidgetSpanSizeRegistry {
  final _entries = <int, _WidgetSpanSizeEntry>{};

  Size? sizeFor(int index, WidgetSpan span) {
    final entry = _entries[index];
    if (entry == null || !identical(entry.span, span)) {
      return null;
    }
    return entry.size;
  }

  bool hasSize(int index, WidgetSpan span, Size size) {
    return sizeFor(index, span) == size;
  }

  void setSize(int index, WidgetSpan span, Size size) {
    _entries[index] = _WidgetSpanSizeEntry(span, size);
  }
}

class _WidgetSpanSizeEntry {
  const _WidgetSpanSizeEntry(this.span, this.size);

  final WidgetSpan span;
  final Size size;
}

class _MeasuredReelTextRun {
  const _MeasuredReelTextRun({
    required this.content,
    required this.metrics,
  });

  final _ReelTextContent content;
  final _TextRunMetrics metrics;

  String get text => content.plainText;

  int get length => content.length;

  bool get hasWidgets => content.hasWidgets;

  double get width => metrics.width;

  double get height => metrics.height;

  List<int> get visualOrder => metrics.visualOrder;

  double widthAt(int index) => metrics.widthAt(index);

  _ReelTextToken? tokenAt(int index) => content.tokenAt(index);

  double widthFor(_SlotEndpoint? endpoint) {
    if (endpoint == null) {
      return 0;
    }
    return widthAt(endpoint.index);
  }

  _ReelTextToken? tokenFor(_SlotEndpoint? endpoint) {
    if (endpoint == null) {
      return null;
    }
    return tokenAt(endpoint.index) ?? endpoint.token;
  }

  _SlotEndpoint? endpointAt(int index) {
    final token = tokenAt(index);
    if (token == null) {
      return null;
    }
    return _SlotEndpoint(index: index, token: token);
  }

  static _MeasuredReelTextRun of({
    required BuildContext context,
    required _ReelTextContent content,
    required _ReelTextLayoutContext layout,
  }) {
    return _MeasuredReelTextRun(
      content: content,
      metrics: _TextRunMetrics.of(
        context: context,
        content: content,
        layout: layout,
      ),
    );
  }
}

class _TextRunMetrics {
  const _TextRunMetrics({
    required this.widths,
    required this.visualOrder,
    required this.width,
    required this.height,
  });

  final List<double> widths;
  final List<int> visualOrder;
  final double width;
  final double height;

  double widthAt(int index) {
    if (index < 0 || index >= widths.length) {
      return 0;
    }
    return widths[index];
  }

  static _TextRunMetrics of({
    required BuildContext context,
    required _ReelTextContent content,
    required _ReelTextLayoutContext layout,
  }) {
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final painter = TextPainter(
      text: content.span,
      textDirection: layout.textDirection,
      textScaler: textScaler,
      locale: layout.locale,
      strutStyle: layout.strutStyle,
      maxLines: 1,
    );
    painter.setPlaceholderDimensions(
      _placeholderDimensionsFor(content, layout.widgetSpanSizeFor),
    );
    painter.layout();

    final tokens = content.tokens;
    final offsets = <int>[0];
    var offset = 0;
    for (final token in tokens) {
      offset += token.text.length;
      offsets.add(offset);
    }

    final widths = <double>[];
    final visualLefts = <double>[];
    for (var i = 0; i < tokens.length; i++) {
      final bounds = _tokenBounds(painter, offsets[i], offsets[i + 1]);
      widths.add(bounds.width);
      visualLefts.add(bounds.left);
    }

    final measured = widths.fold<double>(0, (sum, width) => sum + width);
    if (widths.isNotEmpty && (measured - painter.size.width).abs() > 1e-9) {
      final index = widths.lastIndexWhere((width) => width > 0);
      if (index >= 0) {
        widths[index] = math.max(
          0,
          widths[index] + painter.size.width - measured,
        );
      }
    }

    final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);
    final visualOrder = [for (var i = 0; i < tokens.length; i++) i]
      ..sort((a, b) {
        final byLeft = visualLefts[a].compareTo(visualLefts[b]);
        if (byLeft != 0) {
          return byLeft;
        }
        final byRight = (visualLefts[a] + widths[a]).compareTo(
          visualLefts[b] + widths[b],
        );
        if (byRight != 0) {
          return byRight;
        }
        return a.compareTo(b);
      });
    return _TextRunMetrics(
      widths: widths,
      visualOrder: visualOrder,
      width: totalWidth,
      height: painter.size.height,
    );
  }

  static double _caretDx(TextPainter painter, int offset) {
    return painter
        .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
        .dx;
  }

  static _TokenBounds _tokenBounds(TextPainter painter, int start, int end) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isNotEmpty) {
      var width = 0.0;
      var left = double.infinity;
      for (final box in boxes) {
        width += (box.right - box.left).abs();
        left = math.min(left, math.min(box.left, box.right));
      }
      return _TokenBounds(width: width, left: left.isFinite ? left : 0);
    }

    final startDx = _caretDx(painter, start);
    final endDx = _caretDx(painter, end);
    return _TokenBounds(
      width: (endDx - startDx).abs(),
      left: math.min(startDx, endDx),
    );
  }
}

List<PlaceholderDimensions>? _placeholderDimensionsFor(
  _ReelTextContent content,
  Size? Function(int index, WidgetSpan span) widgetSpanSizeFor,
) {
  final dimensions = <PlaceholderDimensions>[];
  for (final widget in content.widgetTokens) {
    dimensions.add(
      _placeholderDimensionsForWidget(
        widget.span,
        widgetSpanSizeFor(widget.index, widget.span) ?? Size.zero,
      ),
    );
  }
  return dimensions.isEmpty ? null : dimensions;
}

PlaceholderDimensions _placeholderDimensionsForWidget(
  WidgetSpan span,
  Size size,
) {
  if (size == Size.zero) {
    return PlaceholderDimensions.empty;
  }
  return PlaceholderDimensions(
    size: size,
    alignment: span.alignment,
    baseline: span.baseline,
    baselineOffset:
        span.alignment == ui.PlaceholderAlignment.baseline ? size.height : null,
  );
}

class _TokenBounds {
  const _TokenBounds({required this.width, required this.left});

  final double width;
  final double left;
}

class _SlotMetrics {
  const _SlotMetrics({
    required this.fromWidth,
    required this.toWidth,
    required this.height,
  });

  final double fromWidth;
  final double toWidth;
  final double height;
}

Alignment _inlineStartAlignment(TextDirection textDirection) {
  return textDirection == TextDirection.rtl
      ? Alignment.centerRight
      : Alignment.centerLeft;
}
