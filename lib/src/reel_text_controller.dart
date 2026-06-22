part of 'reel_text.dart';

/// Imperative controller for [ReelText.controller].
class ReelTextController extends ChangeNotifier {
  /// Creates a controller with an initial displayed text.
  ReelTextController({required String initialText}) : _value = initialText;

  Timer? _revertTimer;
  Timer? _progressTimer;
  String _value;
  String? _restingText;
  _ReelTextCommand? _command;
  int _progressEpoch = 0;

  /// The currently requested text.
  String get value => _value;

  _ReelTextCommand? get _currentCommand => _command;

  /// Permanently rolls to [text] and cancels any pending flash revert.
  void set(String text, {ReelTextOptions? options}) {
    _cancelFlash();
    _cancelProgress();
    _emit(text, options);
  }

  /// Temporarily rolls to [text], then rolls back to the previous resting text.
  ///
  /// Repeated calls reset the revert timer instead of queueing extra reverts.
  void flash(
    String text, {
    ReelTextFlashOptions options = const ReelTextFlashOptions(),
  }) {
    _cancelProgress();
    _restingText ??= _value;
    _emit(
      text,
      (options.enter ?? const ReelTextOptions()).copyWith(interrupt: false),
    );

    _revertTimer?.cancel();
    _revertTimer = Timer(options.revertAfter, () {
      final back = _restingText!;
      _restingText = null;
      _revertTimer = null;
      _emit(
        back,
        (options.exit ?? const ReelTextOptions()).copyWith(interrupt: false),
      );
    });
  }

  /// Starts an operation label that keeps rolling until the returned handle is
  /// completed, failed, or cancelled.
  ///
  /// [text] is emitted immediately. [frames] can contain additional intermediate
  /// labels, for example `Exportaa`, `Exportee`, and `Exportii`. Matching
  /// glyphs stay fixed by default, so progress should animate only the
  /// uncertain fragment of the word. When [interval] is omitted, frames tick
  /// fast enough to keep the roll continuous. Set [animateUnchanged] to true for
  /// decorative loops that intentionally re-roll identical glyphs.
  ReelTextProgress startProgress(
    String text, {
    List<String> frames = const <String>[],
    ReelTextOptions? options,
    Duration? interval,
    bool animateUnchanged = false,
  }) {
    final sequence = frames.isEmpty
        ? <String>[text]
        : frames.first == text
            ? List<String>.of(frames)
            : <String>[text, ...frames];
    final progressOptions = (options ?? const ReelTextOptions()).copyWith(
      interrupt: false,
      skipUnchanged: !animateUnchanged,
    );
    final tickInterval = interval ??
        Duration(
          milliseconds: (progressOptions.duration.inMilliseconds * 0.55)
              .round()
              .clamp(80, 220)
              .toInt(),
        );

    return _startFrameLoop(
      initial: sequence.first,
      frameAt: (tick) => sequence[tick % sequence.length],
      interval: tickInterval,
      options: progressOptions,
    );
  }

  // Calm motion tuned for the dot/frames loops: short rolls, light bounce.
  static const _tickWaitingDefaults = ReelTextOptions(
    duration: Duration(milliseconds: 240),
    stagger: Duration(milliseconds: 34),
    exitOffset: Duration(milliseconds: 40),
    bounce: 0.25,
  );

  // Calm motion tuned for the breathing wave: slower, no overshoot, almost
  // no tilt, so the loop reads as a ripple instead of a glitch.
  static const _waveWaitingDefaults = ReelTextOptions(
    duration: Duration(milliseconds: 520),
    stagger: Duration(milliseconds: 46),
    exitOffset: Duration(milliseconds: 64),
    curve: Cubic(0.22, 1.0, 0.36, 1.0),
    bounce: 0.1,
  );

  /// Starts a looping idle animation that keeps rolling until the returned
  /// handle is completed, failed, or cancelled.
  ///
  /// [text] is the readable base label. The look of the loop is picked with a
  /// [ReelWaiting] preset: [ReelWaiting.ellipsis] appends rolling dots,
  /// [ReelWaiting.wave] periodically sweeps a re-roll wave across the glyphs,
  /// and [ReelWaiting.frames]/[ReelWaiting.builder] give full control over the
  /// frame sequence.
  ///
  /// ```dart
  /// final handle = controller.startWaiting('Saving');
  /// await save();
  /// handle.complete('Saved');
  /// ```
  ///
  /// Calling [startWaiting] again restarts the loop from the first frame. If
  /// the trigger can be tapped repeatedly, keep the handle and skip re-entry
  /// while [ReelTextProgress.isActive] is true.
  ReelTextProgress startWaiting(
    String text, {
    ReelWaiting waiting = const ReelWaiting.ellipsis(),
    ReelTextOptions? options,
  }) {
    switch (waiting._kind) {
      case _ReelWaitingKind.ellipsis:
        final base = options ?? _tickWaitingDefaults;
        return startProgress(
          text,
          frames: <String>[
            for (var i = 0; i <= waiting.dots; i++) '$text${waiting.dot * i}',
          ],
          interval: waiting.step ?? _steadyStep(base),
          options: base,
        );
      case _ReelWaitingKind.wave:
        final base = options ?? _waveWaitingDefaults;
        final glyphCount = math.max(1, text.characters.length);
        final sweepMs = (glyphCount - 1) * base.stagger.inMilliseconds +
            base.exitOffset.inMilliseconds +
            (base.duration.inMilliseconds * (1 + base.bounce * 0.45)).round() +
            (base.color != null || base.colorBuilder != null
                ? base.colorFade.inMilliseconds
                : 0) +
            120;
        return startProgress(
          text,
          interval: Duration(milliseconds: sweepMs) + waiting.rest,
          animateUnchanged: true,
          options: base,
        );
      case _ReelWaitingKind.frames:
        final base = options ?? _tickWaitingDefaults;
        return startProgress(
          text,
          frames: waiting.frames,
          interval: waiting.step ?? _steadyStep(base),
          options: base,
        );
      case _ReelWaitingKind.builder:
        final base = options ?? _tickWaitingDefaults;
        final frame = waiting.frameBuilder!;
        return _startFrameLoop(
          initial: frame(text, 0),
          frameAt: (tick) => frame(text, tick),
          interval: waiting.step ?? _steadyStep(base),
          options: base.copyWith(interrupt: false),
        );
      case _ReelWaitingKind.scramble:
        final base = options ?? _tickWaitingDefaults;
        return _startFrameLoop(
          initial: text,
          frameAt: (tick) => _scrambleFrame(text, tick, waiting),
          interval: waiting.step ?? _steadyStep(base),
          options: base.copyWith(interrupt: false),
        );
    }
  }

  /// Runs [operation] while showing a waiting label, then emits success/failure.
  ///
  /// The operation is invoked after the waiting loop starts. On success the
  /// returned value is forwarded and [success] is emitted. On failure [failure]
  /// is emitted and the original error is rethrown.
  Future<T> runWhile<T>(
    FutureOr<T> Function() operation, {
    required String waiting,
    required String success,
    required String failure,
    ReelWaiting waitingPreset = const ReelWaiting.ellipsis(),
    ReelTextOptions? waitingOptions,
    ReelTextOptions? successOptions,
    ReelTextOptions? failureOptions,
  }) async {
    final handle = startWaiting(
      waiting,
      waiting: waitingPreset,
      options: waitingOptions,
    );
    try {
      final result = await operation();
      handle.complete(success, options: successOptions);
      return result;
    } catch (_) {
      handle.fail(failure, options: failureOptions);
      rethrow;
    }
  }

  /// A frame cadence that lets one glyph roll fully finish — including its
  /// bounce variation, exit offset, and color fade — plus a short rest, so
  /// ticks land on a steady beat instead of queueing behind in-flight rolls.
  static Duration _steadyStep(ReelTextOptions options) {
    final rollMs =
        (options.duration.inMilliseconds * (1 + options.bounce * 0.45)).round();
    final fadeMs = options.color != null || options.colorBuilder != null
        ? options.colorFade.inMilliseconds
        : 0;
    return Duration(
      milliseconds: rollMs + options.exitOffset.inMilliseconds + fadeMs + 160,
    );
  }

  static String _scrambleFrame(String text, int tick, ReelWaiting waiting) {
    if (tick % waiting.holdEvery == 0) {
      return text;
    }

    final glyphs = text.characters.toList();
    if (glyphs.isEmpty) {
      return text;
    }
    final firstMutable = math.min(waiting.protectedPrefix, glyphs.length);
    if (firstMutable == glyphs.length) {
      return text;
    }

    final alphabet = waiting.alphabet.characters.toList();
    final mutableIndexes = <int>[
      for (var i = firstMutable; i < glyphs.length; i++) i,
    ];
    final random = math.Random(tick * 9973 + glyphs.length * 37);
    mutableIndexes.shuffle(random);

    for (final index in mutableIndexes.take(waiting.changedGlyphs)) {
      var next = alphabet[random.nextInt(alphabet.length)];
      if (alphabet.length > 1 && next == glyphs[index]) {
        next = alphabet[(alphabet.indexOf(next) + 1) % alphabet.length];
      }
      glyphs[index] = next;
    }
    return glyphs.join();
  }

  ReelTextProgress _startFrameLoop({
    required String initial,
    required String Function(int tick) frameAt,
    required Duration interval,
    required ReelTextOptions options,
  }) {
    _cancelFlash();
    _cancelProgress();

    final epoch = ++_progressEpoch;
    var tick = 0;

    _emit(initial, options, force: true);
    _progressTimer = Timer.periodic(interval, (_) {
      if (epoch != _progressEpoch) {
        return;
      }
      tick++;
      _emit(frameAt(tick), options, force: true);
    });

    return ReelTextProgress._(this, epoch);
  }

  void _completeProgress(int epoch, String text, {ReelTextOptions? options}) {
    if (!_isProgressActive(epoch)) {
      return;
    }
    _cancelProgress();
    _emit(text, options);
  }

  void _cancelProgressHandle(
    int epoch, {
    String? text,
    ReelTextOptions? options,
  }) {
    if (!_isProgressActive(epoch)) {
      return;
    }
    _cancelProgress();
    if (text != null) {
      _emit(text, options);
    }
  }

  bool _isProgressActive(int epoch) {
    return _progressTimer != null && _progressEpoch == epoch;
  }

  void _cancelFlash() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _restingText = null;
  }

  void _cancelProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _progressEpoch++;
  }

  void _emit(String text, ReelTextOptions? options, {bool force = false}) {
    _value = text;
    _command = _ReelTextCommand(text, options, force: force);
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelFlash();
    _cancelProgress();
    super.dispose();
  }
}

/// Handle returned by [ReelTextController.startProgress].
///
/// Keep the handle for the async operation that owns the in-progress label and
/// resolve it with [complete] or [fail]. Calling any method after the handle is
/// no longer active is a no-op.
class ReelTextProgress {
  const ReelTextProgress._(this._controller, this._epoch);

  final ReelTextController _controller;
  final int _epoch;

  /// Whether this handle still owns the controller progress loop.
  bool get isActive => _controller._isProgressActive(_epoch);

  /// Stops the progress loop and rolls to [text].
  void complete(String text, {ReelTextOptions? options}) {
    _controller._completeProgress(_epoch, text, options: options);
  }

  /// Stops the progress loop and rolls to an error [text].
  void fail(String text, {ReelTextOptions? options}) {
    complete(text, options: options);
  }

  /// Stops the progress loop. When [text] is provided, it is emitted as the next
  /// resting label.
  void cancel({String? text, ReelTextOptions? options}) {
    _controller._cancelProgressHandle(_epoch, text: text, options: options);
  }
}

class _ReelTextCommand {
  const _ReelTextCommand(this.text, this.options, {this.force = false});

  final String text;
  final ReelTextOptions? options;
  final bool force;
}
