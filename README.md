# reel_text

[![pub package](https://img.shields.io/pub/v/reel_text.svg)](https://pub.dev/packages/reel_text)
[![live demo](https://img.shields.io/badge/demo-live-blue)](https://kicknext.github.io/reel_text/)

Dependency-light Flutter text roll animation for short labels, counters, status
text, command buttons, rich text, and inline editable text corrections. The
package itself has no runtime dependencies beyond Flutter.

`reel_text` brings the DOM text-roll idea from
[Danilaa1's original package](https://github.com/Danilaa1/slot-text) to
Flutter. Each grapheme cluster gets its own measured slot, changed glyphs slide
vertically, optional color flashes fade back to the inherited text color, and
imperative `flash()` calls stay safe under rapid button taps.

![reel_text showcase](https://raw.githubusercontent.com/KickNext/reel_text/main/assets/reel_text_hero_light_720p_60fps_full_cycle.webp)

[Try the live demo](https://kicknext.github.io/reel_text/)

## Install

```bash
flutter pub add reel_text
```

If you keep `pubspec.yaml` organized by hand, add `reel_text` under
`dependencies` using the current version constraint from
[pub.dev](https://pub.dev/packages/reel_text/install).

Then run:

```bash
flutter pub get
```

The package supports Dart 3.2.0 and Flutter 3.16.0 and newer.

Then import it:

```dart
import 'package:reel_text/reel_text.dart';
```

## AI agent skill

This repository includes an optional agent skill for AI coding tools:
[`skills/reel-text/SKILL.md`](https://github.com/KickNext/reel_text/blob/main/skills/reel-text/SKILL.md).
It helps agents decide when `reel_text` is appropriate, when plain `Text` is
better, and which API to use.

Install with the Agent Skills CLI:

```bash
npx skills add KickNext/reel_text --skill reel-text
```

Update an installed skill after this repository changes:

```bash
npx skills update reel-text --project
```

Use `--global` instead of `--project` if you installed the skill globally.

Or install the
[`skills/reel-text`](https://github.com/KickNext/reel_text/tree/main/skills/reel-text)
folder manually in any agent that supports local skills. The `SKILL.md` file is
the portable source of truth; `agents/openai.yaml` only adds optional
Codex/OpenAI UI metadata.

Then ask:

```text
Use $reel-text to add meaningful rolling text transitions to this Flutter UI.
```

## When to use it

- Command feedback: `Copy -> Copied -> Copy`.
- Status labels: `Export -> Exporting... -> Exported`.
- Small counters, scoreboards, and compact metrics.
- Rotating hero words or action labels.
- Rich text phrases that need inline styles.
- Editable text corrections where the replacement should animate in place.

Keep it focused on short, high-signal text. Long paragraphs are better left to
plain `Text`.

## API map

| Need | Use |
| --- | --- |
| Declarative one-line text | `ReelText('Copy')` |
| Styled inline phrase | `ReelText.rich(TextSpan(...))` |
| Imperative labels | `ReelTextController` with `ReelText.controller` |
| Temporary button feedback | `ReelTextController.flash()` |
| Async waiting/success/failure labels | `ReelTextController.runWhile()` |
| Manual progress or waiting loops | `ReelTextController.startProgress()` or `.startWaiting()` |
| Rotating labels without a controller | `ReelText.sequence` |
| Editable inline corrections | `ReelTextEditingController` and `ReelTextEditReplacement` |

## Quick start

Use `ReelText` anywhere you would use a one-line `Text` widget:

```dart
ReelText(
  copied ? 'Copied' : 'Copy',
  options: ReelTextOptions(
    direction: copied ? ReelTextDirection.up : ReelTextDirection.down,
    colorBuilder: copied ? chromatic() : null,
  ),
);
```

For imperative button feedback, drive the widget with a controller:

```dart
final label = ReelTextController(initialText: 'Copy');

ReelText.controller(controller: label);

label.flash(
  'Copied',
  options: ReelTextFlashOptions(
    enter: ReelTextOptions(colorBuilder: chromatic()),
    exit: const ReelTextOptions(direction: ReelTextDirection.down),
  ),
);
```

`flash()` captures the resting text on the first flash in a burst, resets the
revert timer on repeated calls, and rolls back once after the last flash.
Calling `set()` cancels a pending revert:

```dart
label.set('Saved');
label.set(
  'Save',
  options: const ReelTextOptions(direction: ReelTextDirection.down),
);
```

Dispose controllers from your widget state:

```dart
@override
void dispose() {
  label.dispose();
  super.dispose();
}
```

## Async labels

Use `runWhile()` when a label should move through waiting, success, and failure
states around an async operation:

```dart
final exportLabel = ReelTextController(initialText: 'Export');

await exportLabel.runWhile(
  exportFile,
  waiting: 'Exporting',
  success: 'Exported',
  failure: 'Failed',
  waitingOptions: const ReelTextOptions(color: Color(0xffffb84d)),
  successOptions: const ReelTextOptions(color: Color(0xff38bdf8)),
  failureOptions: const ReelTextOptions(color: Color(0xffe11d48)),
);
```

`runWhile()` starts the waiting loop before invoking the operation, emits the
success label on completion, and emits the failure label before rethrowing an
error.

## Waiting animations

For lower-level control, start a waiting loop and resolve it yourself:

```dart
final label = ReelTextController(initialText: 'Export');

final handle = label.startWaiting('Exporting');
try {
  await exportFile();
  handle.complete('Exported');
} catch (_) {
  handle.fail('Failed');
}
```

Pick the look with a `ReelWaiting` preset:

```dart
// Exporting -> Exporting. -> Exporting.. -> Exporting...
label.startWaiting('Exporting', waiting: const ReelWaiting.ellipsis());

// A calm self-roll wave sweeps across the readable label.
label.startWaiting(
  'Exporting',
  waiting: const ReelWaiting.wave(rest: Duration(milliseconds: 1200)),
);

// Scramble a suffix while periodically returning to the readable label.
label.startWaiting(
  'Exporting',
  waiting: const ReelWaiting.scramble(protectedPrefix: 6),
);
```

Use `startProgress()` when you want to supply explicit frames instead of a
waiting preset. All waiting and progress helpers compile down to the same roll
engine as normal text changes, so options for direction, curve, stagger, and
color still apply.

Both `startWaiting()` and `startProgress()` return a `ReelTextProgress` handle.
Use `complete()`, `fail()`, or `cancel()` to stop the loop, and `isActive` to
ignore stale async callbacks after another progress loop has taken over.

## Sequences

Use `ReelText.sequence` when a label should rotate without manually wiring a
controller and timer:

```dart
ReelText.sequence(
  values: const ['CRAFT', 'DRAFT', 'DRIFT'],
  interval: const Duration(milliseconds: 2400),
  optionsBuilder: (index, value) => ReelTextOptions(
    direction: index.isEven ? ReelTextDirection.up : ReelTextDirection.down,
  ).withChromatic(from: 70 + index * 54),
);
```

## Layout, selection, and emoji

In settled state, `ReelText` keeps the same single-line layout box as Flutter
`Text` for the current string. During a roll, its width interpolates toward the
target string while the height stays stable. It does not add extra vertical
padding for the animation, and heavy text styles get extra horizontal paint
room so bold glyphs do not clip at slot edges.

`textAlign` is visible when a parent gives the widget a real width, such as
`SizedBox` or `Expanded`; loose max-width constraints keep the intrinsic text
width:

```dart
const SizedBox(
  width: 160,
  child: ReelText('Copied', textAlign: TextAlign.end),
);
```

Inside a `SelectionArea`, `ReelText` exposes one selectable surface for the full
current string while the animated glyphs stay visual-only. Extended emoji and
joined emoji sequences are treated as whole grapheme clusters:

```dart
SelectionArea(
  child: ReelText('Ready 👨‍👩‍👧‍👦🧑🏽‍💻👍🏽'),
);
```

Use `ReelText.rich` when the changing phrase needs inline styles:

```dart
ReelText.rich(
  const TextSpan(
    children: [
      TextSpan(text: 'Draft: ', style: TextStyle(color: Colors.redAccent)),
      TextSpan(text: 'rewrite with evidence'),
    ],
  ),
);
```

`ReelText.rich` supports `TextSpan` trees. `WidgetSpan` is not supported because
the widget splits text into measured rolling grapheme clusters.

Screen readers get one semantic label for the current value. For rich text,
`TextSpan.semanticsLabel` is respected; pass `semanticsLabel` to `ReelText` when
the whole rolling label needs a custom spoken value.

RTL and mixed-bidi labels follow Flutter's visual glyph order while keeping
logical semantics. Use `Directionality` or the widget's `textDirection` when the
label lives outside an already-directional subtree:

```dart
Directionality(
  textDirection: TextDirection.rtl,
  child: ReelText('ETA 12 דק', textAlign: TextAlign.start),
);
```

During a roll, bidi labels are diffed in visual slots instead of applying a
separate horizontal correction after the glyph replacement.

Because each grapheme cluster gets its own measured slot, Flutter still owns
the font metrics, bidi visual order, and emoji clusters, but text shaping is not
identical to one continuous `Text` run in every script. Latin kerning pairs and
ligatures may look slightly looser during slot animation, and connected scripts
such as Arabic should be tested in context before using a roll effect. For short
labels, counters, statuses, and commands, this tradeoff keeps the motion
predictable.

## Editable text

For editable surfaces, use `ReelTextEditingController`. It extends Flutter's
`TextEditingController` and renders temporary replacements inside the same
`EditableText` layout, so caret, selection, wrapping, and scroll geometry stay
owned by Flutter:

```dart
final controller = ReelTextEditingController(text: 'Please recieve teh file.');

controller.animateReplacements(
  replacements: [
    const ReelTextEditReplacement(
      range: TextRange(start: 7, end: 14),
      replacement: 'receive',
      options: ReelTextOptions(color: Color(0xff84cc16)),
    ),
  ],
  commitAfter: const Duration(milliseconds: 760),
);
```

For custom editors, `beginReplacements()` can stage inline replacement widgets,
`animateReplacements()` rolls them to their target text, `replacementText()`
previews the committed string, and `commitReplacements()` or
`clearReplacements()` resolves the edit. Replacement ranges are validated and
must not overlap. Pass `spanBuilder` to customize the resting text span without
subclassing the controller.

## Accessibility and reduced motion

When the platform requests reduced motion
(`MediaQuery.disableAnimationsOf(context)`), `ReelText` snaps to the target
text instantly instead of rolling. Opt out per widget with
`respectDisableAnimations: false`.

## Dynamic fonts

`ReelText` measures glyph slots from the active Flutter text layout. If your app
loads fonts asynchronously, preload them before the first `ReelText` frame so
initial slot widths are measured with the final font. For example, with
`google_fonts`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.archivoBlack();
  await GoogleFonts.pendingFonts();
  runApp(const App());
}
```

## Options

| Option | Default | Description |
| --- | --- | --- |
| `direction` | `ReelTextDirection.down` | Roll direction. |
| `stagger` | `45ms` | Delay between glyph starts. |
| `duration` | `300ms` | Per-glyph slide duration. |
| `exitOffset` | `50ms` | Delay before incoming glyphs chase outgoing glyphs. |
| `curve` | `Cubic(0.34, 1.56, 0.64, 1)` | Slide curve. |
| `bounce` | `0.6` | Per-glyph timing/tilt variation and settle-overshoot depth. |
| `color` | null | Flat incoming glyph tint. |
| `colorBuilder` | null | Per-glyph incoming tint, such as `chromatic()`. |
| `colorFade` | `280ms` | Tint fade-back duration. |
| `skipUnchanged` | `true` | Keeps identical same-index glyphs static. |
| `interrupt` | `true` | Interrupts in-flight rolls; set false to queue only the latest target. |

Useful helpers:

```dart
const ReelTextOptions().reversed();
const ReelTextOptions().withColor(Colors.green);
const ReelTextOptions().withChromatic(from: 80);
const ReelTextOptions().withoutColor();
```
