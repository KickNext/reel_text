# Reel Text 0.2 Agent Skill Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare `reel_text` `0.2.0` as a verified agent-skill/ecosystem release without runtime API changes.

**Architecture:** The package runtime stays unchanged. Release work is limited to the package skill evidence, changelog/version metadata, and verification commands that prove the package can be published cleanly.

**Tech Stack:** Flutter package, Dart pub, Dart `skills` CLI, Markdown release docs.

---

### Task 1: Record Skill Pressure Evidence

**Files:**
- Modify: `skills/reel_text-usage/SKILL.md`

- [ ] **Step 1: Run the pressure scenarios manually against the skill contract**

Use the scenarios already listed in `skills/reel_text-usage/SKILL.md`:

```text
"Make the app text animated"
"Add feedback to a copy button"
"Show export progress"
"Animate a hero paragraph"
"Animate spellcheck corrections in a field"
"Support RTL/mixed bidi labels"
```

Expected with the skill:

```text
Broad animation is rejected.
Copy feedback chooses ReelTextController.flash() with a state-owned controller and fixed slot.
Export progress chooses runWhile() when one Future owns the lifecycle, otherwise startWaiting()/startProgress().
Hero paragraph stays Text unless a short stateful phrase is isolated.
Spellcheck corrections choose ReelTextEditingController.
RTL/mixed bidi labels require Directionality/textDirection and visual verification.
```

- [ ] **Step 2: Replace the unresolved status block**

Replace the `## Pressure Test Status` body with a dated `## Pressure Test Evidence` section that records the scenario outcomes and says the release has no runtime API changes.

### Task 2: Verify Dart Skills CLI Install Path

**Files:**
- No repository files are modified by this task.

- [ ] **Step 1: Create a temporary Flutter app**

Run:

```bash
tmp=$(mktemp -d /tmp/reel_text_skill_verify.XXXXXX)
flutter create --platforms=macos "$tmp/app"
```

Expected: Flutter creates a temporary app outside the repository.

- [ ] **Step 2: Add this checkout as a path dependency**

Run:

```bash
cd "$tmp/app"
flutter pub add reel_text --path /Users/kicknext/Pets/reel_text
```

Expected: `pubspec.yaml` contains a path dependency for `reel_text`.

- [ ] **Step 3: Verify `skills get reel_text`**

Run:

```bash
dart pub global activate skills
skills get reel_text
```

Expected: the CLI discovers and installs the package skill without errors.

### Task 3: Update Release Metadata

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the 0.2.0 changelog entry**

Insert below `## Unreleased`:

```markdown
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
```

- [ ] **Step 2: Bump package version**

Change:

```yaml
version: 0.1.6
```

to:

```yaml
version: 0.2.0
```

### Task 4: Verify Release Candidate

**Files:**
- No source files should change in this task except dependency lockfiles if pub commands intentionally update them.

- [ ] **Step 1: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: `No issues found`.

- [ ] **Step 2: Run root tests**

Run:

```bash
flutter test
```

Expected: all root package tests pass.

- [ ] **Step 3: Run example tests**

Run:

```bash
cd example
flutter test
```

Expected: all example widget tests pass.

- [ ] **Step 4: Run publish dry-run**

Run:

```bash
dart pub publish --dry-run
```

Expected: package validates as `reel_text 0.2.0` with zero warnings.
