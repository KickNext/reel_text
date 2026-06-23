part of '../recipes_page.dart';

// ---------------------------------------------------------------------------
// 1. Declarative swap
// ---------------------------------------------------------------------------

const _declarativeCode = '''
bool saved = false;

ClipRect(
  child: SizedBox(
    height: 58,
    child: Center(
      child: ReelText(
        saved ? 'Saved' : 'Save',
        options: const ReelTextOptions(
          direction: ReelTextDirection.up,
        ),
        style: const TextStyle(fontSize: 24),
      ),
    ),
  ),
);

// Anywhere in your state:
setState(() => saved = !saved);''';

class _DeclarativePreview extends StatefulWidget {
  const _DeclarativePreview();

  @override
  State<_DeclarativePreview> createState() => _DeclarativePreviewState();
}

class _DeclarativePreviewState extends State<_DeclarativePreview> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_declarative_motion_slot'),
          height: 58,
          child: ReelText(
            _saved ? 'Saved' : 'Save',
            options: const ReelTextOptions(direction: ReelTextDirection.up),
            style: Studio.display(size: 26, letterSpacing: 0),
          ),
        ),
        const SizedBox(height: 16),
        StudioButton(
          onPressed: () => setState(() => _saved = !_saved),
          filled: false,
          child: const Text('Toggle'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. flash()
// ---------------------------------------------------------------------------

const _flashCode = '''
final label = ReelTextController(initialText: 'Copy');

// In build:
ClipRect(
  child: SizedBox(
    width: 58,
    height: 44,
    child: Center(
      child: ReelText.controller(controller: label),
    ),
  ),
);

// On tap:
label.flash(
  'Copied',
  options: ReelTextFlashOptions(
    revertAfter: const Duration(milliseconds: 1400),
    enter: ReelTextOptions(
      colorBuilder: chromatic(
        from: 205,
        spread: 155,
        saturation: 0.58,
        lightness: 0.74,
      ),
    ),
    exit: const ReelTextOptions(
      direction: ReelTextDirection.down,
    ),
  ),
);''';

class _FlashPreview extends StatefulWidget {
  const _FlashPreview();

  @override
  State<_FlashPreview> createState() => _FlashPreviewState();
}

class _FlashPreviewState extends State<_FlashPreview> {
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

  @override
  Widget build(BuildContext context) {
    return _RecipeReelButton(
      buttonKey: const ValueKey('recipe_flash_button'),
      slotKey: const ValueKey('recipe_flash_motion_slot'),
      controller: _label,
      icon: Icons.copy_rounded,
      semanticsLabel: 'Copy',
      labelWidth: 58,
      onPressed: () {
        _label.flash(
          'Copied',
          options: ReelTextFlashOptions(
            enter: ReelTextOptions(
              colorBuilder: chromatic(
                from: 205,
                spread: 155,
                saturation: 0.58,
                lightness: 0.74,
              ),
            ),
            exit: const ReelTextOptions(direction: ReelTextDirection.down),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Async operation
// ---------------------------------------------------------------------------

const _asyncCode = '''
final label = ReelTextController(initialText: 'Export');

ClipRect(
  child: SizedBox(
    height: 58,
    child: Center(
      child: ReelText.controller(controller: label),
    ),
  ),
);

Future<void> export() {
  return label.runWhile(
    doExport,
    waiting: 'Exporting',
    success: 'Exported',
    failure: 'Failed',
  );
}''';

class _AsyncPreview extends StatefulWidget {
  const _AsyncPreview();

  @override
  State<_AsyncPreview> createState() => _AsyncPreviewState();
}

class _AsyncPreviewState extends State<_AsyncPreview> {
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
    _finish = Timer(const Duration(milliseconds: 2600), () {
      if (succeed) {
        completer.complete();
      } else {
        completer.completeError(StateError('Export failed'));
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
            if (mounted) {
              setState(() => _running = false);
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_async_motion_slot'),
          height: 58,
          child: ReelText.controller(
            controller: _label,
            style: Studio.display(size: 24, letterSpacing: 0),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            StudioButton(
              onPressed: _running ? null : () => _run(succeed: true),
              filled: false,
              child: const Text('Run · success'),
            ),
            StudioButton(
              onPressed: _running ? null : () => _run(succeed: false),
              filled: false,
              accent: Studio.danger,
              child: const Text('Run · failure'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Waiting label
// ---------------------------------------------------------------------------

const _waitingCode = '''
final label = ReelTextController(initialText: 'Sync');

ClipRect(
  child: SizedBox(
    height: 56,
    child: Center(
      child: ReelText.controller(controller: label),
    ),
  ),
);

final handle = label.startWaiting(
  'Syncing',
  waiting: const ReelWaiting.ellipsis(),
);

try {
  await sync();
  handle.complete('Synced');
} catch (_) {
  handle.fail('Failed');
}''';

class _WaitingPreview extends StatefulWidget {
  const _WaitingPreview();

  @override
  State<_WaitingPreview> createState() => _WaitingPreviewState();
}

class _WaitingPreviewState extends State<_WaitingPreview> {
  late final ReelTextController _label;
  ReelTextProgress? _handle;
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: 'Sync');
  }

  @override
  void dispose() {
    _handle?.cancel();
    _label.dispose();
    super.dispose();
  }

  void _start() {
    if (_handle?.isActive ?? false) {
      return;
    }
    _handle = _label.startWaiting(
      'Syncing',
      waiting: const ReelWaiting.ellipsis(),
      options: ReelTextOptions(color: Studio.warning),
    );
    setState(() => _waiting = true);
  }

  void _complete() {
    final handle = _handle;
    if (handle != null && handle.isActive) {
      handle.complete(
        'Synced',
        options: ReelTextOptions(color: Studio.success),
      );
    } else {
      _label.set('Synced', options: ReelTextOptions(color: Studio.success));
    }
    setState(() => _waiting = false);
  }

  void _fail() {
    final handle = _handle;
    if (handle != null && handle.isActive) {
      handle.fail('Failed', options: ReelTextOptions(color: Studio.danger));
    } else {
      _label.set('Failed', options: ReelTextOptions(color: Studio.danger));
    }
    setState(() => _waiting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_waiting_motion_slot'),
          height: 56,
          child: ReelText.controller(
            controller: _label,
            style: Studio.display(size: 22, letterSpacing: 0),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            StudioButton(
              onPressed: _waiting ? null : _start,
              filled: false,
              child: const Text('Start'),
            ),
            StudioButton(
              onPressed: _waiting ? _complete : null,
              filled: false,
              child: const Text('Complete'),
            ),
            StudioButton(
              onPressed: _waiting ? _fail : null,
              filled: false,
              accent: Studio.danger,
              child: const Text('Fail'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. WidgetSpan inline
// ---------------------------------------------------------------------------

const _widgetSpanCode = '''
TextSpan statusSpan(bool reviewed) {
  return TextSpan(
    children: [
      TextSpan(text: reviewed ? 'Reviewed ' : 'Queued '),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: StatusBadge(label: reviewed ? 'QA' : 'AI'),
      ),
      TextSpan(text: reviewed ? ' done' : ' check'),
    ],
  );
}

SelectionArea(
  child: ReelText.rich(
    statusSpan(reviewed),
    semanticsLabel: reviewed
        ? 'Reviewed by QA, done'
        : 'Queued for AI check',
  ),
);''';

class _WidgetSpanPreview extends StatefulWidget {
  const _WidgetSpanPreview();

  @override
  State<_WidgetSpanPreview> createState() => _WidgetSpanPreviewState();
}

class _WidgetSpanPreviewState extends State<_WidgetSpanPreview> {
  bool _reviewed = false;

  TextSpan _span() {
    return TextSpan(
      children: [
        TextSpan(text: _reviewed ? 'Reviewed ' : 'Queued '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineStatusBadge(
            key: const ValueKey('recipe_widget_span_badge'),
            label: _reviewed ? 'QA' : 'AI',
            accent: _reviewed ? Studio.success : Studio.violet,
          ),
        ),
        TextSpan(text: _reviewed ? ' done' : ' check'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_widget_span_slot'),
          height: 62,
          child: SelectionArea(
            child: ReelText.rich(
              _span(),
              semanticsLabel: _reviewed
                  ? 'Reviewed by QA, done'
                  : 'Queued for AI check',
              style: Studio.display(
                size: 24,
                color: Studio.text,
                height: 1.12,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StudioButton(
          onPressed: () => setState(() => _reviewed = !_reviewed),
          filled: false,
          child: Text(_reviewed ? 'Reset' : 'Mark reviewed'),
        ),
      ],
    );
  }
}

class _InlineStatusBadge extends StatelessWidget {
  const _InlineStatusBadge({
    super.key,
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Studio.accentWash(accent, alpha: Studio.isLight ? 0.16 : 0.18),
          border: Border.all(color: Studio.accentBorder(accent, alpha: 0.58)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            label,
            style: Studio.mono(
              size: 11,
              color: Studio.tone(accent),
              weight: FontWeight.w800,
              height: 1,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. WidgetSpan RTL
// ---------------------------------------------------------------------------

const _widgetSpanRtlCode = '''
TextSpan flightSpan(bool boarding) {
  return TextSpan(
    children: [
      TextSpan(text: boarding ? 'Gate B4 פתוח ' : 'ETA 12 דק '),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: StatusBadge(label: boarding ? 'OK' : 'AI'),
      ),
    ],
  );
}

Directionality(
  textDirection: TextDirection.rtl,
  child: ReelText.rich(
    flightSpan(boarding),
    textAlign: TextAlign.start,
    locale: const Locale('he'),
    semanticsLabel: boarding
        ? 'Gate B4 open, OK'
        : 'ETA 12 minutes, AI',
  ),
);''';

class _WidgetSpanRtlPreview extends StatefulWidget {
  const _WidgetSpanRtlPreview();

  @override
  State<_WidgetSpanRtlPreview> createState() => _WidgetSpanRtlPreviewState();
}

class _WidgetSpanRtlPreviewState extends State<_WidgetSpanRtlPreview> {
  bool _boarding = false;

  TextSpan _span() {
    return TextSpan(
      children: [
        TextSpan(text: _boarding ? 'Gate B4 פתוח ' : 'ETA 12 דק '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineStatusBadge(
            key: const ValueKey('recipe_widget_span_rtl_badge'),
            label: _boarding ? 'OK' : 'AI',
            accent: _boarding ? Studio.success : Studio.info,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_widget_span_rtl_slot'),
          width: 330,
          height: 62,
          child: Directionality(
            key: const ValueKey('recipe_widget_span_rtl_directionality'),
            textDirection: TextDirection.rtl,
            child: SelectionArea(
              child: ReelText.rich(
                _span(),
                textAlign: TextAlign.start,
                locale: const Locale('he'),
                semanticsLabel: _boarding
                    ? 'Gate B4 open, OK'
                    : 'ETA 12 minutes, AI',
                style: Studio.display(
                  size: 23,
                  color: Studio.text,
                  height: 1.12,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StudioButton(
          onPressed: () => setState(() => _boarding = !_boarding),
          filled: false,
          child: const Text('Roll RTL badge'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Counter
// ---------------------------------------------------------------------------

const _counterCode = r'''
int count = 1024;
bool up = true;

final counter = ReelText(
  '$count',
  // Only changed digits roll (skipUnchanged: true is the
  // default). Direction follows the delta.
  options: ReelTextOptions(
    direction: up ? ReelTextDirection.up : ReelTextDirection.down,
  ),
  style: const TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
);

// Give the roll its own viewport in tight UI.
ClipRect(
  child: SizedBox(height: 72, child: Center(child: counter)),
);

// On taps:
setState(() { count += 1; up = true; });
setState(() { count -= 1; up = false; });''';

class _CounterPreview extends StatefulWidget {
  const _CounterPreview();

  @override
  State<_CounterPreview> createState() => _CounterPreviewState();
}

class _CounterPreviewState extends State<_CounterPreview> {
  int _count = 1024;
  bool _up = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_counter_motion_slot'),
          height: 72,
          child: ReelText(
            '$_count',
            options: ReelTextOptions(
              direction: _up ? ReelTextDirection.up : ReelTextDirection.down,
            ),
            style: Studio.mono(
              size: 40,
              color: Studio.text,
              weight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Decrease counter',
              onPressed: () => setState(() {
                _count -= 1;
                _up = false;
              }),
              style: IconButton.styleFrom(
                side: BorderSide(color: Studio.border),
                foregroundColor: Studio.text,
              ),
              icon: const Icon(Icons.remove_rounded),
            ),
            IconButton.outlined(
              tooltip: 'Increase counter',
              onPressed: () => setState(() {
                _count += 1;
                _up = true;
              }),
              style: IconButton.styleFrom(
                side: BorderSide(color: Studio.border),
                foregroundColor: Studio.text,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Spam-safe button
// ---------------------------------------------------------------------------

const _spamSafeCode = '''
final label = ReelTextController(initialText: 'Like');
var liked = false;

ClipRect(
  child: SizedBox(
    width: 46,
    height: 44,
    child: Center(
      child: ReelText.controller(controller: label),
    ),
  ),
);

// On every tap — even very fast ones:
liked = !liked;
label.set(
  liked ? 'Liked' : 'Like',
  options: const ReelTextOptions(
    interrupt: false, // finish the roll, play only the latest
  ),
);''';

class _SpamSafePreview extends StatefulWidget {
  const _SpamSafePreview();

  @override
  State<_SpamSafePreview> createState() => _SpamSafePreviewState();
}

class _SpamSafePreviewState extends State<_SpamSafePreview> {
  late final ReelTextController _label;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: 'Like');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RecipeReelButton(
      buttonKey: const ValueKey('recipe_spam_button'),
      slotKey: const ValueKey('recipe_spam_motion_slot'),
      controller: _label,
      accent: Studio.danger,
      icon: Icons.favorite_rounded,
      semanticsLabel: _liked ? 'Liked' : 'Like',
      labelWidth: 46,
      onPressed: () {
        setState(() => _liked = !_liked);
        _label.set(
          _liked ? 'Liked' : 'Like',
          options: const ReelTextOptions(interrupt: false),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Mixed bidi
// ---------------------------------------------------------------------------

const _mixedBidiCode = '''
final label = ReelTextController(initialText: 'ETA 12 דק');

Directionality(
  textDirection: TextDirection.rtl,
  child: SizedBox(
    width: 280,
    child: ReelText.controller(
      controller: label,
      textAlign: TextAlign.start,
      locale: const Locale('he'),
    ),
  ),
);

// On tap:
label.set('Gate B4 פתוח');''';

class _MixedBidiPreview extends StatefulWidget {
  const _MixedBidiPreview();

  @override
  State<_MixedBidiPreview> createState() => _MixedBidiPreviewState();
}

class _MixedBidiPreviewState extends State<_MixedBidiPreview> {
  static const _labels = ['ETA 12 דק', 'ETA 09 דק', 'Gate B4 פתוח'];

  late final ReelTextController _label;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: _labels.first);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _roll() {
    _index = (_index + 1) % _labels.length;
    _label.set(
      _labels[_index],
      options: const ReelTextOptions(direction: ReelTextDirection.up),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_mixed_bidi_motion_slot'),
          width: 330,
          height: 62,
          child: Directionality(
            key: const ValueKey('recipe_mixed_bidi_directionality'),
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 280,
              child: ReelText.controller(
                key: const ValueKey('recipe_mixed_bidi_text'),
                controller: _label,
                textAlign: TextAlign.start,
                locale: const Locale('he'),
                style: TextStyle(
                  color: Studio.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StudioButton(
          onPressed: _roll,
          filled: false,
          child: const Text('Roll mixed'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 10. RTL script
// ---------------------------------------------------------------------------

const _rtlCode = '''
final label = ReelTextController(initialText: 'משלוח בדרך ליעד');

Directionality(
  textDirection: TextDirection.rtl,
  child: SizedBox(
    width: 260,
    child: ReelText.controller(
      controller: label,
      textAlign: TextAlign.start,
      locale: const Locale('he'),
    ),
  ),
);

// On tap:
label.set('עדכון מסלול צפוני');''';

class _RtlPreview extends StatefulWidget {
  const _RtlPreview();

  @override
  State<_RtlPreview> createState() => _RtlPreviewState();
}

class _RtlPreviewState extends State<_RtlPreview> {
  static const _labels = [
    'משלוח בדרך ליעד',
    'עדכון מסלול צפוני',
    'הגעה בעוד רגעים',
  ];

  late final ReelTextController _label;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _label = ReelTextController(initialText: _labels.first);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _roll() {
    _index = (_index + 1) % _labels.length;
    _label.set(
      _labels[_index],
      options: const ReelTextOptions(direction: ReelTextDirection.up),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecipeMotionSlot(
          slotKey: const ValueKey('recipe_rtl_motion_slot'),
          width: 300,
          height: 62,
          child: Directionality(
            key: const ValueKey('recipe_rtl_directionality'),
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 260,
              child: ReelText.controller(
                key: const ValueKey('recipe_rtl_text'),
                controller: _label,
                textAlign: TextAlign.start,
                locale: const Locale('he'),
                style: TextStyle(
                  color: Studio.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StudioButton(
          onPressed: _roll,
          filled: false,
          child: const Text('Roll RTL'),
        ),
      ],
    );
  }
}
