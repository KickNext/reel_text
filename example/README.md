# reel_text example

Interactive Flutter example app for the `reel_text` package.

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

Run it with:

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
