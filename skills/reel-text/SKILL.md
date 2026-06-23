---
name: reel-text
description: "Use when adding, reviewing, or refactoring Flutter UI that may use reel_text for compact rolling text: command feedback, async/status labels, counters, rotating short phrases, styled TextSpan phrases, WidgetSpan inline anchors, or editable inline corrections. Also use when deciding whether plain Text is better or installing reel_text."
---

# Reel Text

## Principle

Use motion to clarify a state transition. Do not use motion to make static text more interesting.

`reel_text` is for short, high-signal Flutter text whose change carries meaning: commands, status, counters, rotating labels, styled inline phrases, anchored inline widgets, and editable corrections. Keep ordinary reading content in Flutter `Text`.

## Decision Workflow

1. Audit candidate text before installing or editing code.
2. Keep only short text that changes because of user action, async state, numeric change, rotation, or inline correction.
3. Reject decorative use. If the transition does not explain state, keep `Text`.
4. Pick the narrowest `reel_text` API for the interaction.
5. Preserve layout, semantics, reduced motion, and controller lifecycle.
6. Verify with Flutter analysis/tests and a UI pass when practical.

## Agent Output Contract

Before editing, state the accepted candidate transition and the API choice. If no candidate qualifies, say that plain `Text` is the correct choice and stop.

For code changes, report:

- The text transition being animated.
- The API chosen and why.
- How the dependency was added or confirmed.
- The layout constraint that prevents size jumps.
- The lifecycle owner for any controller.
- The verification command run.

## Install

For an app that does not already depend on the package:

```bash
flutter pub add reel_text
```

If `pubspec.yaml` is carefully grouped, commented, sorted, or otherwise hand-structured, do not let a command rewrite it blindly. Run `flutter pub add reel_text --dry-run` to see the default compatible constraint without editing files, then add `reel_text: <constraint>` under `dependencies` by hand and run `flutter pub get`. If dry-run cannot resolve the package, look up the current compatible constraint from pub.dev. Do not copy a hardcoded version from this skill.

Then import:

```dart
import 'package:reel_text/reel_text.dart';
```

Do not add the dependency just because the task mentions animation. First find a good candidate transition.

## Source Lookup

Before guessing APIs, inspect the package source available to the project:

- If the project already ran `flutter pub get`, read `.dart_tool/package_config.json` and use the `reel_text` `rootUri`/`packageUri` to find `lib/`.
- If package config is unavailable, check `${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/reel_text-<version>/lib/`.
- If working inside this repository, use the local `lib/` source.

Use cached source as the API reference when docs and installed version may differ.

## Reject Plainly

Keep Flutter `Text` for:

- Paragraphs, body copy, legal text, help text, and long error messages.
- Static labels, titles, navigation items, and captions that do not change.
- Text that wraps or needs multi-line reading continuity.
- `WidgetSpan` children that need their own glyph-level rolling animation. `ReelText.rich` can keep widgets anchored inline, but only surrounding `TextSpan` text rolls.
- Connected scripts or complex typography unless the exact text is tested in context.
- Any request that effectively says "animate all text" without stateful meaning.

When rejecting, explain the smaller useful target instead of applying the package broadly.

## API Choice

| Interaction | Use |
| --- | --- |
| Simple rebuild from one short string to another | `ReelText('Copy')` |
| Styled inline phrase or anchored inline widget | `ReelText.rich(TextSpan(...))` |
| Imperative label owned by widget state | `ReelTextController` with `ReelText.controller` |
| Temporary button feedback such as `Copy -> Copied -> Copy` | `ReelTextController.flash()` |
| Async waiting, success, and failure labels | `ReelTextController.runWhile()` |
| Manual waiting or progress loops | `startWaiting()` or `startProgress()` |
| Passive rotating short labels | `ReelText.sequence` |
| Inline text-field corrections | `ReelTextEditingController` and `ReelTextEditReplacement` |

## Implementation Patterns

Own imperative controllers in widget state:

```dart
class _CopyButtonState extends State<CopyButton> {
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
    return FilledButton(
      onPressed: () => _label.flash('Copied'),
      child: ClipRect(
        child: SizedBox(
          width: 64,
          child: Center(child: ReelText.controller(controller: _label)),
        ),
      ),
    );
  }
}
```

Tie async labels to the operation that owns them:

```dart
await label.runWhile(
  saveDraft,
  waiting: 'Saving',
  success: 'Saved',
  failure: 'Failed',
);
```

## Implementation Rules

- Create `ReelTextController` and `ReelTextEditingController` in widget state, not inside `build`. Dispose them.
- Use `flash()` for temporary command feedback. Use `set()` for a persistent new label.
- Use `runWhile()` when the label lifecycle follows a `Future`; remember it rethrows failures after showing the failure label.
- For buttons, chips, and compact controls, reserve a stable motion slot with layout constraints such as `SizedBox`, `ConstrainedBox`, or `ClipRect` so the control does not jump.
- Keep outer button semantics clear. Add `semanticsLabel` when the rolling text needs a custom spoken value.
- For `WidgetSpan` rich text, treat the widget as an anchored inline child. Animate the surrounding `TextSpan` text; use `semanticsLabel` when the widget contributes meaning that is not already in the text.
- Keep `respectDisableAnimations` at its default `true` unless the user explicitly asks to ignore reduced motion.
- Use `Directionality` or `textDirection` when the label is outside an already directional subtree.
- Preload async fonts before the first `ReelText` frame when the app relies on dynamically loaded fonts.
- Validate `ReelTextEditReplacement` ranges; they must be in bounds and non-overlapping.
- Preserve existing `pubspec.yaml` comments, grouping, ordering, and constraints when adding `reel_text`; do not normalize unrelated dependencies.

## Red Flags

- Replacing many unrelated `Text` widgets in one pass.
- Creating any `ReelTextController` inside `build`.
- Adding `reel_text` to a project before identifying a qualifying transition.
- Rewriting a carefully structured `pubspec.yaml` just to add one dependency.
- Inventing API calls without checking local source or the pub cache when the package is installed.
- Animating body copy, long errors, legal/help text, or static navigation labels.
- Putting a rolling label in a button without a stable slot width.
- Reimplementing waiting timers when `runWhile()` or `startWaiting()` matches the lifecycle.

## Pressure Scenarios

- "Make the app text animated" -> reject broad replacement, then identify one or two stateful labels where motion clarifies the transition.
- "Add feedback to a copy button" -> use `ReelTextController.flash()` in a fixed label slot.
- "Show export progress" -> use `runWhile()` or `startWaiting()` depending on whether one `Future` owns the lifecycle.
- "Animate a hero paragraph" -> keep `Text`; consider only a short rotating word or action label.
- "Animate spellcheck corrections in a field" -> use `ReelTextEditingController`, not an overlay outside `EditableText`.
- "Support RTL/mixed bidi labels" -> use `Directionality`/`textDirection` and verify visual order in context.
- "Add an inline status icon or badge to rich text" -> use `ReelText.rich` with `WidgetSpan`; keep the widget anchored and verify the surrounding text rolls without layout jumps.

## Pressure Test Evidence

Recorded on 2026-06-23 for the `0.3.0` package release. This combines a manual pressure review against the skill contract and the current `npx skills` install flow.

Install the bundled skill from the GitHub repository with:

```bash
npx skills add KickNext/reel_text --skill reel-text --agent universal --yes
```

Scenario outcomes:

- "Make the app text animated" -> reject broad replacement; only consider one or two short stateful labels where a change communicates state.
- "Add feedback to a copy button" -> choose `ReelTextController.flash()` with a state-owned controller, `dispose()`, and a fixed `SizedBox`/`ClipRect` label slot.
- "Show export progress" -> choose `runWhile()` only when one `Future` owns the lifecycle; otherwise choose `startWaiting()` or `startProgress()` and resolve the returned handle.
- "Animate a hero paragraph" -> keep the paragraph as plain `Text`; consider only a short rotating word or action label if it has stateful meaning.
- "Animate spellcheck corrections in a field" -> choose `ReelTextEditingController` and validated `ReelTextEditReplacement` ranges, not an overlay outside `EditableText`.
- "Support RTL/mixed bidi labels" -> require `Directionality` or `textDirection`, then verify visual order in context.
- "Add a badge inside styled rich text" -> choose `ReelText.rich` with a `WidgetSpan` anchor; verify the widget stays inline while adjacent text rolls.

CLI install evidence:

- Created a temporary install directory.
- Ran `npx skills add KickNext/reel_text --skill reel-text --agent universal --yes`.
- The CLI found one skill and installed `reel-text` into `./.agents/skills/reel-text` using the universal Agent Skills layout.

Release note: this evidence validates the optional agent skill install path. It does not indicate runtime API or widget behavior changes.

## Verification

- Run `flutter analyze`.
- Run relevant widget tests or add focused tests for controller lifecycle, state changes, layout stability, or reduced motion when the change is risky.
- Inspect the changed UI when practical: the text should stay short, the container should not jump, semantics should remain correct, and reduced-motion users should get an instant snap.
