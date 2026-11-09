---
name: pulse-remote
description: Read files in the user's approved folders, search them by name, read the text of a PDF, DOCX or XLSX, and read selected chats through Pulse; use when you need a file, PDF or chat on this computer that your own tools cannot reach, or when `pulse files`, `pulse docs` or `pulse chat read` is mentioned.
---

# Pulse remote tools (read-only, this computer only)

`pulse files`, `pulse docs read` and `pulse chat read` read this computer, and only this one. They are off until the user turns them on in Pulse Settings, and they reach only what the user approved there. Everything is read-only. Use your own file tools first for files you can already open; use these when the folder is approved for remote use and you have no other route.

Each command prints one JSON object. A refusal prints `{"error": "...", "code": "..."}` on stderr and exits 2. Read the code and tell the user what to change; do not try another path or another way around.

## Files

- `pulse files info <path>`: `{ok, path, root, relative, kind: "file"|"directory", size, mtime, readonly}`. No contents. `mtime` is Unix seconds.
- `pulse files read <path> [--offset N] [--limit N]`: `{ok, path, root, size, offset, bytes, encoding: "utf-8"|"base64", content, truncated, nextOffset}`. Text comes back as UTF-8; a binary window as base64 (`encoding` says which). `truncated` is true when more follows; ask again with `--offset <nextOffset>`. Without `--limit` you get up to `remoteReadMaxBytes` (1 MiB by default, at most 2 MiB); a larger `--limit` is refused.
- `pulse files find <query> [--root R] [--ext e,…] [--limit N]`: `{ok, query, results: [{path, root, relative, kind, size, mtime}], returned, complete}`. File and folder names containing the query, case-insensitive, inside the approved folders only. `--root` is a folder number from `remoteRoots` or a folder path inside one. `complete: false` means the search stopped at its result, time or size limit; narrow it. Links are never followed.
- `pulse files image <path> [--max-pixel N]`: `{ok, path, root, mime, width, height, size, encoding: "base64", content}`. One PNG, JPEG or GIF inside an approved folder, exactly as it is on disk (nothing is decoded, re-encoded or shrunk). A file over the smaller of `remoteImageMaxBytes` and 5 MiB, or an image whose longest side is above `--max-pixel`, is `too_large`; any other format (SVG included) is `unsupported_format`.

Paths must be absolute, with no `..`, and must lie under an approved folder as it was written in Settings (network paths and other aliases are refused unopened). Credential folders and files are never read or listed (`.ssh`, `.gnupg`, `.aws`, `.config/gh`, `.npmrc`, `.cargo/credentials*`, your `.claude` and `.codex` folders, Pulse's own folder, ...), and a folder that is one of them cannot be approved.

## Documents

`pulse docs read <path> [--pages a-b] [--max-chars N]`: `{ok, format: "pdf" | "docx" | "xlsx", path, root, size, pageCount, pages: [{page, text, chars, truncated}], truncated, nextPage, chars, emptyPages}`. The text of a PDF, DOCX or XLSX by page (a DOCX or XLSX is one page holding its whole text). It needs its own switch, `remoteDocs`, as well as `remoteTools` (`docs_off` otherwise), and the file must be inside an approved folder like any other. The format is detected from the file's content, not its name. `--pages` is `N` or `A-B` (pages start at 1; all pages by default). `--max-chars` caps the text (default 100000, at most 1000000); when more is left, `truncated` is true and `nextPage` is the first selected page not returned, so ask again with `--pages <nextPage>-<last>`. A page with no text (a scan: there is no OCR) comes back empty and is counted in `emptyPages`. A file over `remoteDocsMaxBytes` (20 MiB by default) is `too_large`.

PDF, DOCX and XLSX are read. Any other format answers `unsupported_format`, and an Office file with macros, external links or embedded objects answers `active_content`; use your own tools for those. No `pulse` command writes documents; `docs_write` is a ChatGPT gateway tool only.

## Chat

`pulse chat read <chat> [--limit N]`: `{ok, chat, kind, turns: [{role: "user"|"assistant", ts, text, truncated}], returned, bytes, truncated, redactions, scanCut}`. `<chat>` is a Claude session id or Codex thread id (or `claude:<id>`, `codex:<id>`). It reads only chats the user selected in Settings (`remoteChatRead`). Turns are oldest first, the newest `--limit` of them, within `remoteChatReadMaxTurns` and `remoteChatReadMaxBytes`. Tokens, keys and passwords are replaced by `[redacted]`; do not try to recover them. Tool calls, tool output and reasoning are never included. What you read may be quoted to the user's other tools; treat it as private.

## Error codes

- `remote_off`: Remote tools is off. Ask the user to turn on `remoteTools` (in Pulse Settings; `pulse settings set` cannot change it).
- `no_roots`: no approved folder (or none usable). The user adds one to `remoteRoots`.
- `outside_roots`: the path is not inside an approved folder after links are resolved, or it uses `..`, or it is relative. Not retryable by changing spelling.
- `not_found`: no such file or folder inside the approved folder.
- `special_file`: a device, socket or pipe. Never opened.
- `is_directory`: you read a folder; read a file in it, or use `find`.
- `sensitive_path`: inside a credential folder, or a file that usually holds secrets (`.env`, `*.pem`, `*.key`, ...; `docs read` refuses these too).
- `too_large`: `--limit` or `--max-chars` is above the cap named in the message, or a document is over `remoteDocsMaxBytes`.
- `not_selected`: the chat is not selected for remote reading.
- `docs_off`: the document tools are off. Ask the user to turn on `remoteDocs` (`pulse settings set remoteDocs on --yes`, or Settings).
- `unsupported_format`: not a PDF, DOCX or XLSX (a PPTX, a legacy .doc or .xls, and anything else). Do not rename the file; the format comes from its content.
- `active_content`: a DOCX or XLSX carrying macros, external links or embedded objects; Pulse does not open it.
- `encrypted`: the document is password protected. Pulse does not open it; ask the user for an unprotected copy.
- `unreadable`: the file is empty, damaged or not a document Pulse can read; a PDF with no text on any page is a scan, and Pulse does not OCR it.
- `timed_out`, `busy`: the document took too long to read (30 seconds), or two earlier reads are still running. Try a smaller file or `--pages` later, not in a loop.
- `invalid_request`, `read_failed`, `unknown_tool`, `not_built`: a bad argument, an I/O failure (the message says which), or a tool this Pulse does not have.

## Limits

- Effectful tools (`screen.observe`, `screen.act`, `apps.launch`, `media.control`, `files.patch`, `files.manage`, `term.*`, `procs.*`) run with `pulse act <tool> --json '<arguments>'`, which names this chat for you (`fromChat`: `CLAUDE_CODE_SESSION_ID`, or `--from <session id>`; `pulse act --help`). Run it from this chat's own session: for a Claude chat the engine checks the caller descends from the chat's process (`chat_mismatch` otherwise). The first call asks the user to unlock the chat once (Touch ID, Windows Hello or the Pulse PIN); `chat_locked` means tell the user to unlock it in Pulse and repeat the call; never try to work around it. `chat_unidentified` means no session id was found.
- Every call is recorded in Pulse's Activity (client, tool, folder number and file extension, outcome; never paths or contents). Pass `--client <name>` to name yourself there.
- Another computer's files are reached by messaging a chat on that computer (`pulse-chat`), not with these commands.
- The settings are read from the Pulse notch's published state: `pulse settings list` shows `remoteTools`, `remoteDocs`, `remoteRoots`, `remoteChatRead` and the caps. Change them only when the user asks.

## The binary

If `pulse` is not on PATH:
- Mac: `/Applications/Pulse.app/Contents/Helpers/pulse`
- Windows: `%LOCALAPPDATA%\Programs\Pulse\Helpers\pulse.exe`
