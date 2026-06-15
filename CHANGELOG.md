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
