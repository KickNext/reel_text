# reel_text

[![pub package](https://img.shields.io/pub/v/reel_text.svg)](https://pub.dev/packages/reel_text)
[![live demo](https://img.shields.io/badge/demo-live-blue)](https://kicknext.github.io/reel_text/)

Dependency-light Flutter text roll animation for short labels, counters, status
text, command buttons, rich text, and inline editable text corrections.

`reel_text` brings the DOM text-roll idea from
[Danilaa1's original package](https://github.com/Danilaa1/slot-text) to
Flutter. Each grapheme cluster gets its own measured slot, changed glyphs slide
vertically, optional color flashes fade back to the inherited text color, and
imperative `flash()` calls stay safe under rapid button taps.

![reel_text showcase](assets/showcase.webp)

[Try the live demo](https://kicknext.github.io/reel_text/)

## Install

```bash
flutter pub add reel_text
```

Then import it:

```dart
import 'package:reel_text/reel_text.dart';
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

`ReelText` keeps the same single-line layout box as Flutter `Text` for the
current target string, including during a roll. It does not add extra vertical
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

The example editor uses this controller with a spell-check pipeline:
LanguageTool for online suggestions, Flutter's native spellcheck service where
the platform exposes one, and a deterministic fallback for offline demo text.

## Reduced motion

When the platform requests reduced motion
(`MediaQuery.disableAnimationsOf(context)`), `ReelText` snaps to the target
text instantly instead of rolling. Opt out per widget with
`respectDisableAnimations: false`.

## Dynamic fonts

`ReelText` measures glyph slots from the active Flutter text layout. If your app
loads fonts asynchronously, preload them before the first `ReelText` frame so
initial slot widths are measured with the final font:

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
| `curve` | springy cubic | Slide curve. |
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

## Example app

Run the included example:

```bash
cd example
flutter run
```

The example has three pages:

- **Home**: a self-running, choreographed presentation of the core motion
  patterns.
- **Recipes**: live previews with copy-ready code for common integrations.
- **Editor**: a selectable document where typo corrections roll inline in the
  body copy.

Build the web demo with:

```bash
cd example
flutter build web
```
