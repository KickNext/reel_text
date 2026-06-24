## 0.4.0

- Reworked plain rolling text slots to paint through cached render objects,
  reducing per-frame widget rebuild work for dense `ReelText` scenes.
- Added a full-screen performance stress screen to the example app with theme
  support and adjustable tile density.
- Fixed RTL rolling slot alignment while animated slot widths change.
- Added intrinsic/dry layout support for painted rolling slots and disposed
  transient/cached `TextPainter` resources used by the optimized paint path.
- No public API changes.

## 0.3.0

- Added `WidgetSpan` support to `ReelText.rich`: inline widgets now stay in the
  reel row while neighboring text spans keep rolling.
- Reworked the internal roll planner around a shared measured token pipeline for
  text glyphs and widget placeholders.
- Added regression coverage for RTL and mixed-bidi widget spans, keyed widget
  reorders, interrupted rich updates, selection sizing, and late placeholder
  measurement.
- Split the example recipe shell and preview widgets into smaller files.
- No public API changes.

## 0.2.1

- Renamed the optional agent skill to the spec-compliant `reel-text`
  name and matching folder.
- Switched skill install docs and the example copy command to the
  `npx skills add ... --agent universal` flow used by the official Flutter and
  Dart skill repositories.
- Restored full-height tap targets for the example install copy buttons.

## 0.2.0

- Added the optional `reel_text-usage` AI agent skill for choosing meaningful
  short text transitions, rejecting broad decorative animation requests, and
  selecting the narrowest `reel_text` API.
- Documented installation through the Dart `skills` CLI and verified the local
  path-dependency install flow.
- Recorded pressure-scenario evidence for copy feedback, async labels, hero
  text, editable corrections, and RTL/mixed-bidi guidance.
- Moved example app details out of the root README and kept the publish archive
  small by excluding generated platform scaffolds and the root hero asset.
- No runtime API changes.

## 0.1.6

- Added visual-order glyph layout for RTL and mixed-bidi labels while keeping
  the existing roll width and alignment model.
- Built bidi rolls from visual-order slots, aligned from the inline end for RTL,
  so stable glyphs do not need a separate horizontal correction phase.
- Added regression coverage and a mixed-bidi example recipe for visual checks.

## 0.1.5

- Corrected the 0.1.4 changelog to remove a mixed-bidi fix claim for
  visual-order work that was reverted before release.
- No runtime changes.

## 0.1.4

- Added accessibility guideline coverage for the example app across desktop and
  mobile Home, Recipes, and Editor layouts.
- Improved example tap targets, semantic labels, and text-scale resilience for
  top navigation, metadata links, recipe controls, and editor controls.
- Made `ReelText.rich` respect nested `TextSpan.semanticsLabel` values unless a
  widget-level `semanticsLabel` override is provided.
- Added locale and RTL alignment regression coverage.
- Added an example RTL script recipe for visually checking right-to-left rolls.

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
