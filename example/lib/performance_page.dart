import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:reel_text/reel_text.dart';

import 'studio.dart';

const _kPerformanceCueHold = Duration(milliseconds: 1450);
const _kPerformanceRollDuration = Duration(milliseconds: 560);
const _kPerformanceRollStagger = Duration(milliseconds: 38);
const _kPerformanceRollBounce = 0.12;
const _kPerformanceProfileLog = bool.fromEnvironment(
  'REEL_TEXT_EXAMPLE_PROFILE_LOG',
);

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key, required this.active});

  final bool active;

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  Timer? _timer;
  Timer? _profileLogTimer;
  final _profileTimings = <FrameTiming>[];
  var _profileTimingsAttached = false;
  var _phase = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _start();
    }
  }

  @override
  void didUpdateWidget(covariant PerformancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) {
      return;
    }
    if (widget.active) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
      _stopProfileLog();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopProfileLog();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_kPerformanceCueHold, (_) {
      if (mounted && widget.active) {
        setState(() => _phase = !_phase);
      }
    });
    _startProfileLog();
  }

  void _startProfileLog() {
    if (!_kPerformanceProfileLog || _profileTimingsAttached) {
      return;
    }
    _profileTimingsAttached = true;
    SchedulerBinding.instance.addTimingsCallback(_handleProfileTimings);
    _profileLogTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _logProfileTimings(),
    );
  }

  void _stopProfileLog() {
    if (!_profileTimingsAttached) {
      return;
    }
    _logProfileTimings();
    _profileLogTimer?.cancel();
    _profileLogTimer = null;
    SchedulerBinding.instance.removeTimingsCallback(_handleProfileTimings);
    _profileTimingsAttached = false;
    _profileTimings.clear();
  }

  void _handleProfileTimings(List<FrameTiming> timings) {
    if (widget.active) {
      _profileTimings.addAll(timings);
    }
  }

  void _logProfileTimings() {
    final timings = List<FrameTiming>.of(_profileTimings);
    _profileTimings.clear();
    if (timings.isEmpty) {
      return;
    }

    double average(Iterable<Duration> durations) {
      final micros = durations.map((duration) => duration.inMicroseconds);
      return micros.reduce((a, b) => a + b) / timings.length / 1000;
    }

    final buildAverage = average(timings.map((timing) => timing.buildDuration));
    final rasterAverage = average(
      timings.map((timing) => timing.rasterDuration),
    );
    final totalAverage = average(timings.map((timing) => timing.totalSpan));
    final worstTotal =
        timings.fold<int>(
          0,
          (maxMicros, timing) =>
              math.max(maxMicros, timing.totalSpan.inMicroseconds).toInt(),
        ) /
        1000;
    final overBudget = timings
        .where((timing) => timing.totalSpan > const Duration(milliseconds: 16))
        .length;

    debugPrint(
      'PerformancePage frames=${timings.length} '
      'build_avg=${buildAverage.toStringAsFixed(2)}ms '
      'raster_avg=${rasterAverage.toStringAsFixed(2)}ms '
      'total_avg=${totalAverage.toStringAsFixed(2)}ms '
      'worst_total=${worstTotal.toStringAsFixed(2)}ms '
      'over_16ms=$overBudget',
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        key: const ValueKey('performance_scene'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final compact = width < 720;
            final columns = math.max(5, (width / (compact ? 82 : 126)).ceil());
            final rows = math.max(8, (height / (compact ? 52 : 64)).ceil());
            return Stack(
              fit: StackFit.expand,
              children: [
                const _PerformanceBackdrop(),
                _PerformanceCheckerboard(
                  phase: _phase,
                  rows: rows,
                  columns: columns,
                  compact: compact,
                ),
                const _PerformanceEdgeFade(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PerformanceBackdrop extends StatelessWidget {
  const _PerformanceBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('performance_backdrop'),
      decoration: BoxDecoration(color: _performanceBackground),
    );
  }
}

Color get _performanceBackground =>
    Studio.isLight ? const Color(0xfff7fbff) : const Color(0xff030711);

Color get _performanceText =>
    Studio.isLight ? const Color(0xff15243a) : Colors.white;

class _PerformanceCheckerboard extends StatelessWidget {
  const _PerformanceCheckerboard({
    required this.phase,
    required this.rows,
    required this.columns,
    required this.compact,
  });

  final bool phase;
  final int rows;
  final int columns;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('performance_checkerboard'),
      children: [
        for (var row = 0; row < rows; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: _PerformanceTile(
                      index: row * columns + column,
                      reversed: (row + column).isOdd,
                      phase: phase,
                      compact: compact,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile({
    required this.index,
    required this.reversed,
    required this.phase,
    required this.compact,
  });

  final int index;
  final bool reversed;
  final bool phase;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showReel = reversed ? phase : !phase;
    final blue = Studio.sky;
    final label = showReel ? 'reel' : 'text';
    final labelColor = _performanceText;

    return ClipRect(
      key: ValueKey('performance_tile_clip_$index'),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.shrink(
                key: ValueKey(
                  showReel
                      ? 'performance_reel_tile_$index'
                      : 'performance_text_tile_$index',
                ),
              ),
              ReelText(
                label,
                key: ValueKey('performance_tile_$index'),
                options: ReelTextOptions(
                  direction: showReel
                      ? ReelTextDirection.up
                      : ReelTextDirection.down,
                  duration: _kPerformanceRollDuration,
                  stagger: _kPerformanceRollStagger,
                  bounce: _kPerformanceRollBounce,
                  colorBuilder: showReel ? chromatic(from: index * 19) : null,
                  color: showReel ? null : blue,
                ),
                style: Studio.display(
                  size: compact ? 28 : 38,
                  height: 1,
                  color: labelColor,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceEdgeFade extends StatelessWidget {
  const _PerformanceEdgeFade();

  @override
  Widget build(BuildContext context) {
    final fade = _performanceBackground;
    final screen = MediaQuery.sizeOf(context);
    final edge = math.min(240.0, math.max(148.0, screen.shortestSide * 0.36));
    return IgnorePointer(
      key: const ValueKey('performance_edge_fade'),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: edge,
            child: _EdgeFadeBand(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              color: fade,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: edge,
            child: _EdgeFadeBand(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              color: fade,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: edge,
            child: _EdgeFadeBand(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              color: fade,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: edge,
            child: _EdgeFadeBand(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              color: fade,
            ),
          ),
        ],
      ),
    );
  }
}

class _EdgeFadeBand extends StatelessWidget {
  const _EdgeFadeBand({
    required this.begin,
    required this.end,
    required this.color,
  });

  final Alignment begin;
  final Alignment end;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            color,
            color.withValues(alpha: 0.82),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.34, 1],
        ),
      ),
    );
  }
}
