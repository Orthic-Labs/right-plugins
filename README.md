# Right plugins

Agent plugins for the Right suite of apps by Orthic Labs, for Claude Code and Codex. Each plugin is a skill that teaches your agent to drive one installed app through its command line. This repository holds only the plugins and the marketplace manifest; the apps themselves are installed separately.

## Add it

Claude Code:

```
/plugin marketplace add Orthic-Labs/right-plugins
```

Then install any listed plugin, for example `/plugin install genright@right-suite`.

Codex: `codex plugin marketplace add Orthic-Labs/right-plugins`, restart Codex, open the Plugins directory and install from `right-suite`. Plugins with hooks (Pulse) need their hooks trusted once with `/hooks`.

## Tools

Every plugin except Legion needs the matching app installed on the same computer. A plugin never installs the app; if the app is missing, the agent tells you and stops.

| Plugin | What the agent can do | Needs installed |
|---|---|---|
| `cutright-engine` | Cut, edit, render and deliver video projects | CutRight |
| `genright` | Generate images, video and voice; check jobs, models and spend | GenRight |
| `scraperight-engine` | Transcribe video and audio; extract text from links, PDFs and images | ScrapeRight |
| `postright-engine` | Check the content calendar, review posts, run the text gate, inspect publish jobs | PostRight |
| `pulse` | Message AI chats on other computers (skill plus hooks) | Pulse |
| `legion` | Capability routing and authority roles for Claude Code | the `legion` binary |

Each skill drives the installed app's own command line (the engine inside the app). The skill asks you before anything that spends money, publishes, or deletes.

## Read this first

- The Legion entry is listed by its remote repository URL (`Orthic-Labs/legion`), not copied here. That remote form has not been tried against a real `/plugin marketplace add` yet. If it fails, install Legion from its own repository.
- The other plugins are copied into this repository, and the manifest points at them by relative path, the form Pulse and Legion use for themselves.
- Plugins track `main` and are not pinned to a release.

## Report a problem

Open an issue on this repository and name the plugin, your agent (Claude Code or Codex), and the exact request and reply. Problems with an app itself go to that app's support channel.

## Maintainers

`SOURCES.json` records which commit of each app's repository every plugin was copied from. `marketplace/plugins.json` is the source list; `.agents/plugins/marketplace.json` is generated from it with `right-ax marketplace build`. `.claude-plugin/marketplace.json` is generated the same way and then rewritten by hand to relative-path sources (the generator can only emit remote sources for now), so `right-ax marketplace validate` reports drift on that one file; use `--no-drift`. See `docs/INSTALLER-BUNDLING.md` for shipping a plugin inside an app installer.
