part of 'reel_text.dart';

class _SettledReelText extends StatelessWidget {
  const _SettledReelText({
    super.key,
    required this.content,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final _ReelTextContent content;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final runMetrics = _TextRunMetrics.of(
      context: context,
      span: content.span,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      text: content.plainText,
    );
    final glyphRow = Row(
      key: const ValueKey('reel_text_settled_glyphs'),
      mainAxisSize: MainAxisSize.min,
      textDirection: textDirection,
      children: [
        for (final (index, glyph) in content.glyphs.indexed)
          _SettledGlyphSlot(
            glyph.text,
            width: runMetrics.widthAt(index),
            height: runMetrics.height,
            style: glyph.style,
            textDirection: textDirection,
            locale: locale,
            strutStyle: strutStyle,
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? math.min(runMetrics.width, constraints.maxWidth)
            : runMetrics.width;
        return SizedBox(
          width: viewportWidth,
          height: runMetrics.height,
          child: OverflowBox(
            alignment: _inlineStartAlignment(textDirection),
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: runMetrics.height,
            maxHeight: runMetrics.height,
            child: glyphRow,
          ),
        );
      },
    );
  }
}

class _SettledGlyphSlot extends StatelessWidget {
  const _SettledGlyphSlot(
    this.glyph, {
    required this.width,
    required this.height,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String glyph;
  final double width;
  final double height;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: _inlineStartAlignment(textDirection),
        child: _GlyphFace(
          glyph,
          width: width,
          height: height,
          horizontalBleed: _horizontalGlyphBleed(height),
          style: style,
          textDirection: textDirection,
          locale: locale,
          strutStyle: strutStyle,
        ),
      ),
    );
  }
}

class _GlyphSlot extends StatelessWidget {
  const _GlyphSlot({
    required this.slot,
    required this.fromMetrics,
    required this.toMetrics,
    required this.fromContent,
    required this.toContent,
    required this.progressMs,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final _SlotPlan slot;
  final _TextRunMetrics fromMetrics;
  final _TextRunMetrics toMetrics;
  final _ReelTextContent fromContent;
  final _ReelTextContent toContent;
  final double progressMs;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final metrics = _GlyphMetrics(
      fromWidth: slot.from.isEmpty ? 0 : fromMetrics.widthAt(slot.index),
      toWidth: slot.to.isEmpty ? 0 : toMetrics.widthAt(slot.index),
      height: math.max(fromMetrics.height, toMetrics.height),
    );
    final fromStyle = fromContent.glyphAt(slot.index)?.style;
    final toStyle = toContent.glyphAt(slot.index)?.style;
    final effectiveToStyle = toStyle ?? fromStyle ?? const TextStyle();
    final travelDistance =
        metrics.height + _verticalSlotBleed(metrics.height) * 2;

    if (!slot.changed) {
      return SizedBox(
        width: metrics.toWidth,
        height: metrics.height,
        child: _GlyphFace(
          slot.to,
          width: metrics.toWidth,
          height: metrics.height,
          horizontalBleed: _horizontalGlyphBleed(metrics.height),
          style: effectiveToStyle,
          textDirection: textDirection,
          locale: locale,
          strutStyle: strutStyle,
        ),
      );
    }
    final width = ui.lerpDouble(
      metrics.fromWidth,
      metrics.toWidth,
      slot.widthT(progressMs),
    )!;
    final textColor =
        effectiveToStyle.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    final incomingColor = slot.color == null
        ? textColor
        : Color.lerp(slot.color, textColor, slot.colorT(progressMs))!;
    final effectiveFromStyle = fromStyle ?? effectiveToStyle;

    return ClipRect(
      clipper: const _VerticalSlotClipper(),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: metrics.height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: _inlineStartAlignment(textDirection),
          children: [
            if (slot.from.isNotEmpty)
              Opacity(
                opacity: slot.outOpacity(progressMs),
                child: Transform.translate(
                  offset: Offset(0, slot.outY(progressMs, travelDistance)),
                  child: Transform.rotate(
                    angle: -slot.tiltRadians * slot.outT(progressMs),
                    child: _GlyphFace(
                      slot.from,
                      width: metrics.fromWidth,
                      height: metrics.height,
                      horizontalBleed: _horizontalGlyphBleed(metrics.height),
                      style: effectiveFromStyle,
                      textDirection: textDirection,
                      locale: locale,
                      strutStyle: strutStyle,
                    ),
                  ),
                ),
              ),
            if (slot.to.isNotEmpty)
              Transform.translate(
                offset: Offset(0, slot.inY(progressMs, travelDistance)),
                child: Transform.rotate(
                  angle: slot.tiltRadians * (1 - slot.inT(progressMs)),
                  child: _GlyphFace(
                    slot.to,
                    width: metrics.toWidth,
                    height: metrics.height,
                    horizontalBleed: _horizontalGlyphBleed(metrics.height),
                    style: effectiveToStyle.copyWith(color: incomingColor),
                    textDirection: textDirection,
                    locale: locale,
                    strutStyle: strutStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
double _horizontalGlyphBleed(double height) => math.max(4, height * 0.08);

class _GlyphFace extends StatelessWidget {
  const _GlyphFace(
    this.text, {
    required this.width,
    required this.height,
    this.horizontalBleed = 0,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String text;
  final double width;
  final double height;
  final double horizontalBleed;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final paintWidth = width + horizontalBleed;
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        alignment: _inlineStartAlignment(textDirection),
        minWidth: paintWidth,
        maxWidth: paintWidth,
        minHeight: height,
        maxHeight: height,
        child: SizedBox(
          width: paintWidth,
          height: height,
          child: _GlyphText(
            text,
            style: style,
            textDirection: textDirection,
            locale: locale,
            strutStyle: strutStyle,
          ),
        ),
      ),
    );
  }
}

class _GlyphText extends StatelessWidget {
  const _GlyphText(
    this.text, {
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      softWrap: false,
    );
  }
}
