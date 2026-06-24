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
const _kPerformanceMinTileCount = 4.0;
const _kPerformanceMaxDensity = 3.0;
const _kPerformanceTileGap = 10.0;
const _kPerformanceCompactTileGap = 8.0;
const _kPerformanceStressDescription =
    'This is a stress test, not a normal usage example. Each ReelText '
    'in the grid is independent and animates separately, so high density '
    'can visibly slow down.';
const _kPerformanceProfileLog = bool.fromEnvironment(
  'REEL_TEXT_EXAMPLE_PROFILE_LOG',
);

class PerformancePage extends StatefulWidget {
  const PerformancePage({
    super.key,
    required this.active,
    required this.tileTarget,
    required this.onTileTargetChanged,
  });

  final bool active;
  final double tileTarget;
  final ValueChanged<double> onTileTargetChanged;

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
            final baseTileWidth = compact ? 82.0 : 126.0;
            final baseTileHeight = compact ? 52.0 : 64.0;
            final maxColumns = math.max(
              5,
              (width / (baseTileWidth / _kPerformanceMaxDensity)).ceil(),
            );
            final maxRows = math.max(
              8,
              (height / (baseTileHeight / _kPerformanceMaxDensity)).ceil(),
            );
            final maxTileCount = math
                .max(_kPerformanceMinTileCount.toInt(), maxRows * maxColumns)
                .toDouble();
            final tileTarget = widget.tileTarget
                .clamp(_kPerformanceMinTileCount, maxTileCount)
                .toDouble();
            final grid = _PerformanceGridShape.fromTarget(
              target: tileTarget.round(),
              maxRows: maxRows,
              maxColumns: maxColumns,
              width: width,
              height: height,
            );
            final controlWidth = math.min(360.0, math.max(0.0, width - 40.0));
            final controlLeft = math.max(0.0, (width - controlWidth) / 2);
            final controlBottom = MediaQuery.paddingOf(context).bottom + 22;
            return Stack(
              fit: StackFit.expand,
              children: [
                const _PerformanceBackdrop(),
                _PerformanceCheckerboard(
                  phase: _phase,
                  rows: grid.rows,
                  columns: grid.columns,
                  compact: compact,
                ),
                const _PerformanceEdgeFade(),
                Positioned(
                  left: controlLeft,
                  bottom: controlBottom,
                  width: controlWidth,
                  child: _PerformanceDensityControl(
                    tileTarget: tileTarget,
                    maxTileCount: maxTileCount,
                    tileCount: grid.tileCount,
                    onChanged: widget.onTileTargetChanged,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PerformanceGridShape {
  const _PerformanceGridShape({required this.rows, required this.columns});

  final int rows;
  final int columns;

  int get tileCount => rows * columns;

  static _PerformanceGridShape fromTarget({
    required int target,
    required int maxRows,
    required int maxColumns,
    required double width,
    required double height,
  }) {
    final maxTiles = maxRows * maxColumns;
    final requested = target.clamp(_kPerformanceMinTileCount.toInt(), maxTiles);
    if (requested >= maxTiles) {
      return _PerformanceGridShape(rows: maxRows, columns: maxColumns);
    }
    if (requested <= _kPerformanceMinTileCount) {
      return const _PerformanceGridShape(rows: 2, columns: 2);
    }

    final aspect = height <= 0 ? 1.0 : width / height;
    var columns = math.sqrt(requested * aspect).ceil().clamp(2, maxColumns);
    var rows = (requested / columns).ceil().clamp(2, maxRows);

    if (rows == maxRows && rows * columns < requested) {
      columns = (requested / rows).ceil().clamp(2, maxColumns);
    }

    while (columns > 2 && rows * (columns - 1) >= requested) {
      columns--;
    }
    while (rows > 2 && (rows - 1) * columns >= requested) {
      rows--;
    }

    return _PerformanceGridShape(rows: rows, columns: columns);
  }
}

class _PerformanceDensityControl extends StatelessWidget {
  const _PerformanceDensityControl({
    required this.tileTarget,
    required this.maxTileCount,
    required this.tileCount,
    required this.onChanged,
  });

  final double tileTarget;
  final double maxTileCount;
  final int tileCount;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final background = Studio.isLight
        ? Colors.white.withValues(alpha: 0.82)
        : const Color(0xff07101f).withValues(alpha: 0.72);
    final border = Studio.isLight
        ? const Color(0xffc7d7ef).withValues(alpha: 0.68)
        : Colors.white.withValues(alpha: 0.12);
    final countLabel = '$tileCount tiles';

    return SizedBox(
      key: const ValueKey('performance_density_layer'),
      child: DecoratedBox(
        key: const ValueKey('performance_density_control'),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _kPerformanceStressDescription,
                key: const ValueKey('performance_stress_description'),
                style: Studio.body(
                  size: 11.5,
                  height: 1.32,
                  color: _performanceText.withValues(alpha: 0.82),
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      countLabel,
                      key: const ValueKey('performance_density_count'),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Studio.mono(
                        size: 12,
                        color: _performanceText,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('performance_density_slider'),
                      min: _kPerformanceMinTileCount,
                      max: maxTileCount,
                      value: tileTarget,
                      label: countLabel,
                      semanticFormatterCallback: (value) =>
                          '${value.round()} independent ReelText widgets',
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final gap = compact ? _kPerformanceCompactTileGap : _kPerformanceTileGap;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gap / 2, vertical: gap / 2),
      child: ClipRect(
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
