part of 'reel_text.dart';

/// Builds the resting text span for [ReelTextEditingController].
typedef ReelTextEditingSpanBuilder = TextSpan Function(
  BuildContext context,
  String text,
  TextStyle style,
  bool withComposing,
);

/// A text replacement that [ReelTextEditingController] can animate inline.
class ReelTextEditReplacement {
  /// Creates an inline editable-text replacement.
  const ReelTextEditReplacement({
    required this.range,
    required this.replacement,
    this.options,
    this.key,
    this.style,
    this.semanticsLabel,
  });

  /// Range in the controller's current text that should roll to [replacement].
  final TextRange range;

  /// Text shown by the inline [ReelText] during the correction.
  final String replacement;

  /// Options for this replacement. Falls back to the surrounding [ReelText]
  /// defaults when omitted.
  final ReelTextOptions? options;

  /// Optional key for the inline [ReelText] widget.
  final Key? key;

  /// Optional style override merged with the editable text style.
  final TextStyle? style;

  /// Optional semantics label for the inline [ReelText].
  final String? semanticsLabel;
}

/// A [TextEditingController] that can render animated [ReelText] replacements
/// directly inside Flutter's editable text layout.
///
/// This keeps the animated correction in the same [EditableText] render flow as
/// caret, selection, wrapping, and scrolling instead of drawing a separate
/// overlay.
class ReelTextEditingController extends TextEditingController {
  /// Creates a controller for editable text with optional initial [text].
  ///
  /// Use [spanBuilder] to customize the non-animated text span without
  /// subclassing the controller.
  ReelTextEditingController({super.text, this.spanBuilder});

  final _activeReplacements = <_ActiveReelTextReplacement>[];

  /// Custom builder for the non-animated text span.
  final ReelTextEditingSpanBuilder? spanBuilder;

  Timer? _autoCommitTimer;
  int _replacementEpoch = 0;

  /// Whether this controller is currently rendering inline replacements.
  bool get hasActiveReplacements => _activeReplacements.isNotEmpty;

  /// Starts rendering the supplied replacement ranges as inline [ReelText].
  void beginReplacements(
    Iterable<ReelTextEditReplacement> replacements, {
    bool notify = true,
  }) {
    clearReplacements(notify: false);
    final sorted = replacements.toList()
      ..sort((a, b) => a.range.start.compareTo(b.range.start));

    var cursor = 0;
    for (final replacement in sorted) {
      final range = replacement.range;
      if (!range.isValid ||
          range.start < 0 ||
          range.end > text.length ||
          range.start > range.end) {
        throw FlutterError(
          'ReelTextEditReplacement range $range is outside the current text.',
        );
      }
      if (range.start < cursor) {
        throw FlutterError('ReelTextEditReplacement ranges must not overlap.');
      }
      cursor = range.end;
      _activeReplacements.add(
        _ActiveReelTextReplacement(
          replacement: replacement,
          source: text.substring(range.start, range.end),
        ),
      );
    }
    _replacementEpoch++;

    if (notify) {
      notifyListeners();
    }
  }

  /// Rolls active inline replacements to their target text.
  ///
  /// When [replacements] is provided, it first replaces any active inline
  /// animations with that set. When [commitAfter] is provided, the replacement
  /// text is committed automatically after the delay.
  void animateReplacements({
    Duration? commitAfter,
    Iterable<ReelTextEditReplacement>? replacements,
    TextSelection? selection,
    bool notify = true,
  }) {
    _cancelAutoCommit();
    final hasNewReplacements = replacements != null;
    if (replacements != null) {
      beginReplacements(replacements, notify: notify);
    }

    final epoch = _replacementEpoch;
    void rollActiveReplacements() {
      if (epoch != _replacementEpoch) {
        return;
      }
      for (final active in _activeReplacements) {
        active.controller.set(
          active.replacement.replacement,
          options: active.replacement.options,
        );
      }
    }

    if (hasNewReplacements && notify) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rollActiveReplacements();
      });
    } else {
      rollActiveReplacements();
    }

    if (commitAfter != null) {
      _autoCommitTimer = Timer(commitAfter, () {
        if (epoch != _replacementEpoch) {
          _autoCommitTimer = null;
          return;
        }
        _autoCommitTimer = null;
        commitReplacements(selection: selection);
      });
    }
  }

  /// Returns the text after applying all active replacements.
  String replacementText() {
    if (_activeReplacements.isEmpty) {
      return text;
    }

    final buffer = StringBuffer();
    var cursor = 0;
    for (final active in _activeReplacements) {
      final range = active.replacement.range;
      buffer.write(text.substring(cursor, range.start));
      buffer.write(active.replacement.replacement);
      cursor = range.end;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  /// Applies active replacements to [value] and clears the inline animations.
  void commitReplacements({TextSelection? selection}) {
    _cancelAutoCommit();
    final nextText = replacementText();
    clearReplacements(notify: false);
    value = value.copyWith(
      text: nextText,
      selection: selection ?? TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }

  /// Removes active inline replacements.
  void clearReplacements({bool notify = true}) {
    _cancelAutoCommit();
    if (_activeReplacements.isEmpty) {
      return;
    }
    for (final active in _activeReplacements) {
      active.dispose();
    }
    _activeReplacements.clear();
    _replacementEpoch++;
    if (notify) {
      notifyListeners();
    }
  }

  /// Builds the normal editable text span when no replacement is active.
  @protected
  TextSpan buildRestingTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final builder = spanBuilder;
    if (builder != null) {
      return builder(context, text, style ?? const TextStyle(), withComposing);
    }
    return super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_activeReplacements.isEmpty) {
      return buildRestingTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final baseStyle = style ?? const TextStyle();
    final strutStyle = _editableTextStrutStyleOf(context);
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final active in _activeReplacements) {
      final replacement = active.replacement;
      final range = replacement.range;
      if (range.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: ReelText.controller(
            key: replacement.key,
            controller: active.controller,
            options: replacement.options ?? const ReelTextOptions(),
            semanticsLabel:
                replacement.semanticsLabel ?? replacement.replacement,
            style: replacement.style == null
                ? baseStyle
                : baseStyle.merge(replacement.style),
            strutStyle: strutStyle,
          ),
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(style: baseStyle, children: children);
  }

  @override
  void dispose() {
    clearReplacements(notify: false);
    super.dispose();
  }

  void _cancelAutoCommit() {
    _autoCommitTimer?.cancel();
    _autoCommitTimer = null;
  }
}

StrutStyle? _editableTextStrutStyleOf(BuildContext context) {
  final widget = context.widget;
  if (widget is EditableText) {
    return widget.strutStyle;
  }
  return context.findAncestorWidgetOfExactType<EditableText>()?.strutStyle;
}

class _ActiveReelTextReplacement {
  _ActiveReelTextReplacement({
    required this.replacement,
    required String source,
  }) : controller = ReelTextController(initialText: source);

  final ReelTextEditReplacement replacement;
  final ReelTextController controller;

  void dispose() => controller.dispose();
}
