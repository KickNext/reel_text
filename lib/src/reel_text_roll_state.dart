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
