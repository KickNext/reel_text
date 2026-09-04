part of 'reel_text.dart';

class _SettledReelText extends StatelessWidget {
  const _SettledReelText({
    super.key,
    required this.run,
    required this.layout,
    required this.surfaceKey,
  });

  final _MeasuredReelTextRun run;
  final _ReelTextLayoutContext layout;

  /// Global key shared with [_RollingReelText] so the same render surface
  /// (and its prepared-face cache) is reparented instead of recreated when a
  /// roll starts or finishes.
  final Key surfaceKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('reel_text_settled_glyphs'),
      child: _ReelTextSurface(
        key: surfaceKey,
        data: _ReelTextSurfaceData.settled(run: run, layout: layout),
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
      ),
    );
  }
}

class _RollingReelText extends StatelessWidget {
  const _RollingReelText({
    required this.plan,
    required this.fromRun,
    required this.toRun,
    required this.animation,
    required this.textAlign,
    required this.layout,
    required this.defaultTextColor,
    required this.surfaceKey,
  });

  final _RollPlan plan;
  final _MeasuredReelTextRun fromRun;
  final _MeasuredReelTextRun toRun;
  final Animation<double> animation;
  final TextAlign textAlign;
  final _ReelTextLayoutContext layout;
  final Color defaultTextColor;
  final Key surfaceKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('reel_text_rolling'),
      child: KeyedSubtree(
        key: const ValueKey('reel_text_rolling_text_slot'),
        child: _ReelTextSurface(
          key: surfaceKey,
          data: _ReelTextSurfaceData.rolling(
            plan: plan,
            fromRun: fromRun,
            toRun: toRun,
            animation: animation,
            textAlign: textAlign,
            layout: layout,
            defaultTextColor: defaultTextColor,
          ),
          textScaler:
              MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        ),
      ),
    );
  }
}
