import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reel_text/reel_text.dart';

import 'studio.dart';

const _packagePubspecAsset = 'packages/reel_text/pubspec.yaml';

Future<String> _packageVersionLabel() {
  return _loadPackageVersionLabel();
}

Future<String> _loadPackageVersionLabel() async {
  try {
    final pubspec = await rootBundle.loadString(_packagePubspecAsset);
    final version = RegExp(
      r'^version:\s*([^\s]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    return version == null || version.isEmpty ? 'v?' : 'v$version';
  } on Object {
    return 'v?';
  }
}

/// Landing page. The hero is a self-running, choreographed presentation that
/// walks through the package's core capabilities by changing one live line.
/// Below it is a compact workbench of real text-changing surfaces.
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.autoPlay = true, this.active = true});

  /// Auto-advance the hero acts. Disabled in tests for determinism.
  final bool autoPlay;

  /// False when the page is retained offscreen by the shell.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final compact = width < 900;
        final hPad = EdgeInsets.symmetric(horizontal: compact ? 16 : 40);

        Widget centered(Widget child) => Padding(
          padding: hPad,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: child,
            ),
          ),
        );

        return ListView(
          key: const ValueKey('home_scroll'),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Full-bleed scene — no card framing.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: HeroStage(
                  compact: compact,
                  viewportHeight: height,
                  autoPlay: autoPlay && active,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 0),
            centered(_HomeWorkbench(compact: compact, active: active)),
            SizedBox(height: compact ? 24 : 32),
            centered(const StudioFooter()),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Hero stage — the choreographed presentation
// ===========================================================================

const Duration _kCueFast = Duration(milliseconds: 1100);
const Duration _kCueMedium = Duration(milliseconds: 1450);
const Duration _kCueSlow = Duration(milliseconds: 1900);
const Duration _kCueFeature = Duration(milliseconds: 2300);
const Duration _kCueBrand = Duration(milliseconds: 2500);
const double _kHeroLineHeight = 1.50;
const double _kHeroLineHeightCompact = 1.36;

class HeroStage extends StatefulWidget {
  const HeroStage({
    super.key,
    required this.compact,
    required this.viewportHeight,
    this.autoPlay = true,
  });

  final bool compact;
  final double viewportHeight;
  final bool autoPlay;

  @override
  State<HeroStage> createState() => _HeroStageState();
}

class _HeroStageState extends State<HeroStage> with TickerProviderStateMixin {
  late final ReelTextController _line;
  late final AnimationController _cueProgress;
  late final AnimationController _actProgress;
  int _cueIndex = 0;
  int _cueEpoch = 0;

  @override
  void initState() {
    super.initState();
    _line = ReelTextController(initialText: '');
    _cueProgress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && widget.autoPlay && mounted) {
          _advanceCue();
        }
      });
    _actProgress = AnimationController(vsync: this);
    if (widget.autoPlay) {
      _startActProgress(_cueIndex);
      _startCueProgress(_cueAt(_cueIndex));
    }
  }

  @override
  void didUpdateWidget(covariant HeroStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay == widget.autoPlay) {
      return;
    }
    if (widget.autoPlay) {
      _startActProgress(_cueIndex);
      _startCueProgress(_cueAt(_cueIndex));
    } else {
      _cueProgress.stop();
      _cueProgress.value = 0;
      _actProgress.stop();
      _actProgress.value = 0;
    }
  }

  _HeroCue _cueAt(int index) {
    final cues = _buildHeroCues();
    return cues[index.clamp(0, cues.length - 1)];
  }

  int get _activeActIndex {
    final tag = _cueAt(_cueIndex).tag;
    final index = _buildActs().indexWhere((act) => act.tag == tag);
    return index < 0 ? 0 : index;
  }

  void _startCueProgress(_HeroCue cue) {
    _cueProgress
      ..duration = cue.hold
      ..forward(from: 0);
  }

  void _startActProgress(int cueIndex) {
    final cues = _buildHeroCues();
    if (cues.isEmpty) {
      return;
    }
    final safeIndex = cueIndex.clamp(0, cues.length - 1);
    final tag = cues[safeIndex].tag;
    var first = safeIndex;
    while (first > 0 && cues[first - 1].tag == tag) {
      first--;
    }
    var last = safeIndex;
    while (last + 1 < cues.length && cues[last + 1].tag == tag) {
      last++;
    }

    final total = _cueRangeHold(cues, first, last);
    final elapsed = _cueRangeHold(cues, first, safeIndex - 1);
    if (total <= Duration.zero) {
      _actProgress.value = 1;
      return;
    }
    _actProgress
      ..duration = total
      ..forward(from: elapsed.inMilliseconds / total.inMilliseconds);
  }

  void _advanceCue() {
    final cues = _buildHeroCues();
    final next = _cueIndex + 1 >= cues.length ? 1 : _cueIndex + 1;
    _goCue(next);
  }

  void _go(int next) {
    final acts = _buildActs();
    final cues = _buildHeroCues();
    final tag = acts[next].tag;
    final cueIndex = cues.indexWhere((cue) => cue.tag == tag);
    _goCue(cueIndex < 0 ? 0 : cueIndex);
  }

  void _goCue(int next) {
    if (!mounted || next == _cueIndex) return;
    final oldActIndex = _activeActIndex;
    setState(() => _cueIndex = next);
    final newActIndex = _activeActIndex;
    _cueProgress.stop();
    _cueProgress.value = 0;
    if (widget.autoPlay && newActIndex != oldActIndex) {
      _actProgress.stop();
      _startActProgress(next);
    }
    unawaited(_applyCue(_cueAt(next)));
  }

  Future<void> _applyCue(_HeroCue cue) async {
    final epoch = ++_cueEpoch;
    final text = cue.packageVersion ? await _packageVersionLabel() : cue.text;
    if (!mounted || epoch != _cueEpoch) {
      return;
    }
    _line.set(text, options: _cueOptions(cue));
    if (widget.autoPlay) {
      _startCueProgress(cue);
    }
  }

  @override
  void dispose() {
    _line.dispose();
    _cueProgress.dispose();
    _actProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final acts = _buildActs();
    final minHeight = compact
        ? 250.0
        : math.max(widget.viewportHeight * 0.32, 400.0);
    final activeAct = _activeActIndex;

    return SizedBox(
      key: const ValueKey('hero_stage'),
      height: minHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 64,
          compact ? 10 : 12,
          compact ? 20 : 64,
          compact ? 4 : 0,
        ),
        child: Column(
          children: [
            SizedBox(height: compact ? 4 : 0),
            SizedBox(
              key: const ValueKey('hero_act_view'),
              height: compact ? 150 : 300,
              child: ClipRect(
                key: const ValueKey('hero_line_clip'),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ReelText.controller(
                      key: const ValueKey('hero_brand_word'),
                      controller: _line,
                      style: _focalStyle(context).copyWith(
                        fontSize: compact ? 52 : 112,
                        height: compact
                            ? _kHeroLineHeightCompact
                            : _kHeroLineHeight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            _StageNav(
              acts: acts,
              index: activeAct,
              progress: _actProgress,
              compact: compact,
              onSelect: _go,
            ),
          ],
        ),
      ),
    );
  }
}

class _Act {
  const _Act({required this.tag, required this.accent});

  final String tag;
  final Color accent;
}

List<_Act> _buildActs() => [
  _Act(tag: 'INTRO', accent: Studio.primary),
  _Act(tag: 'LABELS', accent: Studio.info),
  _Act(tag: 'COUNTERS', accent: Studio.tone(Studio.violet)),
  _Act(tag: 'ASYNC', accent: Studio.primary),
  _Act(tag: 'INLINE', accent: Studio.danger),
];

class _HeroCue {
  const _HeroCue({
    required this.tag,
    required this.text,
    required this.accent,
    this.packageVersion = false,
    this.rainbow = false,
    this.direction = ReelTextDirection.up,
    this.hold = _kCueMedium,
  });

  final String tag;
  final String text;
  final Color accent;
  final bool packageVersion;
  final bool rainbow;
  final ReelTextDirection direction;
  final Duration hold;
}

List<_HeroCue> _buildHeroCues() => [
  _HeroCue(tag: 'INTRO', text: '', accent: Studio.primary, hold: _kCueFast),
  _HeroCue(
    tag: 'INTRO',
    text: 'reel_text',
    accent: Studio.primary,
    rainbow: true,
    direction: ReelTextDirection.up,
    hold: _kCueBrand,
  ),
  _HeroCue(
    tag: 'INTRO',
    text: '',
    accent: Studio.primary,
    packageVersion: true,
    direction: ReelTextDirection.down,
    hold: _kCueFeature,
  ),
  _HeroCue(
    tag: 'LABELS',
    text: 'Copy',
    accent: Studio.info,
    direction: ReelTextDirection.up,
    hold: _kCueMedium,
  ),
  _HeroCue(
    tag: 'LABELS',
    text: 'Copied',
    accent: Studio.success,
    direction: ReelTextDirection.up,
    hold: _kCueSlow,
  ),
  _HeroCue(
    tag: 'LABELS',
    text: 'Send',
    accent: Studio.info,
    direction: ReelTextDirection.down,
    hold: _kCueMedium,
  ),
  _HeroCue(
    tag: 'LABELS',
    text: 'Sent',
    accent: Studio.success,
    direction: ReelTextDirection.up,
    hold: _kCueSlow,
  ),
  _HeroCue(
    tag: 'COUNTERS',
    text: '1,024',
    accent: Studio.tone(Studio.violet),
    direction: ReelTextDirection.up,
    hold: _kCueMedium,
  ),
  _HeroCue(
    tag: 'COUNTERS',
    text: '1,025',
    accent: Studio.success,
    direction: ReelTextDirection.up,
    hold: _kCueFast,
  ),
  _HeroCue(
    tag: 'COUNTERS',
    text: '1,024',
    accent: Studio.danger,
    direction: ReelTextDirection.down,
    hold: _kCueSlow,
  ),
  _HeroCue(
    tag: 'ASYNC',
    text: 'Export',
    accent: Studio.warning,
    direction: ReelTextDirection.down,
    hold: _kCueFast,
  ),
  _HeroCue(
    tag: 'ASYNC',
    text: 'Exporting',
    accent: Studio.warning,
    direction: ReelTextDirection.up,
    hold: _kCueFeature,
  ),
  _HeroCue(
    tag: 'ASYNC',
    text: 'Exported',
    accent: Studio.success,
    direction: ReelTextDirection.down,
    hold: _kCueSlow,
  ),
  _HeroCue(
    tag: 'INLINE',
    text: 'please recieve',
    accent: Studio.danger,
    direction: ReelTextDirection.down,
    hold: _kCueSlow,
  ),
  _HeroCue(
    tag: 'INLINE',
    text: 'please receive',
    accent: Studio.success,
    direction: ReelTextDirection.up,
    hold: _kCueFeature,
  ),
];

Duration _cueRangeHold(List<_HeroCue> cues, int first, int last) {
  if (cues.isEmpty || last < first) {
    return Duration.zero;
  }
  final safeFirst = first.clamp(0, cues.length - 1);
  final safeLast = last.clamp(0, cues.length - 1);
  var total = Duration.zero;
  for (var i = safeFirst; i <= safeLast; i++) {
    total += cues[i].hold;
  }
  return total;
}

ReelTextOptions _cueOptions(_HeroCue cue) {
  return ReelTextOptions(
    direction: cue.direction,
    duration: const Duration(milliseconds: 560),
    stagger: const Duration(milliseconds: 38),
    bounce: 0.12,
    color: cue.rainbow ? null : cue.accent,
    colorBuilder: cue.rainbow ? Studio.chromaColor : null,
  );
}

/// Labelled, scrubbable progress nav along the bottom of the stage.
class _StageNav extends StatelessWidget {
  const _StageNav({
    required this.acts,
    required this.index,
    required this.progress,
    required this.compact,
    required this.onSelect,
  });

  final List<_Act> acts;
  final int index;
  final AnimationController progress;
  final bool compact;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Phones get fitted progress dots (labels overflow and hide the active
    // item); wide screens get the scrubbable labelled rail.
    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < acts.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _StageNavDot(
              key: ValueKey('stage_nav_${acts[i].tag.toLowerCase()}'),
              accent: acts[i].accent,
              active: i == index,
              progress: progress,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < acts.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          _StageNavItem(
            key: ValueKey('stage_nav_${acts[i].tag.toLowerCase()}'),
            act: acts[i],
            active: i == index,
            progress: progress,
            onTap: () => onSelect(i),
          ),
        ],
      ],
    );
  }
}

/// Compact progress dot: a small tappable dot that expands into a filling
/// track while its act is current.
class _StageNavDot extends StatelessWidget {
  const _StageNavDot({
    super.key,
    required this.accent,
    required this.active,
    required this.progress,
    required this.onTap,
  });

  final Color accent;
  final bool active;
  final AnimationController progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: active
            ? ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 30,
                  height: 6,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: Studio.border)),
                      AnimatedBuilder(
                        animation: progress,
                        builder: (context, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.value.clamp(0.0, 1.0),
                          child: ColoredBox(color: accent),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Studio.faint,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

class _StageNavItem extends StatelessWidget {
  const _StageNavItem({
    super.key,
    required this.act,
    required this.active,
    required this.progress,
    required this.onTap,
  });

  final _Act act;
  final bool active;
  final AnimationController progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? act.accent : Studio.faint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                act.tag,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Studio.mono(
                  size: 9.5,
                  color: color,
                  weight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: Studio.border)),
                      if (active)
                        AnimatedBuilder(
                          animation: progress,
                          builder: (context, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.value.clamp(0.0, 1.0),
                            child: ColoredBox(color: act.accent),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Focal animations (each self-running, cleans up on dispose)
// ===========================================================================

TextStyle _focalStyle(BuildContext context, {Color? color}) {
  final compact = MediaQuery.sizeOf(context).width < 900;
  return Studio.display(
    size: compact ? 64 : 128,
    color: color ?? Studio.text,
    height: 1.18,
    letterSpacing: 0,
  );
}

String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

// ===========================================================================
// Try-it strip — compact live, interactive examples
// ===========================================================================

class _HomeWorkbench extends StatelessWidget {
  const _HomeWorkbench({required this.compact, required this.active});

  final bool compact;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          key: const ValueKey('home_workbench_heading'),
          label: 'alive in the details',
          title: 'Make your app feel a little more alive.',
          subtitle:
              'ReelText brings smooth, tactile motion to the small text updates users notice every day.',
          centered: true,
        ),
        SizedBox(height: compact ? 20 : 28),
        Center(
          child: ConstrainedBox(
            key: const ValueKey('install_block_frame'),
            constraints: const BoxConstraints(maxWidth: 520),
            child: const _InstallBlock(),
          ),
        ),
        SizedBox(height: compact ? 18 : 22),
        _TryItStrip(compact: compact, active: active),
      ],
    );
  }
}

class _QuietPanel extends StatelessWidget {
  const _QuietPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Studio.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Studio.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _MarketRowData {
  _MarketRowData(this.symbol, this.price);

  final String symbol;
  double price;
  double deltaPct = 0;
  bool up = true;
}

class _LiveBoard extends StatefulWidget {
  const _LiveBoard({this.active = true});

  final bool active;

  @override
  State<_LiveBoard> createState() => _LiveBoardState();
}

class _LiveBoardState extends State<_LiveBoard> {
  final _random = math.Random(42);
  late final List<_MarketRowData> _rows;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _rows = [
      _MarketRowData('BTC', 67412.50),
      _MarketRowData('ETH', 3521.08),
      _MarketRowData('SOL', 142.77),
      _MarketRowData('LINK', 18.43),
    ];
    if (widget.active) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _LiveBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) {
      return;
    }
    if (widget.active) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(milliseconds: 2100), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      final touched = <int>{
        _random.nextInt(_rows.length),
        _random.nextInt(_rows.length),
      };
      for (final i in touched) {
        final row = _rows[i];
        final pct =
            (_random.nextDouble() * 1.4 + 0.05) * (_random.nextBool() ? 1 : -1);
        row.deltaPct = pct;
        row.up = pct >= 0;
        row.price = math.max(0.01, row.price * (1 + pct / 100));
      }
    });
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final dot = s.indexOf('.');
    final b = StringBuffer();
    for (var i = 0; i < dot; i++) {
      final rem = dot - i;
      b.write(s[i]);
      if (rem > 1 && rem % 3 == 1) {
        b.write(',');
      }
    }
    b.write(s.substring(dot));
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return _QuietPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ExampleTitle('Market table'),
          const SizedBox(height: 18),
          const _MarketHeader(),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Studio.border),
            _MarketRow(data: _rows[i], fmt: _fmt),
          ],
        ],
      ),
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader();

  @override
  Widget build(BuildContext context) {
    final style = Studio.mono(
      size: 10.5,
      color: Studio.faint,
      weight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    return Row(
      children: [
        SizedBox(width: 54, child: Text('ASSET', style: style)),
        Expanded(child: Text('PRICE', style: style)),
        SizedBox(
          width: 84,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('24H', style: style),
          ),
        ),
      ],
    );
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({required this.data, required this.fmt});

  final _MarketRowData data;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    final tone = data.deltaPct == 0
        ? Studio.muted
        : data.up
        ? Studio.success
        : Studio.danger;
    final options = ReelTextOptions(
      direction: data.up ? ReelTextDirection.up : ReelTextDirection.down,
      duration: const Duration(milliseconds: 320),
      stagger: const Duration(milliseconds: 26),
      exitOffset: const Duration(milliseconds: 38),
      bounce: 0.25,
      color: tone,
    );
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              data.symbol,
              style: Studio.mono(
                size: 12,
                color: Studio.muted,
                weight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: ReelText(
              '\$${fmt(data.price)}',
              options: options,
              style: Studio.mono(
                size: 21,
                color: Studio.text,
                weight: FontWeight.w700,
                height: 1.1,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Align(
              alignment: Alignment.centerRight,
              child: ReelText(
                data.deltaPct == 0
                    ? '--'
                    : '${data.up ? '+' : '-'}'
                          '${data.deltaPct.abs().toStringAsFixed(2)}%',
                options: options,
                style: Studio.mono(
                  size: 12,
                  color: tone,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TryItStrip extends StatelessWidget {
  const _TryItStrip({required this.compact, required this.active});

  final bool compact;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          _LiveBoard(active: active),
          const SizedBox(height: 12),
          const _CopyLabelCard(),
          const SizedBox(height: 12),
          const _LiveCounterCard(),
          const SizedBox(height: 12),
          const _StatusPillCard(),
          const SizedBox(height: 12),
          const _InlineMessageCard(),
          const SizedBox(height: 12),
          const _LiveAsyncCard(),
        ],
      );
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 13,
                child: KeyedSubtree(
                  key: const ValueKey('market_board_frame'),
                  child: _LiveBoard(active: active),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 8,
                child: Column(
                  key: const ValueKey('right_examples_stack'),
                  children: const [
                    Expanded(child: _CopyLabelCard()),
                    SizedBox(height: 14),
                    Expanded(child: _LiveCounterCard()),
                    SizedBox(height: 14),
                    Expanded(child: _StatusPillCard()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _InlineMessageCard()),
            SizedBox(width: 14),
            Expanded(child: _LiveAsyncCard()),
          ],
        ),
      ],
    );
  }
}

class _ExampleTitle extends StatelessWidget {
  const _ExampleTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return StudioCaption(label, color: Studio.faint);
  }
}

class _ExampleFrame extends StatelessWidget {
  const _ExampleFrame({
    required this.title,
    required this.child,
    this.panelKey,
  });

  final String title;
  final Widget child;
  final Key? panelKey;

  @override
  Widget build(BuildContext context) {
    return _QuietPanel(
      key: panelKey,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_ExampleTitle(title), const SizedBox(height: 16), child],
      ),
    );
  }
}

class _CopyLabelCard extends StatefulWidget {
  const _CopyLabelCard();

  @override
  State<_CopyLabelCard> createState() => _CopyLabelCardState();
}

class _CopyLabelCardState extends State<_CopyLabelCard> {
  static const _pubDevUrl = 'https://pub.dev/packages/reel_text';
  static const _displayUrl = 'pub.dev/packages/reel_text';

  late final ReelTextController _label;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: 'Copy');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _copy() {
    unawaited(Clipboard.setData(const ClipboardData(text: _pubDevUrl)));
    _label.flash(
      'Copied',
      options: ReelTextFlashOptions(
        enter: ReelTextOptions(
          color: Studio.success,
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 18),
        ),
        exit: ReelTextOptions(
          direction: ReelTextDirection.down,
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ExampleFrame(
      panelKey: const ValueKey('copy_button_panel'),
      title: 'Copy button',
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _displayUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Studio.mono(
                  size: 12,
                  color: Studio.muted,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              key: const ValueKey('copy_button_control'),
              width: 84,
              height: 34,
              child: OutlinedButton(
                onPressed: _copy,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Studio.inset,
                  foregroundColor: Studio.text,
                  side: BorderSide(color: Studio.borderBright),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: ClipRect(
                  child: SizedBox(
                    key: const ValueKey('copy_button_label_slot'),
                    height: 34,
                    child: Center(
                      child: ReelText.controller(
                        controller: _label,
                        style: Studio.mono(
                          size: 12,
                          color: Studio.text,
                          weight: FontWeight.w700,
                          height: Studio.compactLabelLineHeight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCounterCard extends StatefulWidget {
  const _LiveCounterCard();

  @override
  State<_LiveCounterCard> createState() => _LiveCounterCardState();
}

class _LiveCounterCardState extends State<_LiveCounterCard> {
  int _count = 1024;
  bool _up = true;

  @override
  Widget build(BuildContext context) {
    return _ExampleFrame(
      title: 'Stepper',
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _RoundIcon(
              icon: Icons.remove_rounded,
              onTap: () => setState(() {
                _count -= 1;
                _up = false;
              }),
            ),
            Expanded(
              child: Center(
                child: ReelText(
                  _grouped(_count),
                  options: ReelTextOptions(
                    direction: _up
                        ? ReelTextDirection.up
                        : ReelTextDirection.down,
                    color: _up ? Studio.success : Studio.danger,
                  ),
                  style:
                      Studio.mono(
                        size: 26,
                        color: Studio.text,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
            _RoundIcon(
              icon: Icons.add_rounded,
              onTap: () => setState(() {
                _count += 1;
                _up = true;
              }),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _count += 111;
                  _up = true;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Studio.tone(Studio.violet),
                  side: BorderSide(color: Studio.accentBorder(Studio.violet)),
                  minimumSize: const Size(58, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '+111',
                  style: Studio.mono(
                    size: 12,
                    color: Studio.tone(Studio.violet),
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onTap,
      style: IconButton.styleFrom(
        side: BorderSide(color: Studio.borderBright),
        foregroundColor: Studio.text,
        fixedSize: const Size.square(40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _StatusDatum {
  const _StatusDatum(this.label, this.color, this.direction);

  final String label;
  final Color color;
  final ReelTextDirection direction;
}

class _StatusPillCard extends StatefulWidget {
  const _StatusPillCard();

  @override
  State<_StatusPillCard> createState() => _StatusPillCardState();
}

class _StatusPillCardState extends State<_StatusPillCard> {
  List<_StatusDatum> get _items => [
    _StatusDatum('Draft', Studio.muted, ReelTextDirection.down),
    _StatusDatum('Review', Studio.warning, ReelTextDirection.up),
    _StatusDatum('Live', Studio.success, ReelTextDirection.up),
  ];

  int _index = 0;

  void _next() => setState(() => _index = (_index + 1) % _items.length);

  @override
  Widget build(BuildContext context) {
    final status = _items[_index];
    return _ExampleFrame(
      title: 'Status pill',
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Release',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Studio.mono(
                  size: 12,
                  color: Studio.muted,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              key: const ValueKey('status_pill_chip'),
              onTap: _next,
              borderRadius: BorderRadius.circular(999),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 92),
                child: SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: Studio.accentWash(status.color),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Studio.accentBorder(status.color),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: status.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ClipRect(
                              child: SizedBox(
                                key: const ValueKey('status_pill_label_slot'),
                                height: 32,
                                child: Center(
                                  child: ReelText(
                                    status.label,
                                    options: ReelTextOptions(
                                      direction: status.direction,
                                      color: status.color,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      stagger: const Duration(milliseconds: 22),
                                    ),
                                    style: Studio.mono(
                                      size: 12,
                                      color: status.color,
                                      weight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineLine {
  const _InlineLine(
    this.state,
    this.amount,
    this.eta,
    this.color,
    this.direction,
  );

  final String state;
  final String amount;
  final String eta;
  final Color color;
  final ReelTextDirection direction;
}

class _InlineMessageCard extends StatefulWidget {
  const _InlineMessageCard();

  @override
  State<_InlineMessageCard> createState() => _InlineMessageCardState();
}

class _InlineMessageCardState extends State<_InlineMessageCard> {
  List<_InlineLine> get _lines => [
    _InlineLine(
      'queued',
      '\$1,248.00',
      'today',
      Studio.warning,
      ReelTextDirection.up,
    ),
    _InlineLine(
      'approved',
      '\$1,312.40',
      'tomorrow',
      Studio.success,
      ReelTextDirection.up,
    ),
    _InlineLine(
      'returned',
      '\$986.15',
      'Friday',
      Studio.danger,
      ReelTextDirection.down,
    ),
  ];

  int _index = 0;

  void _next() => setState(() => _index = (_index + 1) % _lines.length);

  @override
  Widget build(BuildContext context) {
    final line = _lines[_index];
    final plain = Studio.body(
      size: 15,
      color: Studio.text.withValues(alpha: 0.88),
      height: 1.25,
    );
    final reel = Studio.mono(
      size: 15,
      color: line.color,
      weight: FontWeight.w700,
      height: 1.25,
    );
    return _ExampleFrame(
      title: 'Inline copy',
      child: ConstrainedBox(
        key: const ValueKey('inline_copy_row'),
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Payout is', style: plain),
                    ReelText(
                      line.state,
                      options: ReelTextOptions(
                        direction: line.direction,
                        color: line.color,
                      ),
                      style: reel,
                    ),
                    Text('for', style: plain),
                    ReelText(line.amount, style: reel),
                    Text('and lands', style: plain),
                    ReelText(line.eta, style: reel),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _RoundIcon(
              key: const ValueKey('inline_refresh_button'),
              icon: Icons.refresh_rounded,
              onTap: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveAsyncCard extends StatefulWidget {
  const _LiveAsyncCard();

  @override
  State<_LiveAsyncCard> createState() => _LiveAsyncCardState();
}

class _LiveAsyncCardState extends State<_LiveAsyncCard> {
  late final ReelTextController _label;
  Timer? _finish;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: 'Export');
  }

  @override
  void dispose() {
    _finish?.cancel();
    _label.dispose();
    super.dispose();
  }

  void _run({required bool succeed}) {
    _finish?.cancel();
    setState(() => _running = true);
    final completer = Completer<void>();
    _finish = Timer(const Duration(milliseconds: 1800), () {
      if (succeed) {
        completer.complete();
      } else {
        completer.completeError(StateError('failed'));
      }
    });
    unawaited(
      _label
          .runWhile<void>(
            () => completer.future,
            waiting: 'Exporting',
            success: 'Exported',
            failure: 'Failed',
            waitingOptions: ReelTextOptions(color: Studio.warning),
            successOptions: ReelTextOptions(color: Studio.success),
            failureOptions: ReelTextOptions(color: Studio.danger),
          )
          .catchError((Object _) {})
          .whenComplete(() {
            if (mounted) setState(() => _running = false);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ExampleFrame(
      title: 'Async action',
      child: SizedBox(
        key: const ValueKey('async_action_row'),
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReelText.controller(
                  controller: _label,
                  style: Studio.mono(
                    size: 15,
                    color: Studio.text,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _CompactActionButton(
              label: 'Run',
              color: Studio.success,
              onPressed: _running ? null : () => _run(succeed: true),
            ),
            const SizedBox(width: 8),
            _CompactActionButton(
              label: 'Fail',
              color: Studio.danger,
              onPressed: _running ? null : () => _run(succeed: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: Studio.faint,
          side: BorderSide(
            color: onPressed == null
                ? Studio.borderBright.withValues(alpha: 0.45)
                : color.withValues(alpha: 0.42),
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: Studio.mono(
            size: 12,
            color: onPressed == null ? Studio.faint : color,
            weight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared bits
// ===========================================================================

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    super.key,
    required this.label,
    required this.title,
    required this.subtitle,
    this.centered = false,
  });

  final String label;
  final String title;
  final String subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final content = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!centered) ...[
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Studio.borderBright,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: Studio.mono(
                size: 11,
                color: Studio.faint,
                weight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: Studio.display(size: compact ? 24 : 34, letterSpacing: 0),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            subtitle,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Studio.body(size: 14, height: 1.5),
          ),
        ),
      ],
    );
    return centered
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }
}

/// Install command, sitting directly under the scene.
class _InstallBlock extends StatefulWidget {
  const _InstallBlock();

  @override
  State<_InstallBlock> createState() => _InstallBlockState();
}

class _InstallBlockState extends State<_InstallBlock> {
  late final ReelTextController _label;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: 'Copy');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _copy() {
    unawaited(
      Clipboard.setData(const ClipboardData(text: 'flutter pub add reel_text')),
    );
    // Keep the flash on the button's contrast color instead of tinting it.
    _label.flash(
      'Copied',
      options: const ReelTextFlashOptions(
        enter: ReelTextOptions(
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 18),
        ),
        exit: ReelTextOptions(
          direction: ReelTextDirection.down,
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;

    final label = SizedBox(
      width: 62,
      child: Text(
        'Install',
        style: Studio.mono(
          size: 11,
          color: Studio.faint,
          weight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );

    final command = DecoratedBox(
      decoration: BoxDecoration(
        color: Studio.inset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Studio.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'flutter pub add reel_text',
            style: Studio.mono(
              size: 13,
              color: Studio.text.withValues(alpha: 0.9),
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    final copyButton = SizedBox(
      key: const ValueKey('install_copy_button'),
      width: 88,
      height: 34,
      child: FilledButton(
        onPressed: _copy,
        style: FilledButton.styleFrom(
          backgroundColor: Studio.primary,
          foregroundColor: Studio.onAccent(Studio.primary),
          padding: EdgeInsets.zero,
          minimumSize: const Size(88, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: ClipRect(
          child: SizedBox(
            key: const ValueKey('install_copy_label_slot'),
            width: 56,
            height: 34,
            child: Center(
              child: ReelText.controller(
                controller: _label,
                textAlign: TextAlign.center,
                style: Studio.mono(
                  size: 12,
                  color: Studio.onAccent(Studio.primary),
                  weight: FontWeight.w800,
                  letterSpacing: 0.2,
                  height: Studio.compactLabelLineHeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return _QuietPanel(
      key: const ValueKey('install_block_panel'),
      padding: EdgeInsets.all(compact ? 14 : 16),
      color: Studio.surface.withValues(alpha: 0.72),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 10),
                command,
                const SizedBox(height: 10),
                copyButton,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                label,
                const SizedBox(width: 16),
                command,
                const SizedBox(width: 10),
                copyButton,
              ],
            ),
    );
  }
}
