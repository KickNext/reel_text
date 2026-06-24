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

class _PendingRoll {
  const _PendingRoll(this.frame, this.options, {this.force = false});

  final _ReelTextFrame frame;
  final ReelTextOptions options;
  final bool force;
}

class _MeasuredReelTextFrame {
  const _MeasuredReelTextFrame({
    required this.frame,
    required this.content,
    required this.run,
  });

  final _ReelTextFrame frame;
  final _ReelTextContent content;
  final _MeasuredReelTextRun run;
}

class _SettledReelTextCache {
  const _SettledReelTextCache({
    required this.key,
    required this.measured,
    required this.child,
  });

  final _SettledReelTextCacheKey key;
  final _MeasuredReelTextFrame measured;
  final Widget child;
}

class _SettledReelTextCacheKey {
  const _SettledReelTextCacheKey({
    required this.frame,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
    required this.textScaler,
    required this.widgetSpanMetricsVersion,
  });

  final _ReelTextFrame frame;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextScaler textScaler;
  final int widgetSpanMetricsVersion;

  @override
  bool operator ==(Object other) {
    return other is _SettledReelTextCacheKey &&
        _sameFrameTarget(frame, other.frame) &&
        style == other.style &&
        textDirection == other.textDirection &&
        locale == other.locale &&
        strutStyle == other.strutStyle &&
        textScaler == other.textScaler &&
        widgetSpanMetricsVersion == other.widgetSpanMetricsVersion;
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
        widgetSpanMetricsVersion,
      );
}

class _ActiveRoll {
  const _ActiveRoll({
    required this.from,
    required this.to,
    required this.options,
    required this.plan,
  });

  final _MeasuredReelTextFrame from;
  final _MeasuredReelTextFrame to;
  final ReelTextOptions options;
  final _RollPlan plan;
}
