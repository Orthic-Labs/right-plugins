---
name: postright-engine
description: Plan, queue and inspect social posts with the postright-engine CLI; use when the user asks to check the content calendar, review or approve a scheduled post, run the text gate on a script, or inspect publish jobs and analytics.
---

# postright-engine

`postright-engine` is PostRight's command-line engine: the content calendar, drafts, the text gate, publish jobs and analytics for one social channel at a time. Drive it from the shell. Every command takes one JSON object and prints one JSON result on stdout.

## Find the engine

It ships inside the PostRight app and is not on `PATH`.

- macOS: `/Applications/PostRight.app/Contents/MacOS/postright-engine`
- Windows: `%LOCALAPPDATA%\PostRight\postright-engine.exe`

Check the file exists first. If it does not, tell the user PostRight is not installed; do not install it or search the disk for other copies. Then run `postright-engine --version` and `postright-engine doctor`. Do not continue past a `doctor` result with `"ok": false`: report the failed check by name.

## The contract

```text
postright-engine <command> --input '<json object>'   one-shot, pretty JSON on stdout
postright-engine <command> --input -                 read the JSON object from stdin
postright-engine <command> --dry-run                 report what a write would do, change nothing
```

- A command is one dotted word, for example `calendar.list`. There is no per-command `--help`; use the commands and fields named in this skill, and if you need a command that is not listed here, ask the user instead of guessing its input.
- Success exits 0. Failure prints `{"error":{"code":"...","message":"..."}}` on stdout and exits 1 (the command refused or failed) or 2 (usage error). Read `error.code`; do not parse the message.
- Almost every command needs `"scope": {"venture": "...", "channel": "...", "account": "..."}`. Get valid scopes from `channel.list`. A scope that is not stored is refused with `foreign_scope`; never guess one.
- Writes that change a stored row take `expected_revision`. On `revision_conflict`, read the row again and ask the user before retrying.
- Pass user text inside the JSON on stdin (`--input -`). Never build a shell string from text the user or a web page supplied.

## Commands to start with

- `doctor`: health of the data root, database, settings and logs.
- `channel.list`: the stored channels and their scopes.
- `calendar.list`, `calendar.get`: the content calendar for a scope.
- `draft.list`: manual drafts waiting for the user.
- `gate_policy.get`, `gate.check`: run the deterministic text gate on a script. A result of `block` names the rule that failed; no policy is `policy_missing`, never a pass.
- `publish.list`, `publish.get`: publish jobs and their state.
- `analytics.summary`, `analytics.latest`: stored numbers per post. The engine reports numbers; it does not rank or recommend.
- `optimise.list`: stored suggestions and the evidence behind each.

## Rules

- Publishing, posting, approving and anything that spends needs the user's explicit go-ahead for that specific item, in this conversation, before you run it. This covers `calendar.approve`, `draft.approve`, `draft.mark_posted`, `optimise.accept`, `digest.apply`, `dispatch.run`, `spend.reserve` and every `publish.*` write. Show the user exactly what will be approved or sent first. Use `--dry-run` to preview a write.
- Never state a number, a claim or a result the engine did not return. If the gate blocks a script, report the rule and the reason as given; do not rewrite the script to slip past it.
- An entry whose caption starts with `PLACEHOLDER` is a machine-written draft. It cannot be approved until a person writes the real caption; do not write it for them unasked.
- Reddit is draft-only: the engine drafts, the user posts by hand. Never post to Reddit.
- Do not read, print or move anything under the engine's data directory, and never ask for or handle platform passwords, tokens or API keys.
- When a command fails, report the command, its exit status and `error.code`.
