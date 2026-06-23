part of 'reel_text.dart';

class _SlotBuildState {
  _SlotBuildState({required this.totalSlots});

  final int totalSlots;
  final slots = <_SlotPlan>[];
  var maxEndMs = 1;
  var changeOrder = 0;
}

void _appendSlot({
  required _SlotBuildState state,
  required ReelTextOptions options,
  required _SlotEndpoint? from,
  required _SlotEndpoint? to,
  bool forceUnchanged = false,
}) {
  final index = state.slots.length;
  final unchanged =
      forceUnchanged || _slotEndpointsUnchanged(from, to, options);
  final isTail = to == null;
  final durationMs = math.max(
    1,
    (options.duration.inMilliseconds *
            (isTail ? 0.75 : 1.0) *
            (1 + options.bounce * 0.45 * _wobble(index, 1)))
        .round(),
  );
  final staggerIndex =
      isTail ? state.changeOrder * 0.5 : state.changeOrder.toDouble();
  final baseMs = unchanged
      ? 0
      : math.max(
          0,
          (staggerIndex *
                  options.stagger.inMilliseconds *
                  (1 + options.bounce * 0.25 * _wobble(index, 2)))
              .round(),
        );
  final exitOffsetMs = from == null ? 0 : options.exitOffset.inMilliseconds;
  final color =
      options.colorBuilder?.call(index, state.totalSlots) ?? options.color;
  final endMs = baseMs +
      exitOffsetMs +
      durationMs +
      (color == null ? 0 : options.colorFade.inMilliseconds);
  if (!unchanged) {
    state.changeOrder++;
    state.maxEndMs = math.max(state.maxEndMs, endMs + 80);
  }
  state.slots.add(
    _SlotPlan(
      index: index,
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
      tiltRadians: options.bounce * 5 * math.pi / 180 * _wobble(index, 3),
      overshoot: 0.6 + options.bounce * 0.7,
    ),
  );
}

bool _slotEndpointsUnchanged(
  _SlotEndpoint? from,
  _SlotEndpoint? to,
  ReelTextOptions options,
) {
  final fromText = from?.text ?? '';
  final toText = to?.text ?? '';
  if (fromText != toText) {
    return false;
  }
  if (!options.skipUnchanged && from != null) {
    return false;
  }
  if (from == null || to == null) {
    return true;
  }
  return _tokensEquivalentForUnchanged(from.token, to.token);
}

bool _tokensEquivalentForUnchanged(
  _ReelTextToken from,
  _ReelTextToken to,
) {
  if (from.isWidget || to.isWidget) {
    if (!from.isWidget || !to.isWidget) {
      return false;
    }
    return _widgetSpansEquivalentForUnchanged(
      from.widgetSpan!,
      to.widgetSpan!,
    );
  }
  return from.text == to.text;
}

class _SlotEndpoint {
  const _SlotEndpoint({
    required this.index,
    required this.token,
  });

  final int index;
  final _ReelTextToken token;

  String get text => token.text;
}

class _SlotPlan {
  const _SlotPlan({
    required this.index,
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
  });

  final int index;
  final _SlotEndpoint? from;
  final _SlotEndpoint? to;
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

  double outT(double nowMs) => _curved(nowMs, baseMs, durationMs);

  double outOpacity(double nowMs) {
    final t = outT(nowMs);
    return 1 - _smoothstep((t - 0.78) / 0.22);
  }

  double inT(double nowMs) => _curved(nowMs, baseMs + exitOffsetMs, durationMs);

  double widthT(double nowMs) {
    if (to == null) {
      return _linear(
        nowMs,
        baseMs + (durationMs * 0.55).round(),
        math.max(140, (durationMs * 0.6).round()),
      );
    }
    if (from == null) {
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
