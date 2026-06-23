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
  late final AnimationController _controller;
  late _ReelTextFrame _displayedFrame;
  _ReelTextFrame? _targetFrame;
  _ActiveRoll? _roll;
  _PendingRoll? _pending;
  Timer? _sequenceTimer;
  int _sequenceIndex = 0;
  final _widgetSpanSizes = _WidgetSpanSizeRegistry();

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
    // Snap an in-flight roll when the platform switches to reduced motion.
    if (_animationsDisabled && _targetFrame != null) {
      _controller.stop();
      _displayedFrame = _targetFrame!;
      _targetFrame = null;
      _roll = null;
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
        _displayedFrame = _effectiveFrame;
        _targetFrame = null;
        _roll = null;
        _pending = null;
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
        _pending = _PendingRoll(targetFrame, options, force: force);
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
    final direction = widget.textDirection ??
        Directionality.maybeOf(context) ??
        TextDirection.ltr;
    final defaultTextStyle = DefaultTextStyle.of(context);
    final defaultStyle = defaultTextStyle.style;
    final style = defaultStyle.merge(widget.style);
    final effectiveTextAlign =
        widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start;
    final layout = _layoutContextFor(direction);
    final visibleFrame = _targetFrame ?? _displayedFrame;
    final visibleSemanticsText = visibleFrame.semanticsText;
    final roll = _roll;
    final visibleContent =
        roll?.to.content ?? _displayedFrame.contentFor(style);

    Widget child;
    if (roll == null) {
      child = _SettledReelText(
        content: visibleContent,
        key: const ValueKey('reel_text_settled'),
        layout: layout,
      );
    } else {
      child = _RollingReelText(
        plan: roll.plan,
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

    return Semantics(
      label: widget.semanticsLabel ?? visibleSemanticsText,
      child: _ReelTextSelection(
        content: visibleContent,
        textAlign: effectiveTextAlign,
        layout: layout,
        child: child,
      ),
    );
  }

  void _handleWidgetSpanSizeChanged(int index, WidgetSpan span, Size size) {
    if (!mounted) {
      return;
    }
    if (_widgetSpanSizes.hasSize(index, span, size)) {
      return;
    }
    setState(() {
      _widgetSpanSizes.setSize(index, span, size);
      final targetFrame = _targetFrame;
      final roll = _roll;
      if (targetFrame != null && roll != null) {
        _roll = _createRoll(targetFrame, roll.options);
      }
    });
  }

  _ReelTextLayoutContext _layoutContextFor(TextDirection direction) {
    return _ReelTextLayoutContext(
      textDirection: direction,
      locale: widget.locale,
      strutStyle: widget.strutStyle,
      widgetSpanSizeFor: _widgetSpanSizes.sizeFor,
      onWidgetSpanSizeChanged: _handleWidgetSpanSizeChanged,
    );
  }

  _MeasuredReelTextRun _measuredRunFor(
    _ReelTextContent content,
    _ReelTextLayoutContext layout,
  ) {
    return _MeasuredReelTextRun.of(
      context: context,
      content: content,
      layout: layout,
    );
  }

  _ActiveRoll _createRoll(_ReelTextFrame targetFrame, ReelTextOptions options) {
    final direction = widget.textDirection ??
        Directionality.maybeOf(context) ??
        TextDirection.ltr;
    final defaultTextStyle = DefaultTextStyle.of(context);
    final style = defaultTextStyle.style.merge(widget.style);
    final layout = _layoutContextFor(direction);
    final from = _measureFrame(_displayedFrame, style, layout);
    final to = _measureFrame(targetFrame, style, layout);
    final plan = _RollPlan.create(
      from: from.run,
      to: to.run,
      options: options,
      alignVisualOrderFromEnd: direction == TextDirection.rtl,
    );

    return _ActiveRoll(
      from: from,
      to: to,
      options: options,
      plan: plan,
    );
  }

  _MeasuredReelTextFrame _measureFrame(
    _ReelTextFrame frame,
    TextStyle style,
    _ReelTextLayoutContext layout,
  ) {
    final content = frame.contentFor(style);
    return _MeasuredReelTextFrame(
      frame: frame,
      content: content,
      run: _measuredRunFor(content, layout),
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
