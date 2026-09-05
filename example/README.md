# reel_text example

`example.md` contains the concise usage example displayed on pub.dev.
`lib/main.dart` runs the full interactive showcase deployed to GitHub Pages.

This app has its own SDK constraint and dependencies in this directory. The
package compatibility floor is defined by the root `pubspec.yaml`.

Demo-only dependencies such as `http`, `url_launcher`, `flutter_svg`,
`google_fonts`, and `shared_preferences` are scoped to this app.

It demonstrates:

- A choreographed Home page for the main motion patterns.
- Recipe cards with live previews and copy-ready code.
- Imperative button feedback with `ReelTextController.flash()`.
- Async labels with `runWhile()` and `startWaiting()`.
- Numeric counters, status pills, rotating labels, and rich text with anchored
  inline widgets.
- A motion workbench with target editing, direction/color/timing controls, and
  a `ReelText.controller` preview.

The visual performance stress case lives outside the showcase as an integration
benchmark. Run it on a target device in profile mode:

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/performance_benchmark_test.dart \
  --profile \
  -d macos
```

Replace `macos` with the target device ID from `flutter devices` (for example,
`windows`). The benchmark covers 1, 4, 8, 16, 32, 64, 128, and 256 labels with
plain and chromatic rolls. Results are saved to
`build/integration_response_data.json`. Compare runs on the same device and SDK;
the benchmark records timings but does not enforce a performance threshold.

This grid is a stress test, not a model of typical application usage. For
single-label compute regressions, run `flutter test test/reel_text_compute_test.dart`
from the package root. It covers counter updates, copy feedback, completed
color fades, idle time, and subsequent transitions. Its work counts are not
wall-clock performance measurements.

To capture the rendering matrix on an Android device:

```bash
flutter drive \
  --driver=test_driver/visual_regression.dart \
  --target=integration_test/visual_regression_test.dart \
  -d <android-device-id>
```

Screenshots are saved to `build/visual_screenshots/` for manual comparison.
This capture test does not automatically compare images against a baseline.

Run the interactive showcase with:

```bash
flutter run
```

Install the optional agent skill for this app with the `npx skills` CLI style
used by the official
[Flutter](https://github.com/flutter/skills) and
[Dart](https://github.com/dart-lang/skills) skill repositories:

```bash
npx skills add KickNext/reel_text --skill reel-text --agent universal --yes
```

Run it from this `example/` directory. It creates local agent-tooling files
that are ignored by git.

Build it for web with:

```bash
flutter build web
```

For the public GitHub Pages path:

```bash
flutter build web --base-href "/reel_text/"
```

Widget tests cover Flutter's Android/iOS tap target, labeled target, and text
contrast guidelines across desktop and mobile layouts, plus a smoke test at
200% text scaling.
