part of 'reel_text.dart';

class _ReelTextFrame {
  const _ReelTextFrame(this.text, [this.richText]);

  final String text;
  final InlineSpan? richText;

  String get semanticsText {
    final richText = this.richText;
    if (richText == null) {
      return text;
    }
    return richText.toPlainText(
      includeSemanticsLabels: true,
      includePlaceholders: false,
    );
  }

  _ReelTextContent contentFor(TextStyle style) {
    final richText = this.richText;
    if (richText == null) {
      return _ReelTextContent.plain(text, style);
    }

    final plainText = richText.toPlainText(
      includeSemanticsLabels: false,
      includePlaceholders: true,
    );
    if (plainText != text) {
      return _ReelTextContent.plain(text, style);
    }
    return _ReelTextContent.rich(richText, style);
  }
}

typedef _PendingRoll = ({
  _ReelTextFrame frame,
  ReelTextOptions options,
  bool force,
});

typedef _MeasuredReelTextFrame = ({
  _ReelTextFrame frame,
  _ReelTextContent content,
  _MeasuredReelTextRun run,
});

class _ReelTextMeasureKey {
  const _ReelTextMeasureKey({
    required this.frame,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
    required this.textScaler,
    required this.widgetSpanMetricsRevision,
  });

  final _ReelTextFrame frame;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextScaler textScaler;
  final int widgetSpanMetricsRevision;

  @override
  bool operator ==(Object other) {
    return other is _ReelTextMeasureKey &&
        _sameFrameTarget(frame, other.frame) &&
        style == other.style &&
        textDirection == other.textDirection &&
        locale == other.locale &&
        strutStyle == other.strutStyle &&
        textScaler == other.textScaler &&
        widgetSpanMetricsRevision == other.widgetSpanMetricsRevision;
  }

  @override
  int get hashCode => Object.hash(
        frame.text,
        identityHashCode(frame.richText),
        style,
        textDirection,
        locale,
        strutStyle,
        textScaler,
        widgetSpanMetricsRevision,
      );
}

typedef _ActiveRoll = ({
  _MeasuredReelTextFrame from,
  _MeasuredReelTextFrame to,
  int widgetSpanMetricsRevision,
  ReelTextOptions options,
  _RollPlan plan,
});
