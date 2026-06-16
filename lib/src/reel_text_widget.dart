part of 'reel_text.dart';

/// Text widget that rolls changed glyphs through clipped slots.
class ReelText extends StatefulWidget {
  /// Creates a declarative reel text widget.
  const ReelText(
    this.text, {
    super.key,
    this.options = const ReelTextOptions(),
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.semanticsLabel,
    this.respectDisableAnimations = true,
  }) : controller = null,
       richText = null,
       _sequenceValues = null,
       _sequenceInterval = null,
       _sequenceOptionsBuilder = null;

  /// Creates a declarative reel text widget from a styled [TextSpan] tree.
  ///
  /// The span tree is split by grapheme clusters, so emoji sequences remain
  /// whole glyphs while each cluster keeps the effective style inherited from
  /// the provided span.
  const ReelText.rich(
    InlineSpan this.richText, {
    super.key,
    this.options = const ReelTextOptions(),
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.semanticsLabel,
    this.respectDisableAnimations = true,
  }) : text = null,
       controller = null,
       _sequenceValues = null,
       _sequenceInterval = null,
       _sequenceOptionsBuilder = null;

  /// Creates an imperative reel text widget driven by [controller].
  const ReelText.controller({
    super.key,
    required ReelTextController this.controller,
    this.options = const ReelTextOptions(),
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.semanticsLabel,
    this.respectDisableAnimations = true,
  }) : text = null,
       richText = null,
       _sequenceValues = null,
       _sequenceInterval = null,
       _sequenceOptionsBuilder = null;

  /// Creates a reel text widget that cycles through [values] on [interval].
  ///
  /// Use [optionsBuilder] when each value needs a different direction, color, or
  /// timing. The builder is called only for values after the initial one.
  const ReelText.sequence({
    super.key,
    required List<String> values,
    Duration interval = const Duration(seconds: 2),
    ReelTextSequenceOptionsBuilder? optionsBuilder,
    this.options = const ReelTextOptions(),
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.semanticsLabel,
    this.respectDisableAnimations = true,
  }) : text = null,
       richText = null,
       controller = null,
       _sequenceValues = values,
       _sequenceInterval = interval,
       _sequenceOptionsBuilder = optionsBuilder;

  /// Target text in declarative mode.
  final String? text;

  /// Target styled text in declarative rich-text mode.
  final InlineSpan? richText;

  /// Controller in imperative mode.
  final ReelTextController? controller;

  final List<String>? _sequenceValues;
  final Duration? _sequenceInterval;
  final ReelTextSequenceOptionsBuilder? _sequenceOptionsBuilder;

  /// Default animation options.
  final ReelTextOptions options;

  /// Text style.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Text direction.
  final TextDirection? textDirection;

  /// Text locale.
  final Locale? locale;

  /// Strut style.
  final StrutStyle? strutStyle;

  /// Accessibility label. Defaults to the current value.
  final String? semanticsLabel;

  /// Snaps to the target text without rolling when the platform requests
  /// reduced motion ([MediaQuery.disableAnimationsOf]).
  final bool respectDisableAnimations;

  @override
  State<ReelText> createState() => _ReelTextState();
}

class _ReelTextState extends State<ReelText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late String _displayedText;
  InlineSpan? _displayedRichText;
  String? _targetText;
  InlineSpan? _targetRichText;
  _RollPlan? _plan;
  _ReelTextCommand? _pending;
  Timer? _sequenceTimer;
  int _sequenceIndex = 0;

  String get _effectiveText =>
      widget.controller?.value ??
      widget.richText?.toPlainText(
        includeSemanticsLabels: false,
        includePlaceholders: false,
      ) ??
      widget.text ??
      _firstSequenceValue(widget._sequenceValues) ??
      '';

  @override
  void initState() {
    super.initState();
    _displayedText = _effectiveText;
    _displayedRichText = widget.richText;
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishRoll();
        }
      });
    widget.controller?.addListener(_handleControllerChange);
    _startSequenceTimerIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Snap an in-flight roll when the platform switches to reduced motion.
    if (_animationsDisabled && _targetText != null) {
      _controller.stop();
      _displayedText = _targetText!;
      _displayedRichText = _targetRichText;
      _targetText = null;
      _targetRichText = null;
      _plan = null;
      _pending = null;
    }
  }

  @override
  void didUpdateWidget(covariant ReelText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sequenceConfigChanged(oldWidget)) {
      _sequenceTimer?.cancel();
      _sequenceTimer = null;
      _sequenceIndex = 0;
      if (widget._sequenceValues != null) {
        _controller.stop();
        _displayedText = _effectiveText;
        _displayedRichText = null;
        _targetText = null;
        _targetRichText = null;
        _plan = null;
        _pending = null;
        _startSequenceTimerIfNeeded();
        return;
      }
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      widget.controller?.addListener(_handleControllerChange);
      _displayedText = _effectiveText;
      _displayedRichText = widget.richText;
      _targetText = null;
      _targetRichText = null;
      _plan = null;
      _controller.stop();
    } else if (widget.controller == null &&
        (oldWidget.text != widget.text ||
            oldWidget.richText != widget.richText)) {
      _rollTo(_effectiveText, widget.options, richText: widget.richText);
    }
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    widget.controller?.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }
    final command = widget.controller!._currentCommand;
    if (command == null) {
      return;
    }
    _rollTo(
      command.text,
      widget.options._merge(command.options),
      force: command.force,
    );
  }

  bool get _animationsDisabled =>
      widget.respectDisableAnimations &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _startSequenceTimerIfNeeded() {
    final values = widget._sequenceValues;
    if (values == null || values.length < 2) {
      return;
    }
    _sequenceTimer = Timer.periodic(widget._sequenceInterval!, (_) {
      if (!mounted) {
        return;
      }
      _sequenceIndex = (_sequenceIndex + 1) % values.length;
      final value = values[_sequenceIndex];
      final options =
          widget._sequenceOptionsBuilder?.call(_sequenceIndex, value) ??
          widget.options;
      _rollTo(value, options);
    });
  }

  bool _sequenceConfigChanged(ReelText oldWidget) {
    return !_sameStringList(
          oldWidget._sequenceValues,
          widget._sequenceValues,
        ) ||
        oldWidget._sequenceInterval != widget._sequenceInterval ||
        oldWidget._sequenceOptionsBuilder != widget._sequenceOptionsBuilder;
  }

  void _rollTo(
    String text,
    ReelTextOptions options, {
    InlineSpan? richText,
    bool force = false,
  }) {
    if (_animationsDisabled) {
      _controller.stop();
      setState(() {
        _displayedText = text;
        _displayedRichText = richText;
        _targetText = null;
        _targetRichText = null;
        _plan = null;
        _pending = null;
      });
      return;
    }

    if (_controller.isAnimating && !options.interrupt) {
      if (force || text != _targetText) {
        _pending = _ReelTextCommand(text, options, force: force);
      }
      return;
    }

    if (_controller.isAnimating && options.interrupt && _targetText != null) {
      _controller.stop();
      _displayedText = _targetText!;
      _displayedRichText = _targetRichText;
      _pending = null;
      _plan = null;
    }

    if (_displayedText == text && !force) {
      setState(() {
        _displayedRichText = richText;
        _targetText = null;
        _targetRichText = null;
        _plan = null;
      });
      return;
    }

    final plan = _RollPlan.create(
      fromText: _displayedText,
      toText: text,
      options: options,
    );

    setState(() {
      _targetText = text;
      _targetRichText = richText;
      _plan = plan;
    });

    if (!plan.hasMotion) {
      _finishRoll();
      return;
    }

    _controller.duration = plan.totalDuration;
    _controller.forward(from: 0);
  }

  void _finishRoll() {
    final finishedText = _targetText;
    if (finishedText == null) {
      return;
    }
    _controller.stop();
    setState(() {
      _displayedText = finishedText;
      _displayedRichText = _targetRichText;
      _plan = null;
      _targetText = null;
      _targetRichText = null;
    });

    final pending = _pending;
    _pending = null;
    if (pending != null && (pending.force || pending.text != _displayedText)) {
      _rollTo(
        pending.text,
        widget.options._merge(pending.options),
        force: pending.force,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction =
        widget.textDirection ??
        Directionality.maybeOf(context) ??
        TextDirection.ltr;
    final defaultTextStyle = DefaultTextStyle.of(context);
    final defaultStyle = defaultTextStyle.style;
    final style = defaultStyle.merge(widget.style);
    final effectiveTextAlign =
        widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final visibleText = _targetText ?? _displayedText;
    final visibleRichText = _targetText == null
        ? _displayedRichText
        : _targetRichText;
    final visibleContent = _contentFor(visibleText, visibleRichText, style);
    final plan = _plan;

    Widget child;
    if (plan == null) {
      child = _SettledReelText(
        content: _contentFor(_displayedText, _displayedRichText, style),
        key: const ValueKey('reel_text_settled'),
        textDirection: direction,
        locale: widget.locale,
        strutStyle: widget.strutStyle,
      );
    } else {
      final fromContent = _contentFor(plan.fromText, _displayedRichText, style);
      final toContent = _contentFor(plan.toText, _targetRichText, style);
      final fromMetrics = _TextRunMetrics.of(
        context: context,
        span: fromContent.span,
        textDirection: direction,
        locale: widget.locale,
        strutStyle: widget.strutStyle,
        text: plan.fromText,
      );
      final toMetrics = _TextRunMetrics.of(
        context: context,
        span: toContent.span,
        textDirection: direction,
        locale: widget.locale,
        strutStyle: widget.strutStyle,
        text: plan.toText,
      );
      final height = math.max(fromMetrics.height, toMetrics.height);
      final anchorShrinkingRight =
          _alignsToRight(effectiveTextAlign, direction) &&
          toMetrics.width < fromMetrics.width;
      child = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progressMs =
              _controller.value * plan.totalDuration.inMilliseconds;
          final width = _rollingWidth(plan, fromMetrics, toMetrics, progressMs);
          final viewportWidth = anchorShrinkingRight ? toMetrics.width : width;
          final rollingRow = Row(
            key: const ValueKey('reel_text_rolling'),
            mainAxisSize: MainAxisSize.min,
            textDirection: direction,
            children: [
              for (final slot in plan.slots)
                _GlyphSlot(
                  slot: slot,
                  fromMetrics: fromMetrics,
                  toMetrics: toMetrics,
                  fromContent: fromContent,
                  toContent: toContent,
                  progressMs: progressMs,
                  textDirection: direction,
                  locale: widget.locale,
                  strutStyle: widget.strutStyle,
                ),
            ],
          );
          return SizedBox(
            width: viewportWidth,
            height: height,
            child: OverflowBox(
              alignment: anchorShrinkingRight
                  ? _inlineStartAlignment(direction)
                  : _alignmentForTextAlign(effectiveTextAlign, direction),
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: height,
              maxHeight: height,
              child: rollingRow,
            ),
          );
        },
      );
    }

    child = _ReelTextAlignment(
      textAlign: effectiveTextAlign,
      textDirection: direction,
      child: child,
    );

    return Semantics(
      label: widget.semanticsLabel ?? visibleText,
      child: _ReelTextSelection(
        content: visibleContent,
        textAlign: effectiveTextAlign,
        textDirection: direction,
        locale: widget.locale,
        strutStyle: widget.strutStyle,
        child: child,
      ),
    );
  }

  _ReelTextContent _contentFor(
    String text,
    InlineSpan? richText,
    TextStyle style,
  ) {
    if (richText == null) {
      return _ReelTextContent.plain(text, style);
    }

    final plainText = richText.toPlainText(
      includeSemanticsLabels: false,
      includePlaceholders: false,
    );
    if (plainText != text) {
      return _ReelTextContent.plain(text, style);
    }
    return _ReelTextContent.rich(richText, style);
  }

  double _rollingWidth(
    _RollPlan plan,
    _TextRunMetrics fromMetrics,
    _TextRunMetrics toMetrics,
    double progressMs,
  ) {
    return plan.slots.fold<double>(0, (sum, slot) {
      final fromWidth = slot.from.isEmpty
          ? 0.0
          : fromMetrics.widthAt(slot.index);
      final toWidth = slot.to.isEmpty ? 0.0 : toMetrics.widthAt(slot.index);
      if (!slot.changed) {
        return sum + toWidth;
      }
      return sum + ui.lerpDouble(fromWidth, toWidth, slot.widthT(progressMs))!;
    });
  }
}

bool _sameStringList(List<String>? a, List<String>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

String? _firstSequenceValue(List<String>? values) {
  if (values == null || values.isEmpty) {
    return null;
  }
  return values.first;
}
