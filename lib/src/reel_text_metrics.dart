part of 'reel_text.dart';

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
    required InlineSpan span,
    required TextDirection textDirection,
    required Locale? locale,
    required StrutStyle? strutStyle,
    required String text,
  }) {
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final painter = TextPainter(
      text: span,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      strutStyle: strutStyle,
      maxLines: 1,
    )..layout();

    final chars = text.characters.toList();
    final offsets = <int>[0];
    var offset = 0;
    for (final char in chars) {
      offset += char.length;
      offsets.add(offset);
    }

    final widths = <double>[];
    final visualLefts = <double>[];
    for (var i = 0; i < chars.length; i++) {
      final bounds = _glyphBounds(painter, offsets[i], offsets[i + 1]);
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
    final visualOrder = [for (var i = 0; i < chars.length; i++) i]
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

  static _GlyphBounds _glyphBounds(TextPainter painter, int start, int end) {
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
      return _GlyphBounds(width: width, left: left.isFinite ? left : 0);
    }

    final startDx = _caretDx(painter, start);
    final endDx = _caretDx(painter, end);
    return _GlyphBounds(
      width: (endDx - startDx).abs(),
      left: math.min(startDx, endDx),
    );
  }
}

class _GlyphBounds {
  const _GlyphBounds({required this.width, required this.left});

  final double width;
  final double left;
}

class _GlyphMetrics {
  const _GlyphMetrics({
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
