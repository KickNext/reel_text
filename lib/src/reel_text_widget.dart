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
  })  : controller = null,
        richText = null,
        _sequenceValues = null,
        _sequenceInterval = null,
        _sequenceOptionsBuilder = null;

  /// Creates a declarative reel text widget from a styled [TextSpan] tree.
  ///
  /// The span tree is split by grapheme clusters, so emoji sequences remain
  /// whole glyphs while each cluster keeps the effective style inherited from
  /// the provided span. [WidgetSpan] leaves are kept as inline widgets while
  /// neighboring text clusters roll.
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
  })  : text = null,
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
  })  : text = null,
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
  })  : text = null,
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

  /// Accessibility label.
  ///
  /// Defaults to the current plain value. In [ReelText.rich], nested
  /// [TextSpan.semanticsLabel] values are used unless this override is set.
  final String? semanticsLabel;

  /// Snaps to the target text without rolling when the platform requests
  /// reduced motion ([MediaQuery.disableAnimationsOf]).
  final bool respectDisableAnimations;

  @override
  State<ReelText> createState() => _ReelTextState();
}

class _ReelTextState extends State<ReelText>
    with SingleTickerProviderStateMixin {
  static const _maxMeasuredFrameCacheEntries = 4;

  late final AnimationController _controller;
  late _ReelTextFrame _displayedFrame;
  _ReelTextFrame? _targetFrame;
  _ActiveRoll? _roll;
  _PendingRoll? _pending;
  Timer? _sequenceTimer;
  int _sequenceIndex = 0;
  int _frameMeasureCount = 0;
  bool _activeRollEnvironmentDirty = false;
  late TextDirection _inheritedTextDirection;
  late DefaultTextStyle _inheritedDefaultTextStyle;
  Locale? _inheritedLocale;
  TextScaler _inheritedTextScaler = TextScaler.noScaling;
  bool _inheritedAnimationsDisabled = false;
  bool _inheritedBoldText = false;
  final _widgetSpans = _WidgetSpanLayoutModel();
  final _measuredFrameCache = <_ReelTextMeasureKey, _MeasuredReelTextFrame>{};

  int get debugFrameMeasureCount => _frameMeasureCount;

  String get _effectiveText =>
      widget.controller?.value ??
      (widget.richText == null ? null : _rollingTextFor(widget.richText!)) ??
      widget.text ??
      _firstSequenceValue(widget._sequenceValues) ??
      '';

  _ReelTextFrame get _effectiveFrame =>
      _ReelTextFrame(_effectiveText, widget.richText);

  String get _displayedText => _displayedFrame.text;

  @override
  void initState() {
    super.initState();
    _displayedFrame = _effectiveFrame;
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
    if (_roll != null) {
      _activeRollEnvironmentDirty = true;
    }
    _inheritedTextDirection =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    _inheritedDefaultTextStyle = DefaultTextStyle.of(context);
    _inheritedLocale = Localizations.maybeLocaleOf(context);
    _inheritedTextScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    _inheritedAnimationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _inheritedBoldText = MediaQuery.maybeBoldTextOf(context) ?? false;
    // Snap an in-flight roll when the platform switches to reduced motion.
    if (_animationsDisabled && _targetFrame != null) {
      _controller.stop();
      _displayedFrame = _targetFrame!;
      _targetFrame = null;
      _roll = null;
      _pending = null;
      _activeRollEnvironmentDirty = false;
    }
  }

  @override
  void didUpdateWidget(covariant ReelText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // didUpdateWidget runs before didChangeDependencies, so a text change in
    // the same frame that reduced motion is toggled must not act on the stale
    // cached value.
    _inheritedAnimationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_roll != null &&
        (oldWidget.style != widget.style ||
            oldWidget.textDirection != widget.textDirection ||
            oldWidget.locale != widget.locale ||
            oldWidget.strutStyle != widget.strutStyle)) {
      _activeRollEnvironmentDirty = true;
    }
    if (_sequenceConfigChanged(oldWidget)) {
      _sequenceTimer?.cancel();
      _sequenceTimer = null;
      _sequenceIndex = 0;
      if (widget._sequenceValues != null) {
        _controller.stop();
        _displayedFrame = _effectiveFrame;
        _targetFrame = null;
        _roll = null;
        _pending = null;
        _activeRollEnvironmentDirty = false;
        _startSequenceTimerIfNeeded();
        return;
      }
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      widget.controller?.addListener(_handleControllerChange);
      _displayedFrame = _effectiveFrame;
      _targetFrame = null;
      _roll = null;
      _pending = null;
      _activeRollEnvironmentDirty = false;
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
      widget.respectDisableAnimations && _inheritedAnimationsDisabled;

  /// Applies the platform "bold text" accessibility setting the way [Text]
  /// does, so painted faces stay in sync with regular text.
  TextStyle _applyBoldText(TextStyle style) {
    if (!_inheritedBoldText) {
      return style;
    }
    return style.merge(const TextStyle(fontWeight: FontWeight.bold));
  }

  void _startSequenceTimerIfNeeded() {
    final values = widget._sequenceValues;
    if (values == null || values.length < 2) {
      return;
    }
    _requirePositiveDuration(widget._sequenceInterval!, 'interval');
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
    return !listEquals(
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
    _validateReelTextOptions(options);
    final targetFrame = _ReelTextFrame(text, richText);
    if (_animationsDisabled) {
      _controller.stop();
      setState(() {
        _displayedFrame = targetFrame;
        _targetFrame = null;
        _roll = null;
        _pending = null;
      });
      return;
    }

    if (_controller.isAnimating && !options.interrupt) {
      final currentTarget = _targetFrame;
      if (force ||
          currentTarget == null ||
          !_sameFrameTarget(currentTarget, targetFrame)) {
        _pending = (frame: targetFrame, options: options, force: force);
      }
      return;
    }

    if (_controller.isAnimating && options.interrupt && _targetFrame != null) {
      _controller.stop();
      _displayedFrame = _targetFrame!;
      _targetFrame = null;
      _pending = null;
      _roll = null;
    }

    if (_canReplaceWithoutRoll(targetFrame, force: force)) {
      setState(() {
        _displayedFrame = targetFrame;
        _targetFrame = null;
        _roll = null;
      });
      return;
    }

    final roll = _createRoll(targetFrame, options);
    _activeRollEnvironmentDirty = false;

    setState(() {
      _targetFrame = targetFrame;
      _roll = roll;
    });

    if (!roll.plan.hasMotion) {
      _finishRoll();
      return;
    }

    _controller.duration = roll.plan.totalDuration;
    _controller.forward(from: 0);
  }

  void _finishRoll() {
    final finishedFrame = _targetFrame;
    if (finishedFrame == null) {
      return;
    }
    _controller.stop();
    setState(() {
      _displayedFrame = finishedFrame;
      _roll = null;
      _targetFrame = null;
      _activeRollEnvironmentDirty = false;
    });

    final pending = _pending;
    _pending = null;
    if (pending != null &&
        (pending.force || !_sameFrameTarget(pending.frame, _displayedFrame))) {
      _rollTo(
        pending.frame.text,
        pending.options,
        richText: pending.frame.richText,
        force: pending.force,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _validateReelTextOptions(widget.options);
    final direction = widget.textDirection ?? _inheritedTextDirection;
    final defaultTextStyle = _inheritedDefaultTextStyle;
    final defaultStyle = defaultTextStyle.style;
    final style = _applyBoldText(defaultStyle.merge(widget.style));
    final effectiveTextAlign =
        widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final layout = _layoutContextFor(direction);
    final visibleFrame = _targetFrame ?? _displayedFrame;
    final visibleSemanticsText = visibleFrame.semanticsText;
    final textScaler = _inheritedTextScaler;
    var roll = _roll;
    final targetFrame = _targetFrame;
    if (roll != null &&
        targetFrame != null &&
        (_activeRollEnvironmentDirty ||
            roll.widgetSpanMetricsRevision != _widgetSpans.revision)) {
      roll = _createRoll(targetFrame, roll.options);
      _roll = roll;
      _activeRollEnvironmentDirty = false;
    } else if (roll == null) {
      _activeRollEnvironmentDirty = false;
    }
    late final _ReelTextContent visibleContent;

    Widget child;
    if (roll == null) {
      final measured = _settledReelTextFor(
        frame: _displayedFrame,
        style: style,
        layout: layout,
        textScaler: textScaler,
      );
      visibleContent = measured.content;
      child = _SettledReelText(
        run: measured.run,
        key: const ValueKey('reel_text_settled'),
        layout: layout,
      );
    } else {
      visibleContent = roll.to.content;
      child = _RollingReelText(
        plan: roll.plan,
        defaultTextColor: style.color ?? Colors.black,
        fromRun: roll.from.run,
        toRun: roll.to.run,
        animation: _controller,
        textAlign: effectiveTextAlign,
        layout: layout,
      );
    }

    child = _ReelTextAlignment(
      textAlign: effectiveTextAlign,
      textDirection: direction,
      child: child,
    );

    final explicitSemanticsLabel = widget.semanticsLabel;
    if (explicitSemanticsLabel != null) {
      return Semantics(
        label: explicitSemanticsLabel,
        child: _ReelTextSelection(
          content: visibleContent,
          textAlign: effectiveTextAlign,
          layout: layout,
          excludeVisualSemantics: true,
          child: child,
        ),
      );
    }

    return Semantics(
      label: visibleSemanticsText,
      child: _ReelTextSelection(
        content: visibleContent,
        textAlign: effectiveTextAlign,
        layout: layout,
        excludeVisualSemantics: false,
        child: child,
      ),
    );
  }

  _ReelTextLayoutContext _layoutContextFor(TextDirection direction) {
    return _ReelTextLayoutContext(
      textDirection: direction,
      locale: widget.locale ?? _inheritedLocale,
      strutStyle: widget.strutStyle,
      widgetSpans: _widgetSpans,
    );
  }

  _MeasuredReelTextRun _measuredRunFor(
    _ReelTextContent content,
    _ReelTextLayoutContext layout,
    TextScaler textScaler,
  ) {
    return _MeasuredReelTextRun.of(
      content: content,
      layout: layout,
      textScaler: textScaler,
    );
  }

  _MeasuredReelTextFrame _settledReelTextFor({
    required _ReelTextFrame frame,
    required TextStyle style,
    required _ReelTextLayoutContext layout,
    required TextScaler textScaler,
  }) {
    final key = _measureKey(
      frame: frame,
      style: style,
      layout: layout,
      textScaler: textScaler,
    );
    return _measuredFrameFor(
      key: key,
      frame: frame,
      style: style,
      layout: layout,
      textScaler: textScaler,
    );
  }

  _ActiveRoll _createRoll(_ReelTextFrame targetFrame, ReelTextOptions options) {
    final direction = widget.textDirection ?? _inheritedTextDirection;
    final defaultTextStyle = _inheritedDefaultTextStyle;
    final style = _applyBoldText(defaultTextStyle.style.merge(widget.style));
    final layout = _layoutContextFor(direction);
    final textScaler = _inheritedTextScaler;
    final fromKey = _measureKey(
      frame: _displayedFrame,
      style: style,
      layout: layout,
      textScaler: textScaler,
    );
    final from = _measuredFrameFor(
      key: fromKey,
      frame: _displayedFrame,
      style: style,
      layout: layout,
      textScaler: textScaler,
    );
    final targetKey = _measureKey(
      frame: targetFrame,
      style: style,
      layout: layout,
      textScaler: textScaler,
    );
    final to = _measuredFrameFor(
      key: targetKey,
      frame: targetFrame,
      style: style,
      layout: layout,
      textScaler: textScaler,
    );
    final plan = _RollPlan.create(
      from: from.run,
      to: to.run,
      options: options,
      alignVisualOrderFromEnd: direction == TextDirection.rtl,
    );

    return (
      from: from,
      to: to,
      widgetSpanMetricsRevision: _widgetSpans.revision,
      options: options,
      plan: plan,
    );
  }

  _MeasuredReelTextFrame _measureFrame(
    _ReelTextFrame frame,
    TextStyle style,
    _ReelTextLayoutContext layout,
    TextScaler textScaler,
  ) {
    _frameMeasureCount++;
    final content = frame.contentFor(style);
    return (
      frame: frame,
      content: content,
      run: _measuredRunFor(content, layout, textScaler),
    );
  }

  _MeasuredReelTextFrame _measuredFrameFor({
    required _ReelTextMeasureKey key,
    required _ReelTextFrame frame,
    required TextStyle style,
    required _ReelTextLayoutContext layout,
    required TextScaler textScaler,
  }) {
    final cached = _measuredFrameCache.remove(key);
    if (cached != null) {
      _measuredFrameCache[key] = cached;
      return cached;
    }

    final measured = _measureFrame(frame, style, layout, textScaler);
    _measuredFrameCache[key] = measured;
    if (_measuredFrameCache.length > _maxMeasuredFrameCacheEntries) {
      _measuredFrameCache.remove(_measuredFrameCache.keys.first);
    }
    return measured;
  }

  _ReelTextMeasureKey _measureKey({
    required _ReelTextFrame frame,
    required TextStyle style,
    required _ReelTextLayoutContext layout,
    required TextScaler textScaler,
  }) {
    return _ReelTextMeasureKey(
      frame: frame,
      style: style,
      textDirection: layout.textDirection,
      locale: layout.locale,
      strutStyle: layout.strutStyle,
      textScaler: textScaler,
      widgetSpanMetricsRevision: _widgetSpans.revision,
    );
  }

  bool _canReplaceWithoutRoll(_ReelTextFrame targetFrame,
      {required bool force}) {
    return !force &&
        _displayedText == targetFrame.text &&
        _sameWidgetAnchorSignature(
          _displayedFrame.richText,
          targetFrame.richText,
        );
  }
}

bool _sameFrameTarget(_ReelTextFrame a, _ReelTextFrame b) {
  return a.text == b.text && identical(a.richText, b.richText);
}

String? _firstSequenceValue(List<String>? values) {
  if (values == null || values.isEmpty) {
    return null;
  }
  return values.first;
}
