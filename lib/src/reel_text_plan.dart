part of 'reel_text.dart';

class _RollPlan {
  const _RollPlan({
    required this.fromText,
    required this.toText,
    required this.slots,
    required this.totalDuration,
  });

  final String fromText;
  final String toText;
  final List<_SlotPlan> slots;
  final Duration totalDuration;

  bool get hasMotion => slots.any((slot) => slot.changed);

  static _RollPlan create({
    required String fromText,
    required String toText,
    required ReelTextOptions options,
    List<int>? fromVisualOrder,
    List<int>? toVisualOrder,
    bool alignVisualOrderFromEnd = false,
  }) {
    final fromChars = fromText.characters.toList();
    final toChars = toText.characters.toList();
    final fromOrder =
        fromVisualOrder ?? [for (var i = 0; i < fromChars.length; i++) i];
    final toOrder =
        toVisualOrder ?? [for (var i = 0; i < toChars.length; i++) i];
    final maxLen = math.max(fromOrder.length, toOrder.length);
    var maxEndMs = 1;
    // The stagger cascade runs across *changed* slots only, so a diff that
    // touches just the tail (counters, ellipsis dots) starts instantly instead
    // of inheriting dead delay from untouched leading glyphs.
    var changeOrder = 0;
    final slots = <_SlotPlan>[];

    for (var i = 0; i < maxLen; i++) {
      final fromOrderIndex =
          alignVisualOrderFromEnd ? i - (maxLen - fromOrder.length) : i;
      final toOrderIndex =
          alignVisualOrderFromEnd ? i - (maxLen - toOrder.length) : i;
      final fromIndex = fromOrderIndex >= 0 && fromOrderIndex < fromOrder.length
          ? fromOrder[fromOrderIndex]
          : -1;
      final toIndex = toOrderIndex >= 0 && toOrderIndex < toOrder.length
          ? toOrder[toOrderIndex]
          : -1;
      final from = fromIndex >= 0 ? fromChars[fromIndex] : '';
      final to = toIndex >= 0 ? toChars[toIndex] : '';
      final unchanged = from == to && (options.skipUnchanged || from.isEmpty);
      final isTail = to.isEmpty;
      final durationMs = math.max(
        1,
        (options.duration.inMilliseconds *
                (isTail ? 0.75 : 1.0) *
                (1 + options.bounce * 0.45 * _wobble(i, 1)))
            .round(),
      );
      // Removed tail slots cascade faster so shrinking feels like one motion.
      final staggerIndex = isTail ? changeOrder * 0.5 : changeOrder.toDouble();
      final baseMs = unchanged
          ? 0
          : math.max(
              0,
              (staggerIndex *
                      options.stagger.inMilliseconds *
                      (1 + options.bounce * 0.25 * _wobble(i, 2)))
                  .round(),
            );
      // An incoming glyph only waits for exitOffset when it has to chase an
      // outgoing one; an empty slot fills immediately.
      final exitOffsetMs = from.isEmpty ? 0 : options.exitOffset.inMilliseconds;
      final color = options.colorBuilder?.call(i, maxLen) ?? options.color;
      final endMs = baseMs +
          exitOffsetMs +
          durationMs +
          (color == null ? 0 : options.colorFade.inMilliseconds);
      if (!unchanged) {
        changeOrder++;
        maxEndMs = math.max(maxEndMs, endMs + 80);
      }
      slots.add(
        _SlotPlan(
          index: i,
          fromIndex: fromIndex,
          toIndex: toIndex,
          from: from,
          to: to,
          changed: !unchanged,
          baseMs: baseMs,
          durationMs: durationMs,
          exitOffsetMs: exitOffsetMs,
          colorFadeMs: options.colorFade.inMilliseconds,
          direction: options.direction,
          curve: options.curve,
          color: color,
          tiltRadians: options.bounce * 5 * math.pi / 180 * _wobble(i, 3),
          // How much of the curve's overshoot is rendered: bounce deepens the
          // settle bounce, bounce 0 keeps a whisper of it.
          overshoot: 0.6 + options.bounce * 0.7,
        ),
      );
    }

    return _RollPlan(
      fromText: fromText,
      toText: toText,
      slots: slots,
      totalDuration: Duration(milliseconds: maxEndMs),
    );
  }
}

class _SlotPlan {
  const _SlotPlan({
    required this.index,
    required int fromIndex,
    required int toIndex,
    required this.from,
    required this.to,
    required this.changed,
    required this.baseMs,
    required this.durationMs,
    required this.exitOffsetMs,
    required this.colorFadeMs,
    required this.direction,
    required this.curve,
    required this.color,
    required this.tiltRadians,
    required this.overshoot,
  })  : _fromIndex = fromIndex,
        _toIndex = toIndex;

  final int index;
  // Nullable only for hot reload: slots created before these fields existed
  // should keep rendering by falling back to the original logical index.
  final int? _fromIndex;
  final int? _toIndex;
  final String from;
  final String to;
  final bool changed;
  final int baseMs;
  final int durationMs;
  final int exitOffsetMs;
  final int colorFadeMs;
  final ReelTextDirection direction;
  final Curve curve;
  final Color? color;
  final double tiltRadians;
  final double overshoot;

  int get fromIndex => _fromIndex ?? index;

  int get toIndex => _toIndex ?? index;

  double outT(double nowMs) => _curved(nowMs, baseMs, durationMs);

  double outOpacity(double nowMs) {
    final t = outT(nowMs);
    return 1 - _smoothstep((t - 0.78) / 0.22);
  }

  double inT(double nowMs) => _curved(nowMs, baseMs + exitOffsetMs, durationMs);

  double widthT(double nowMs) {
    if (to.isEmpty) {
      return _linear(
        nowMs,
        baseMs + (durationMs * 0.55).round(),
        math.max(140, (durationMs * 0.6).round()),
      );
    }
    if (from.isEmpty) {
      return _linear(nowMs, baseMs, math.max(140, (durationMs * 0.45).round()));
    }
    return _linear(nowMs, baseMs, durationMs);
  }

  double colorT(double nowMs) {
    if (color == null || colorFadeMs <= 0) {
      return 1;
    }
    return _linear(nowMs, baseMs + exitOffsetMs + durationMs, colorFadeMs);
  }

  double outY(double nowMs, double height) {
    final sign = direction == ReelTextDirection.down ? 1.0 : -1.0;
    return sign * height * outT(nowMs);
  }

  double inY(double nowMs, double height) {
    final sign = direction == ReelTextDirection.down ? -1.0 : 1.0;
    return sign * height * (1 - inT(nowMs));
  }

  double _curved(double nowMs, int startMs, int spanMs) {
    final value = curve.transform(_linear(nowMs, startMs, spanMs));
    // Let springy curves overshoot past the resting line instead of clamping
    // them flat — this is what makes the glyph visibly settle with a bounce.
    // The depth is scaled by [overshoot] (driven by ReelTextOptions.bounce).
    if (value > 1) {
      return 1 + (value - 1) * overshoot;
    }
    if (value < 0) {
      return value * overshoot;
    }
    return value;
  }
}

double _linear(double nowMs, int startMs, int spanMs) {
  if (spanMs <= 0) {
    return nowMs >= startMs ? 1 : 0;
  }
  return ((nowMs - startMs) / spanMs).clamp(0.0, 1.0);
}

double _smoothstep(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _wobble(int i, int salt) {
  final n = math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return (n - n.floor()) * 2 - 1;
}
