## Unreleased

- Added accessibility guideline coverage for the example app across desktop and
  mobile Home, Recipes, and Editor layouts.
- Improved example tap targets, semantic labels, and text-scale resilience for
  top navigation, metadata links, recipe controls, and editor controls.
- Made `ReelText.rich` respect nested `TextSpan.semanticsLabel` values unless a
  widget-level `semanticsLabel` override is provided.
- Fixed glyph width measurement for mixed RTL/LTR bidi labels so internal slot
  widths cannot become negative.
- Added RTL, mixed bidi, and locale layout regression coverage.
- Added an example RTL/bidi recipe for visually checking mixed-direction rolls.

## 0.1.3

- Fixed `DefaultTextStyle.textAlign` inheritance so `ReelText` follows Flutter
  `Text` layout semantics while internal glyph faces stay anchored inside their
  paint boxes.
- Added regression coverage for inherited alignment, internal glyph alignment,
  empty controller targets, and rapid controller updates.
- Expanded the README API map and clarified layout, editable text, and example
  app behavior.
- Persisted the selected theme in the example app.

## 0.1.2

- Relaxed the Dart and Flutter SDK constraints to support Flutter 3.16.0 and
  newer, while keeping the current package implementation unchanged.
- Documented that the showcase example tracks current stable Flutter separately
  from the package compatibility floor.

## 0.1.1

- Fixed horizontal glyph clipping for heavy text styles in both rolling and
  settled states.
- Kept animated row sizing on the original interpolated-width behavior while
  giving individual glyph faces extra paint room.
- Added regression coverage for glyph paint bleed, bounded alignment, and
  selection-surface layout.

## 0.1.0

- Split internal implementation into focused Dart part files while preserving
  the public `package:reel_text/reel_text.dart` API.
- Implemented and documented `textAlign` support for fixed-width `ReelText`
  layouts, covering both settled and rolling glyph states.
- Tightened layout to match Flutter `Text` exactly for settled and rolling
  target strings without extra animation padding.
- Added SelectionArea support through a full-string selectable surface while
  keeping animated glyphs visual-only.
- Added `ReelText.rich` for styled `TextSpan` phrases that still roll and select
  as one plain-text run.
- Added `ReelText.sequence` for rotating labels without manually wiring a
  controller and timer.
- Added `ReelTextController.runWhile` for async waiting/success/failure labels.
- Added `ReelWaiting.scramble` for readable idle loops without custom frame
  generators.
- Added `ReelTextOptions` helpers for color modes and reversed direction.
- Added `ReelTextEditingController`, a `TextEditingController` subclass for
  animating inline replacements inside Flutter `EditableText` layouts.
- Added `ReelTextEditingController.animateReplacements(replacements: ...)` and
  `spanBuilder` to reduce subclass boilerplate for editable text integrations.
- Added tests and examples for adjacent extended emoji clusters, selection,
  exact text sizing, and an inline document editor demo for typo corrections.
- Upgraded the editor demo to use a `SpellCheckService` pipeline with
  LanguageTool, native platform spellcheck where available, and a deterministic
  multilingual fallback for tests and offline demo phrases.

## 0.0.1

- Initial Flutter `ReelText` widget.
- Added declarative and imperative controller APIs.
- Added `set`, `flash`, `ReelTextOptions`, `ReelTextFlashOptions`, and `chromatic`.
- Added `startWaiting` with `ReelWaiting` idle presets: `ellipsis`, `wave`,
  `frames`, and `builder`, each with designed motion defaults and an
  auto-derived steady frame cadence.
- The stagger cascade now runs across changed slots only, so tail-only diffs
  (counters, ellipsis dots) start instantly; incoming glyphs skip `exitOffset`
  when their slot was empty.
- Springy curves now render their overshoot (it was clamped flat before), so
  glyphs visibly settle with a bounce; `bounce` scales the overshoot depth.
- First settled frames now preserve full text-run advances instead of measuring
  isolated glyphs, avoiding broken startup letter spacing.
- Added reduced-motion support: `ReelText` snaps instantly when the platform
  disables animations (`respectDisableAnimations`).
- Added widget tests and a two-page studio example app (designed showcase +
  developer recipes with live previews and copy-ready code).
