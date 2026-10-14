# Pulse-centric plugin adoption

Status: documentation-only adoption plan, 2026-10-14. The target ownership below follows the Right Suite architecture decision. It does not claim that the new Pulse runtime, phone transport, voice conversation or shared task contracts have shipped. No app code, plugin executable, manifest or installation is changed by this document.

## Decision and boundaries

Keep `right-plugins` a distribution repository for Claude Code and Codex adapters. Pulse owns always-on tasks, routines, approvals, conversation, voice-session orchestration, model routing, budgets and multi-device coordination. RightKit owns shared typed contracts, CLI machinery, discovery, local IPC and authenticated network hosting. Each installed app engine remains authoritative for its own commands, data, validation, licensing and effects.

- An app plugin calls that installed app's supported CLI. It does not become an app engine, start a second scheduler or bypass the engine through its database or private files.
- The Pulse plugin adapts Pulse's supported command table. It does not run an always-on loop inside host hooks or equate Claude/Codex chat delivery with completion of a Pulse task.
- The ChatGPT MCP bridge is another adapter to the same typed contracts and admission path. It creates no second approval authority, task store, domain implementation or privileged command set. This repository currently contains Claude/Codex packages, not a ChatGPT bridge implementation; no new bridge package is needed here until its source owner and actual release exist.
- Pulse owns product policy; RightKit provides enforcement mechanisms; apps enforce domain constraints. Neither a plugin installation nor host hook trust grants permission to publish, spend, delete, link devices or expose data.
- Keep app plugins independently usable when Pulse orchestration is unnecessary. Do not require every local read-only app command to round-trip through Pulse or a remote server.

## Verified baseline

Audited `Orthic-Labs/right-plugins` main at `345318ad7041345760cafe418c135e1b42fdef9a`, rechecked through the recursive Git tree on 2026-10-14; `truncated=false`. The tree has no `AGENTS.md`, repository skills directory, generator implementation or test workflow. Its source instructions are the README and installer document.

1. [README](https://github.com/Orthic-Labs/right-plugins/blob/345318ad7041345760cafe418c135e1b42fdef9a/README.md) already defines skills over installed CLIs, separate app installation, and the `right-ax` generation/validation workflow. Plugins follow main rather than a release.
2. [SOURCES.json](https://github.com/Orthic-Labs/right-plugins/blob/345318ad7041345760cafe418c135e1b42fdef9a/SOURCES.json) records six copied packages: CutRight, GenRight, ScrapeRight, PostRight and separate Claude/Codex Pulse packages. All copied plugin versions are `0.1.0`; the recorded source commits are from October 11. PostRight has an explicit local edit removing a private documentation link. Legion is remote, Claude-only, version `0.3.23`, ref `main`, with unverified remote installation and a description waiver. Do not silently absorb or remove Legion as part of Pulse adoption.
3. [marketplace/plugins.json](https://github.com/Orthic-Labs/right-plugins/blob/345318ad7041345760cafe418c135e1b42fdef9a/marketplace/plugins.json) is the source list. `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` are generated outputs. The latter's `AVAILABLE`/`ON_INSTALL` fields are host installation/authentication policy, not approval to execute app effects.
4. The [Pulse skill](https://github.com/Orthic-Labs/right-plugins/blob/345318ad7041345760cafe418c135e1b42fdef9a/plugins/claude/pulse/skills/pulse-bridge/SKILL.md) describes SSH-linked chat forwarding, a 64 KiB message limit and 24-hour reply routes. Claude/Codex hooks run `pulse chat claude-hook` or `codex-hook` on `UserPromptSubmit`, `PostToolUse` and `Stop`, with ten-second timeouts. These are event adapters, not persistent workers. Shell launchers exit successfully if Pulse is absent; the PowerShell launcher exits zero even after invocation, so hook exit status is not a task receipt.
5. The copied Pulse skill says to treat `sent` as arrived and to resend an `unknown` message once. Its upstream source remains identical at Pulse `d6118f99d8de3c9cade8ff6b2588823675764c3f`. However, [Pulse PENDING](https://github.com/Orthic-Labs/pulse/blob/d6118f99d8de3c9cade8ff6b2588823675764c3f/PENDING.md) explicitly records that disappearing queue rows do not prove delivery, idle Codex chats wait for the owner's next prompt, and receipt repair has not started. Fix this disagreement at source before refreshing the distribution; never advertise supported idle wake from the current hooks.
6. [RightKit agent-tools](https://github.com/Orthic-Labs/rightkit/blob/32c490acb9c7953b0d0b952b1eeaf5bb81eef42c/crates/rightkit-agent-tools/README.md) already describes typed schemas, effect classes, exposure rules, caller allowlists, admission and journaling, plus `right-ctl`. This establishes a foundation, not proof that the distributed app CLIs use one identical wire format today.

## Necessary documentation and source changes

### 1. Add the ownership map without replacing working CLI instructions

Add this plan as `docs/pulse-agent-model-adoption-2026-10-14.md`; link it from the README's Maintainers section. Add a short target-direction note explaining the adapter boundary and current-versus-planned distinction. Keep existing install steps and app availability claims unchanged until verified releases exist.

Do not replace existing CLI examples with invented Pulse task subcommands or a generic `right-ctl` invocation. The current adapters differ materially:

- CutRight: one JSON document on stdout, readiness via `doctor`, mandatory dry runs for writes, revision cursor checks and optional `serve` sessions
- GenRight: `contract_version`, request-id deduplication, detached jobs, progress on stderr, job acknowledgement after assets are imported, and explicit unknown-paid-outcome recovery
- ScrapeRight: `cli_contract_version: 1` and `capability_version: 1`; JSON request mode differs from per-job output; `--help` is documented as unreliable
- PostRight: dotted commands, stored scopes, expected revisions and item-specific publishing/approval constraints

Preserve these contracts. Harmonization belongs to app owners using RightKit mechanisms, followed by adapter updates. A distribution-only normalization must not drop errors, revisions, approval requirements or partial results.

### 2. Correct Pulse guidance in the Pulse source repository

The Pulse owner changes `plugins/claude/pulse/` and `plugins/codex/pulse/` together, retaining host-specific manifest and hook differences. Necessary source documentation changes:

- Separate legacy chat message transport from future Pulse task submission/status/cancellation. Document only commands supported by the installed release.
- Describe queue acceptance, recipient acknowledgement and task completion separately. `sent`, exit zero, a vanished queue row, or hook return never independently proves recipient delivery or task success.
- For an unknown legacy delivery outcome, inspect supported status/inbox evidence and report uncertainty; do not automatically resend on the basis of identical text. Permit automatic retry only when a supported stable idempotency key prevents duplicate effects.
- State that idle Codex wake is unsupported in the audited version. Never work around host trust checks by changing ancestry, signing identity, trust files or unofficial forwarding paths.
- Keep incoming agent text untrusted and without authority to change permissions. Carry source provenance as data, never as a user-authored instruction.

Future task-contract documentation must identify request/task/job/message IDs separately, target device and engine, schema/contract version, effect and scope, approval reference, idempotency key, durable outcome and artifact references. Those field names are requirements for the owning contract design, not claims about current CLI flags. Adapters preserve the engine's original receipt and correlate it to the Pulse task; they do not manufacture a success state.

Cancellation must distinguish request accepted, work actually cancelled, already completed, unsupported and outcome unknown. A disconnected or timed-out caller does not prove cancellation. Never equate cancellation with undo, recall of a published post, refund of a paid generation or deletion of produced assets. Expose cancellation only where the engine supports and qualifies it.

### 3. Preserve permission and privacy semantics

Every adapter invokes the same typed, scoped command and enforcement path as another surface. Authentication, installation, hook trust, tool exposure and action approval remain distinct. A broader host permission cannot widen an app's capability set or substitute for an engine approval requirement. Approvals must bind the action, target, material arguments and expiry; changing device, recipient, cost or payload requires policy re-evaluation, not reuse of a general chat approval.

Keep current stronger app safeguards: GenRight per-run spend/upload approval and unknown-outcome hold; PostRight exact-item approval, revision checks, gate policy and Reddit draft-only limit; CutRight project mutation through the engine and cursor conflict checks; ScrapeRight licensing and credential isolation. Do not silently weaken them to match a generic effect label. Resolve any proposed policy change in the owning app and shared contract first.

The plugin must never ingest HeardRight dictation/history/pasteboard to infer user authority. RightKit currently hard-excludes those tool families. A future HeardRight-to-Pulse conversational handoff must be explicitly scoped in those owners' contracts; it is not permission to add an unrestricted speech or input plugin here. Secrets stay in app/RightKit secret ownership; no credentials in skill text, receipt logs or copied source metadata.

Retain [installer rules](https://github.com/Orthic-Labs/right-plugins/blob/345318ad7041345760cafe418c135e1b42fdef9a/docs/INSTALLER-BUNDLING.md): explicit user connection action, no silent config writes, no fabricated hook trust, preserve user-owned configuration, owned-file-only uninstall and no re-registration after removal. A bundled local marketplace is currently proposed, not qualification evidence. Revise the claim that bundling alone prevents drift: host caches and independent app/plugin updates still require a compatibility check.

### 4. Make distribution provenance and compatibility enforceable

Keep `SOURCES.json` as the copy ledger. Copy only committed app-source plugin trees. For each refresh record source repository, exact source commit/path, plugin version, copy date and all approved distribution transformations. Preserve the existing PostRight exception explicitly or upstream it; never silently erase it. Record the generator version and source-list digest in release evidence, and verify copied tree hashes after declared transformations.

Keep plugin package version, engine/app version, CLI contract version and host compatibility separate. Bump the plugin version for changed behavior or instructions; record the tested app release/contract range and tested Claude/Codex version/platform in release evidence. Reject unsupported contract majors before effects; missing version metadata means unqualified compatibility, not permission to guess. Probe using the actual supported `doctor`/version command for each app, not a universal flag. New optional capabilities remain unavailable until positively advertised and tested.

Prefer a tested immutable distribution release or installer-matched bundle over floating main for stable users. Document rollback to a known-compatible plugin/app pair. Do not invent host pinning syntax: verify each host's supported install/update mechanism before prescribing it. Existing floating-main users need a truthful warning until a qualified release channel exists.

After source packages and source-list metadata are approved, run the repository-prescribed `right-ax marketplace build` and `right-ax marketplace validate --workspace .` using a recorded compatible `right-ax` version (README requires at least 0.3.2 for the Claude local-source form). Never hand-edit generated marketplace manifests. Proposed compatibility/provenance metadata must use a supported schema or a separate documented release record; do not inject unknown fields into host manifests or silently change schema version 1.

## Rollout and acceptance gates

1. **Documentation gate:** approve ownership and receipt semantics in Pulse/RightKit; record current limitations here. Documentation publication does not lift implementation holds or authorize app installation, deployment, linking or real-user effects.
2. **Source gate:** app owners implement and document the minimum contracts, update source plugins and bump package versions. Pulse's hook changes require Pulse review. RightKit owns shared schema/admission changes; `right-plugins` owns copying, marketplace integrity and install documentation.
3. **Distribution gate:** verify source commits and transformed hashes; regenerate both manifests; validate drift, package versions, paths and skill descriptions. Keep Legion's existing exception separately visible. Do not claim it is tested or integrated into Pulse authority.
4. **Qualification gate:** run installed-release journeys for Claude Code and Codex on macOS and Windows, each with the recorded host/app/plugin tuple. Test app absent, unsupported contract, user trust declined, update/cache refresh, duplicate marketplace/loose-file installation, uninstall and user-config preservation. Use isolated fixtures, not user data.
5. **Behavior gate:** compare direct CLI, plugin and available ChatGPT adapter results against the same engine command, scope and approval. Require matching refusal semantics and durable receipts. Cover queued versus acknowledged delivery, idle recipient, stale/offline device, duplicate submission, restart after acceptance, timeout with a still-running job, cancel/completion races, revoked approval, revision conflict, unknown paid outcome and result import before acknowledgement. No claimed exactly-once effect without verified deduplication at the effect owner.
6. **Release gate:** publish only adapter capabilities supported by qualified installed releases. Record pass/fail/unsupported per platform and host; do not treat manifest validation as runtime qualification. Keep the previous known-compatible package available. If regression occurs, disable the new exposure and restore compatible guidance without erasing receipts, jobs or source provenance.

Success means an agent selects the right installed engine, preserves consent and domain safeguards, reports actual outcomes, and recovers without duplicate effects. It does not mean a new orchestration runtime has been embedded into a skill. This audit ran no builds, tests, installer journeys or generator commands; all gates above remain future implementation/release work.

## Related architecture plans

- [rightkit](https://github.com/Orthic-Labs/rightkit/blob/docs/pulse-agent-model-adoption-2026-10-14/docs/pulse-agent-model-adoption-2026-10-14.md)
- [pulse](https://github.com/Orthic-Labs/pulse/blob/docs/pulse-agent-model-adoption-2026-10-14/docs/pulse-agent-model-adoption-2026-10-14.md)
