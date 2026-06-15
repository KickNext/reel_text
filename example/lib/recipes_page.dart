import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reel_text/reel_text.dart';

import 'code_view.dart';
import 'studio.dart';

/// Developer-facing screen: each recipe pairs a live, working preview with
/// the exact code that produces it.
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;
    final recipes = <Widget>[
      const _RecipeCard(
        title: 'Declarative swap',
        blurb: 'Rebuild with a new string. Unchanged glyphs stay planted.',
        preview: _DeclarativePreview(),
        code: _declarativeCode,
      ),
      const _RecipeCard(
        title: 'Copy button',
        blurb:
            'Use flash() for temporary feedback without resizing the button.',
        preview: _FlashPreview(),
        code: _flashCode,
      ),
      const _RecipeCard(
        title: 'Counter',
        blurb: 'Only changed digits move. Direction follows the delta.',
        preview: _CounterPreview(),
        code: _counterCode,
      ),
      const _RecipeCard(
        title: 'Async action',
        blurb: 'runWhile() keeps the label alive until a Future settles.',
        preview: _AsyncPreview(),
        code: _asyncCode,
      ),
      const _RecipeCard(
        title: 'Waiting label',
        blurb: 'startWaiting() returns a handle you can complete or fail.',
        preview: _WaitingPreview(),
        code: _waitingCode,
      ),
      const _RecipeCard(
        title: 'Spam-safe tap',
        blurb:
            'interrupt: false queues the latest target instead of thrashing.',
        preview: _SpamSafePreview(),
        code: _spamSafeCode,
      ),
    ];

    return ListView.separated(
      key: const ValueKey('recipes_list'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 40,
        vertical: 20,
      ),
      itemCount: recipes.length + 1,
      separatorBuilder: (_, index) => index == recipes.length - 1
          ? const SizedBox(height: 28)
          : const SizedBox(height: 18),
      itemBuilder: (context, index) {
        if (index == recipes.length) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: const StudioFooter(),
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            key: ValueKey('recipes_content_frame_$index'),
            constraints: const BoxConstraints(maxWidth: 1180),
            child: recipes[index],
          ),
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.title,
    required this.blurb,
    required this.preview,
    required this.code,
  });

  final String title;
  final String blurb;
  final Widget preview;
  final String code;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;
    final previewBox = DecoratedBox(
      decoration: BoxDecoration(
        color: Studio.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Studio.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: preview),
      ),
    );
    final codeBox = CodeView(code: code);

    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Studio.mono(
              size: 12.5,
              color: Studio.text,
              height: 1.25,
              letterSpacing: 0.1,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(blurb, style: Studio.body(size: 12.5)),
          const SizedBox(height: 16),
          if (compact) ...[
            previewBox,
            const SizedBox(height: 12),
            codeBox,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: previewBox),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: codeBox),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecipeMotionSlot extends StatelessWidget {
  const _RecipeMotionSlot({
    required this.height,
    required this.child,
    this.width,
    this.slotKey,
  });

  final double height;
  final double? width;
  final Key? slotKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        key: slotKey,
        width: width,
        height: height,
        child: Center(child: child),
      ),
    );
  }
}

class _RecipeReelButton extends StatelessWidget {
  const _RecipeReelButton({
    required this.onPressed,
    required this.controller,
    required this.icon,
    required this.labelWidth,
    required this.slotKey,
    this.buttonKey,
    this.accent,
  });

  static const height = 44.0;

  final VoidCallback onPressed;
  final ReelTextController controller;
  final IconData icon;
  final double labelWidth;
  final Key slotKey;
  final Key? buttonKey;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fill = accent ?? Studio.primary;
    final foreground = Studio.onAccent(fill);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          key: buttonKey,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 8),
                _RecipeMotionSlot(
                  slotKey: slotKey,
                  width: labelWidth,
                  height: height,
                  child: ReelText.controller(
                    controller: controller,
                    style: Studio.mono(
                      size: 12.5,
                      color: foreground,
                      weight: FontWeight.w700,
                      letterSpacing: 0.8,
                      height: Studio.compactLabelLineHeight,
                    ),
                    textAlign: TextAlign.center,
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
// 5. Counter
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
// 6. Spam-safe button
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
      labelWidth: 46,
      onPressed: () {
        _liked = !_liked;
        _label.set(
          _liked ? 'Liked' : 'Like',
          options: const ReelTextOptions(interrupt: false),
        );
      },
    );
  }
}
