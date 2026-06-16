part of 'reel_text.dart';

class _TextRunMetrics {
  const _TextRunMetrics({
    required this.widths,
    required this.lefts,
    required this.width,
    required this.height,
  });

  final List<double> widths;
  final List<double> lefts;
  final double width;
  final double height;

  double widthAt(int index) {
    if (index < 0 || index >= widths.length) {
      return 0;
    }
    return widths[index];
  }

  double leftAt(int index) {
    if (index < 0) {
      return 0;
    }
    if (index >= lefts.length) {
      return width;
    }
    return lefts[index];
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
    final lefts = <double>[];
    for (var i = 0; i < chars.length; i++) {
      final bounds = _glyphBounds(painter, offsets[i], offsets[i + 1]);
      widths.add(bounds.width);
      lefts.add(bounds.left);
    }

    final measured = widths.fold<double>(0, (sum, width) => sum + width);
    if (widths.isNotEmpty && (measured - painter.size.width).abs() > 1e-9) {
      final index = widths.lastIndexWhere((width) => width > 0);
      if (index >= 0) {
        widths[index] =
            math.max(0, widths[index] + painter.size.width - measured);
      }
    }

    final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);
    return _TextRunMetrics(
      widths: widths,
      lefts: lefts,
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
      final left = boxes.fold<double>(
        double.infinity,
        (min, box) => math.min(min, math.min(box.left, box.right)),
      );
      final width = boxes.fold<double>(
        0,
        (sum, box) => sum + (box.right - box.left).abs(),
      );
      return _GlyphBounds(left: left, width: width);
    }

    final startDx = _caretDx(painter, start);
    final endDx = _caretDx(painter, end);
    return _GlyphBounds(
      left: math.min(startDx, endDx),
      width: (endDx - startDx).abs(),
    );
  }
}

class _GlyphBounds {
  const _GlyphBounds({required this.left, required this.width});

  final double left;
  final double width;
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
