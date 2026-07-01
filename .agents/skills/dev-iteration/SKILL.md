---
name: dev-iteration
description: |
  Structured loop for turning a curated feedback document into verified,
  committed code changes. Use when the user says things like "address the
  feedback in <file>", "work through docs/.../feedback.md", "fix these review
  items", "new iteration <N>", or when iterating on a bug the user keeps
  reporting as "still broken". Emphasizes rebuild-for-testing, root-cause
  diagnosis before re-implementing, clean reverts of dead ends, and focused
  per-item commits.
---

# Dev Iteration Loop

Drive a feedback → addressing → verification loop that keeps the working tree
clean, isolates root causes before large fixes, and produces small, reviewable
commits. The outcome is each feedback item verified by the user and committed
(or cleanly reverted), with the feedback document updated to reflect status.

## Workflow

### Step 0: Kick off a new iteration (when asked for "new iteration <N>")
- Scaffold `docs/iteration-<N>/feedback.md` (mirror the previous iteration's
  structure/template) so there's a place to record items. Add an `assets/` dir
  when screenshots arrive.
- Rebuild the distributable and relaunch a fresh build (see Step 3) so the user
  tests the current code, not a stale bundle.
- Then **collect feedback interactively with `askFollowupQuestion`** rather than
  passively waiting — ask the user what they want to change, offering concrete
  options (e.g. new bug, UI tweak, "everything works", or paste a list).
- **CRITICAL: Recording feedback is a strictly isolated phase from implementing or researching. While collecting/recording feedback, you MUST NOT read code, search files, investigate the codebase, or make any code changes. Your sole task is to transcribe the user's report clearly and fluently into `feedback.md` describing only the user's issue, its visual or functional impact, and any attached screenshots. You MUST NOT include any code, file paths, file names, programming languages, API names, implementation details, or proposed code fixes in the feedback document at this stage. The feedback document must solely describe the user's experience, the observed issue, and user-provided assets/screenshots. Keep gathering items until the user explicitly signals they're done and asks you to start addressing them.**
- Defer ALL code investigation, searching, and implementation to Step 2, and only begin once the user asks you to address the recorded items.

### Step 1: Enumerate the feedback
- Read the feedback document in full. Extract a numbered list of concrete items,
  each with: problem, impacted files, and any proposed solution/asset references.
- Restate the list back so scope is explicit before touching code.

### Step 2: Address items independently
- Treat each feedback item as a separable unit so it can be committed or reverted
  on its own. Avoid entangling unrelated items in the same edit.
- After each change, run the project build (e.g. `swift build`, `npm run build`,
  `cargo build`) and fix compile errors before moving on.

### Step 3: Rebuild the distributable before asking the user to test
- Honor project rules in `AGENTS.md` / `CONTRIBUTING`. For this repo that means
  running `Scripts/build_app.sh` to produce `dist/`, then relaunching a fresh
  build, e.g.:
  `pkill -x <AppName> 2>/dev/null; sleep 1; open "dist/<App>.app"`
- Never ask the user to test a stale bundle — always rebuild + relaunch so they
  exercise the current code.

### Step 4: When a fix doesn't work, diagnose before re-implementing
- If the user reports "still broken" after a rebuild, STOP guessing. Do NOT stack
  more speculative fixes.
- Design a minimal / zero-code experiment that isolates the root cause — ideally
  by comparing the broken behavior against a **known-working analogous feature**
  in the same app (e.g. "the Library window fronts, does Preferences?"). Ask the
  user to run that one comparison and report the result.
- Let the experiment's outcome pick the fix. Only implement once the root cause
  is confirmed, then reuse the proven-working pattern rather than inventing a new
  mechanism.

### Step 5: Revert dead ends cleanly
- When an approach is abandoned, revert just those files to `HEAD` with
  `git checkout HEAD -- <files>` (verify each file contains ONLY that item's
  changes first). Keep the working items intact.
- Also revert any doc "Resolved" notes tied to the reverted items.

### Step 6: Commit working items in focused commits
- Only commit when the user confirms an item works (or explicitly asks).
- Stage specific files by name (never `git add -A`); keep unrelated files (e.g.
  new tooling scripts, `AGENTS.md`) out of the feature commit.
- Group related items into one focused commit; separate unrelated concerns into
  separate commits. Write a "why"-focused message.

### Step 7: Update the feedback document
- Mark each verified item as resolved (e.g. add a `✅ Resolved:` note describing
  the actual root cause and the fix), and commit it with the code change.

## Notes
- Use `askFollowupQuestion` to confirm direction before large experiments or
  reverts, and to decide whether to checkpoint working changes with a commit
  first.
- Prefer reusing an existing, proven pattern in the codebase over novel
  mechanisms — it's both lower-risk and self-documenting.
- Record the confirmed root cause in the commit/feedback note so future readers
  understand *why*, not just *what*.
- Keep the working tree understandable at every step: one logical change per
  commit, dead ends reverted rather than left behind.
