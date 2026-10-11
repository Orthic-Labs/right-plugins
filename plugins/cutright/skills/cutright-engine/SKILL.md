---
name: cutright-engine
description: Edit video projects from the command line with the cutright-engine CLI; use when the user asks to cut or trim a video, render or export an edit, apply an edit plan, or deliver a video from a content brief.
---

# cutright-engine

`cutright-engine` is the command-line engine inside the CutRight desktop app. It edits video projects without the app window: create a project, register media, apply timeline edits, apply reviewed edit plans, render, and deliver a video from a content brief. Drive it from the shell with the Bash tool.

## Find the installed engine

Use the engine inside the installed app, never one from a source checkout or a build folder.

- macOS: `/Applications/CutRight.app/Contents/MacOS/cutright-engine`
- Windows: `%LOCALAPPDATA%\CutRight\cutright-engine.exe`

The engine is not on `PATH`. Check the file exists first. If it does not, tell the user CutRight is not installed; do not install it and do not look for another copy. Then run `cutright-engine doctor`: it prints a JSON health report and exits 1 when a required check fails. Stop and report the failing check if `readiness.status` is not `ready`.

In the examples below `cutright-engine` stands for that full path.

## Output contract

- Every command prints one JSON document on stdout and exits 0 on success.
- On failure it exits non-zero and prints `{"error":{"code":"...","message":"..."}}`, also on stdout. Branch on `error.code` (for example `not_a_project`, `bad_input`, `cursor_mismatch`, `render_timeout`); show `error.message` to the user.
- Parse the JSON; do not scrape text. Field names are part of the contract.
- Learn flags from the binary, not from memory: `cutright-engine --help`, then `cutright-engine <command> --help`.

## The dry-run rule

`--dry-run` is a global flag: the command reports what it would do and changes nothing. Before any command that changes a project or writes a file (`project init`, `source add`, `edit`, `undo`, `redo`, `render`, `plan apply`, `plan rollback`, `brief run`), run it once with `--dry-run`, check the reply is what the user asked for, then run it for real. `doctor`, `apps`, `project show`, `plan check`, `plan history` and `brief check` never write.

## Commands

- `cutright-engine doctor`: health report (data folder, bundled ffmpeg, readiness).
- `cutright-engine apps`: other installed Orthic Labs apps and whether their engines answer.
- `cutright-engine project init <dir> [--fps 30] [--name <name>]`: create a project folder (safe to repeat with the same fps).
- `cutright-engine project show <dir>`: timeline summary and the revision cursor. Read the cursor before editing.
- `cutright-engine source add <dir> <file> [--reference]`: hash, probe and register a media file; `--reference` leaves the file where it is instead of copying it into the project.
- `cutright-engine edit <dir> --action '<json>' [--expect-cursor <n>]`: apply one timeline action. Pass `--expect-cursor` with the cursor you read, so a retry cannot apply the edit twice; a `cursor_mismatch` error means the project changed and you must read it again.
- `cutright-engine undo <dir>` / `cutright-engine redo <dir>`: step one revision back or forward.
- `cutright-engine render <dir> --preset <youtube|reels|tiktok|square> [--out <name>] [--encoder auto] [--timeout-secs <n>]`: render the timeline to `renders/<name>.mp4`. Leave the encoder on `auto`.
- `cutright-engine plan check --project <dir> --input <plan.json>`: validate an edit plan against the current revision; writes nothing.
- `cutright-engine plan apply --project <dir> --input <plan.json> [--expect-cursor <n>]`: apply a whole plan as one undoable step.
- `cutright-engine plan history --project <dir>` and `cutright-engine plan rollback --project <dir> --input <plan.json>`: list applied plans, or undo one as a single step.
- `cutright-engine brief check --input <brief.json>`: validate a RightKit content brief and print the renders it would make; writes nothing.
- `cutright-engine brief run --project <dir> --input <brief.json> [--timeout-secs <n>]`: render, quality-check and deliver the brief's video. The reply lists each deliverable with its output file, its delivery envelope and its export manifest under `exports/manifests/`. A deliverable whose quality check fails gets a manifest but no envelope.
- `cutright-engine serve`: a long-lived session that reads one JSON request per line on stdin and writes replies and progress events on stdout. Use it only when you need many calls or progress events; for single operations use the commands above.

## Rules

- Never edit the files inside a project folder by hand; every change goes through a command so it stays undoable.
- A render can take minutes. Do not start a second render of the same project while one runs.
- Pass user text and paths as separate arguments; never build a shell string from untrusted text.
- When something fails, report the command you ran, the exit status and `error.code`.
