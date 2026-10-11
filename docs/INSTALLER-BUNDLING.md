# Shipping a plugin inside an app installer

Question: can each app's dmg/exe carry its plugin and register it for the user's agents?

Short answer: yes for putting the files on disk and for registering them after the user's click; no for registering silently.

## Evidence: how Pulse does it today

Pulse (`/pulse`) gives two working routes:

1. Marketplace route, typed by the user. `claude plugin marketplace add <repo or local checkout path>` then `claude plugin install pulse@pulse-plugins`; Codex `codex plugin marketplace add <repo or path>`, then install from Plugins and trust the hooks with `/hooks` (`docs/bridge.md`, "Plugins"). A local path is accepted in both hosts, so the marketplace can be a folder on disk.
2. Loose files, written by the app's own command. `pulse chat install` (core/src/bridge/install.rs) writes the skill to `<CLAUDE_CONFIG_DIR or ~/.claude>/skills/pulse-bridge/SKILL.md` and `<CODEX_HOME or ~/.codex>/skills/pulse-bridge/SKILL.md`, merges three hook entries into `<codex home>/hooks.json`, skips a host whose config folder does not exist, writes atomically and idempotently, records version and content hash in `.pulse-bridge.json`, backs up a file it did not write, supports `--dry-run`, and has an `uninstall` that removes only what it wrote. It never writes Codex trust state or `config.toml`.

Pulse notes the two routes duplicate the skill if both are used, so pick one per host.

## What an app would do

Bundle the plugin directory (the one in this repository) in the installer, for example `Contents/Resources/agent-plugin/` on macOS and the install folder on Windows. Then offer one of:

- Local marketplace (preferred). A menu action "Add to Claude Code / Codex" that runs, with the user's click, `claude plugin marketplace add <bundled folder>` and the Codex equivalent, or shows the exact command to copy. The bundle needs a marketplace manifest next to the plugin (`.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`) using relative sources, as in this repository. The host owns the copy, versioning and removal. Caveat: a host may cache the plugin, so a later app update must refresh it (`claude plugin marketplace update`), and a moved or deleted app breaks the path. Not yet tried with a bundled path.
- Copy into the agent's directory (Pulse's loose-file route). Works only for the skill (and Codex hooks.json) and leaves the app responsible for updates, backups and uninstall. More code, more ways to damage the user's configuration; use it only where the marketplace route is unavailable.

Both can run on first launch only as an offer ("Connect to Claude Code / Codex?") or from a menu action, and the same check re-runs after each app update.

## Benefit

Version match. The skill describes the exact flags, output shapes and error codes of the engine in the same bundle, so the plugin cannot drift from the installed app. The marketplace route here installs whatever is on `main`, which can be ahead of or behind the user's app; a bundled plugin is by construction the right one. Mitigation if the marketplace route stays: put the minimum app version in each skill and have `doctor` report the contract version (GenRight and ScrapeRight already do).

## Host support

- Claude Code: marketplace add by local path and plugin install are evidenced (Pulse docs). Plugin hooks need no separate trust prompt there (Pulse docs), but they run code as the user.
- Codex: marketplace add by local path is evidenced; plugin hooks stay off until the user trusts them in `/hooks`. The desktop app's plugin handling was only confirmed by Pulse's docs, not tested here.
- Whether either host can be told to install a plugin without the user's participation is not evidenced; do not rely on it.

## Never do silently

- Write into another program's configuration (`~/.claude`, `~/.codex`, `hooks.json`, `config.toml`, settings) from an installer step, a background update or app start. Only on the user's click, after saying which files change.
- Write or imitate Codex hook trust, or skip a host's trust prompt.
- Overwrite a file the app did not write; back it up first, as Pulse does.
- Re-register after the user removed it.
- Leave hooks that fail loudly when the app is gone; hooks must exit 0 silently without the app (Pulse's launcher does).
