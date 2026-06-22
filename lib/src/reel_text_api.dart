part of 'reel_text.dart';

/// Roll direction used by [ReelText].
enum ReelTextDirection {
  /// New glyphs enter from below and old glyphs leave upward.
  up,

  /// New glyphs enter from above and old glyphs leave downward.
  down,
}

/// Builds a color for one glyph.
typedef ReelTextColorBuilder = Color Function(int index, int total);

/// Options for a [ReelText] roll animation.
@immutable
class ReelTextOptions {
  /// Creates roll animation options.
  const ReelTextOptions({
    this.direction = ReelTextDirection.down,
    this.stagger = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 300),
    this.exitOffset = const Duration(milliseconds: 50),
    this.curve = const Cubic(0.34, 1.56, 0.64, 1),
    this.bounce = 0.6,
    this.color,
    this.colorBuilder,
    this.colorFade = const Duration(milliseconds: 280),
    this.skipUnchanged = true,
    this.interrupt = true,
  }) : assert(bounce >= 0);

  /// Roll direction.
  final ReelTextDirection direction;

  /// Delay between glyph starts.
  final Duration stagger;

  /// Per-glyph slide duration.
  final Duration duration;

  /// Delay before incoming glyphs chase outgoing glyphs.
  final Duration exitOffset;

  /// Slide curve.
  final Curve curve;

  /// Amount of deterministic per-glyph timing and tilt variation, and the
  /// depth of the settle overshoot rendered from springy [curve]s.
  final double bounce;

  /// Flat color used by incoming glyphs before fading back to the text color.
  final Color? color;

  /// Per-glyph color used by incoming glyphs before fading back.
  final ReelTextColorBuilder? colorBuilder;

  /// Duration of the color fade back to the inherited text color.
  final Duration colorFade;

  /// Keeps equal characters at the same index static.
  final bool skipUnchanged;

  /// Whether a new target snaps an in-flight roll to its target before starting.
  ///
  /// When false, the current roll finishes and only the latest pending target is
  /// played next. This is useful for spam-prone buttons.
  final bool interrupt;

  /// Returns a copy with selected fields changed.
  ReelTextOptions copyWith({
    ReelTextDirection? direction,
    Duration? stagger,
    Duration? duration,
    Duration? exitOffset,
    Curve? curve,
    double? bounce,
    Color? color,
    ReelTextColorBuilder? colorBuilder,
    bool clearColor = false,
    Duration? colorFade,
    bool? skipUnchanged,
    bool? interrupt,
  }) {
    return ReelTextOptions(
      direction: direction ?? this.direction,
      stagger: stagger ?? this.stagger,
      duration: duration ?? this.duration,
      exitOffset: exitOffset ?? this.exitOffset,
      curve: curve ?? this.curve,
      bounce: bounce ?? this.bounce,
      color: clearColor ? color : color ?? this.color,
      colorBuilder:
          clearColor ? colorBuilder : colorBuilder ?? this.colorBuilder,
      colorFade: colorFade ?? this.colorFade,
      skipUnchanged: skipUnchanged ?? this.skipUnchanged,
      interrupt: interrupt ?? this.interrupt,
    );
  }

  /// Returns options with roll direction flipped.
  ReelTextOptions reversed() {
    return copyWith(
      direction: direction == ReelTextDirection.up
          ? ReelTextDirection.down
          : ReelTextDirection.up,
    );
  }

  /// Returns options that use one incoming glyph [color].
  ReelTextOptions withColor(Color color) {
    return copyWith(clearColor: true, color: color);
  }

  /// Returns options that use a chromatic incoming glyph sweep.
  ReelTextOptions withChromatic({
    double from = 0,
    double spread = 320,
    double saturation = 0.92,
    double lightness = 0.60,
  }) {
    return copyWith(
      clearColor: true,
      colorBuilder: chromatic(
        from: from,
        spread: spread,
        saturation: saturation,
        lightness: lightness,
      ),
    );
  }

  /// Returns options with any incoming glyph color mode removed.
  ReelTextOptions withoutColor() {
    return copyWith(clearColor: true);
  }

  ReelTextOptions _merge(ReelTextOptions? other) => other ?? this;
}

/// Builds one waiting frame for [ReelWaiting.builder].
///
/// [text] is the base label passed to [ReelTextController.startWaiting] and
/// [tick] is the zero-based loop counter.
typedef ReelWaitingFrameBuilder = String Function(String text, int tick);

/// Builds per-value options for [ReelText.sequence].
typedef ReelTextSequenceOptionsBuilder = ReelTextOptions Function(
    int index, String value);

enum _ReelWaitingKind { ellipsis, wave, frames, builder, scramble }

/// A looping idle animation used by [ReelTextController.startWaiting].
///
/// Presets compile down to the same roll engine as regular text changes, so
/// they inherit direction, curve, stagger, and color from [ReelTextOptions].
@immutable
class ReelWaiting {
  /// Dots roll in one at a time after the label, then all roll away together:
  /// `Load` -> `Load.` -> `Load..` -> `Load...` -> `Load`.
  ///
  /// When [step] is omitted, the cadence is derived from the roll duration so
  /// every dot lands on a steady, metronome-like beat.
  const ReelWaiting.ellipsis({this.dots = 3, this.dot = '.', this.step})
      : assert(dots > 0),
        _kind = _ReelWaitingKind.ellipsis,
        rest = Duration.zero,
        frames = const <String>[],
        frameBuilder = null,
        alphabet = '',
        changedGlyphs = 0,
        protectedPrefix = 0,
        holdEvery = 0;

  /// The whole label stays readable and periodically "breathes": a single
  /// stagger wave of self-rolls sweeps across the glyphs, then the label
  /// rests for [rest] before the next sweep.
  ///
  /// Without explicit options the wave uses a calm, non-springy curve and
  /// almost no tilt so the loop reads as a ripple instead of a glitch.
  const ReelWaiting.wave({this.rest = const Duration(milliseconds: 1300)})
      : _kind = _ReelWaitingKind.wave,
        dots = 0,
        dot = '',
        step = null,
        frames = const <String>[],
        frameBuilder = null,
        alphabet = '',
        changedGlyphs = 0,
        protectedPrefix = 0,
        holdEvery = 0;

  /// Cycles through explicit [frames] every [step].
  const ReelWaiting.frames(this.frames, {this.step})
      : _kind = _ReelWaitingKind.frames,
        dots = 0,
        dot = '',
        rest = Duration.zero,
        frameBuilder = null,
        alphabet = '',
        changedGlyphs = 0,
        protectedPrefix = 0,
        holdEvery = 0;

  /// Generates each frame with [frameBuilder] every [step].
  const ReelWaiting.builder(
    ReelWaitingFrameBuilder this.frameBuilder, {
    this.step,
  })  : _kind = _ReelWaitingKind.builder,
        dots = 0,
        dot = '',
        rest = Duration.zero,
        frames = const <String>[],
        alphabet = '',
        changedGlyphs = 0,
        protectedPrefix = 0,
        holdEvery = 0;

  /// Scrambles a small suffix of the readable label between held frames.
  ///
  /// [protectedPrefix] keeps leading grapheme clusters unchanged, [changedGlyphs]
  /// controls how many later clusters change per tick, and every [holdEvery]th
  /// frame returns the original [ReelTextController.startWaiting] text.
  const ReelWaiting.scramble({
    this.alphabet = 'abcdefghijklmnopqrstuvwxyz',
    this.changedGlyphs = 2,
    this.protectedPrefix = 0,
    this.holdEvery = 4,
    this.step,
  })  : assert(alphabet.length > 0),
        assert(changedGlyphs > 0),
        assert(protectedPrefix >= 0),
        assert(holdEvery > 0),
        _kind = _ReelWaitingKind.scramble,
        dots = 0,
        dot = '',
        rest = Duration.zero,
        frames = const <String>[],
        frameBuilder = null;

  final _ReelWaitingKind _kind;

  /// Maximum number of trailing dots for [ReelWaiting.ellipsis].
  final int dots;

  /// Dot glyph for [ReelWaiting.ellipsis].
  final String dot;

  /// Interval between frames for [ellipsis], [frames], and [builder].
  ///
  /// When null, a steady cadence is derived from the effective roll duration.
  final Duration? step;

  /// Quiet pause between sweeps for [ReelWaiting.wave].
  final Duration rest;

  /// Explicit frames for [ReelWaiting.frames].
  final List<String> frames;

  /// Frame generator for [ReelWaiting.builder].
  final ReelWaitingFrameBuilder? frameBuilder;

  /// Candidate glyphs used by [ReelWaiting.scramble].
  final String alphabet;

  /// Number of glyphs changed on each [ReelWaiting.scramble] tick.
  final int changedGlyphs;

  /// Leading glyph count left readable by [ReelWaiting.scramble].
  final int protectedPrefix;

  /// How often [ReelWaiting.scramble] emits the original readable label.
  final int holdEvery;
}

/// Options for [ReelTextController.flash].
@immutable
class ReelTextFlashOptions {
  /// Creates flash options.
  const ReelTextFlashOptions({
    this.revertAfter = const Duration(milliseconds: 1400),
    this.enter,
    this.exit,
  });

  /// How long the flash text remains before rolling back.
  final Duration revertAfter;

  /// Options for rolling the flash text in.
  final ReelTextOptions? enter;

  /// Options for rolling the original text back in.
  final ReelTextOptions? exit;
}

/// Returns a per-character rainbow color sweep.
ReelTextColorBuilder chromatic({
  double from = 0,
  double spread = 320,
  double saturation = 0.92,
  double lightness = 0.60,
}) {
  return (index, total) {
    final t = total <= 1 ? 0.0 : index / (total - 1);
    final hue = (from + t * spread) % 360;
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  };
}
