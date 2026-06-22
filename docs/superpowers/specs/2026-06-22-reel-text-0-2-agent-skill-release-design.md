# Reel Text 0.2 Agent Skill Release Design

## Goal

Release `reel_text` `0.2.0` as an ecosystem release centered on the optional
`reel_text-usage` agent skill, with no runtime API or behavior changes.

## Scope

This release validates and documents the package skill that helps AI coding
agents decide when `reel_text` is appropriate, choose the narrowest API, and
reject decorative or broad text animation requests.

In scope:

- Replace the unresolved pressure-test note in `skills/reel_text-usage/SKILL.md`
  with concrete evidence from the documented pressure scenarios.
- Verify that the Dart `skills` CLI can discover the local package skill from a
  Flutter project that depends on this checkout.
- Update `CHANGELOG.md` with a `0.2.0` entry that states the skill, docs, and
  package-archive changes clearly.
- Bump `pubspec.yaml` from `0.1.6` to `0.2.0`.
- Run root/package verification and `dart pub publish --dry-run`.

Out of scope:

- Runtime API changes.
- Layout-stability helper APIs.
- Example UI redesigns.
- Publishing to pub.dev.

## Release Positioning

`0.2.0` is justified as a minor release because the package gains a new
integration surface: an optional agent skill distributed with the package.
The changelog must avoid implying that `ReelText` runtime behavior changed.

## Verification

Readiness requires:

- Pressure-scenario evidence recorded in the skill file.
- `skills get reel_text` verified against a temporary Flutter app using the
  local checkout as a path dependency.
- `flutter analyze`.
- `flutter test` in the package root.
- `flutter test` in `example/`.
- `dart pub publish --dry-run`.
