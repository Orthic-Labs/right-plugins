---
name: scraperight-engine
description: Extracts transcripts and text from videos, audio, PDFs, images and web pages with the scraperight-engine command line; use when the user asks to transcribe a video, transcribe an audio file, extract text from a URL, or OCR a PDF or image.
---

# scraperight-engine

Run the installed ScrapeRight engine from the shell. It downloads media from links, extracts text from articles, PDFs and images, and transcribes speech on this machine. Use it for transcripts, OCR, or saved media files. Read results from stdout or from the returned file paths. Do not paste full transcripts into chat.

## Find the installed engine

Use only the installed copy. Never run a development or staged build.

- macOS: `/Applications/ScrapeRight.app/Contents/MacOS/scraperight-engine`
- Windows (installer default): `C:\Program Files\ScrapeRight\scraperight-engine.exe`

If the file is not there, search for it:

- macOS: `mdfind -name scraperight-engine`, then keep the path inside `ScrapeRight.app/Contents/MacOS/`.
- Windows: `where.exe scraperight-engine.exe`, or `dir "C:\Program Files\ScrapeRight" /s /b scraperight-engine.exe`.

Check it:

```bash
ENGINE="/Applications/ScrapeRight.app/Contents/MacOS/scraperight-engine"
"$ENGINE" doctor
```

A healthy run exits 0 and prints pretty JSON on stdout. Look for `cli_contract_version: 1`, `capability_version: 1`, and a `capabilities` list that includes `transcribe_v1` and `extract_v1`. `tdt_model_ok`, `ocr_available`, `ytdlp` and `ffmpeg` should be `true`. If `tdt_model_ok` is `false`, tell the user to open ScrapeRight once so it can finish model setup.

## Rules for every call

- Always pass arguments. The engine with no arguments starts desktop stdio mode, not a CLI run.
- Use absolute paths for local files, `--out`, and `--workspace`.
- Check the exit code before you read results. Parse stdout only; progress goes to stderr.
- `--dry-run` (before or after the command) prints the plan only: no downloads, transcription, writes, or licence check. Example: `"$ENGINE" --dry-run transcribe /Users/me/Movies/clip.mp4`.
- Do not use `--help`. It is not reliable: `doctor --help` and a bare `--help` exit 2 with an error.

## doctor

```bash
"$ENGINE" doctor [--workspace /abs/dir] [--dry-run]
```

Prints the health report as JSON. There is no `--json` flag. `doctor` does not need Pro.

## extract

```bash
"$ENGINE" extract <link>... [--batch file] [--out dir] [--json] [--timeout-min n] \
  [--video-quality p720|p1080|p2160|source | --audio-quality best|compact] \
  [--workspace /abs/dir] [--dry-run]
```

Downloads media only. It never loads the speech model, and results have `words: []`. Pass links to downloadable video or social media. Local files, articles, images and PDFs fail with `unsupported_input` (exit 2). The default video quality is p1080. Pass at most one quality flag.

```bash
"$ENGINE" extract "https://www.youtube.com/watch?v=VIDEO_ID" --video-quality p720 --out "/Users/me/Downloads/exports" --json
```

With `--out`, each job's media goes into its own subdirectory. An existing file is never overwritten.

## transcribe

```bash
"$ENGINE" transcribe <url-or-file>... [--batch urls.txt] [--out dir] [--json] [--timeout-min n] [--workspace /abs/dir] [--dry-run]
```

Downloads, transcribes, and saves each result to the ScrapeRight library. With `--out`, the finished `.txt`, `.md` and `.srt` files are also copied there by file name, replacing any file with the same name. `--batch` reads one input per line; blank lines and `#` comments are skipped. The default timeout is 240 minutes.

```bash
"$ENGINE" transcribe "/Users/me/Movies/clip.mp4" --out "/Users/me/Documents/transcripts" --json
```

Without `--json`, stdout has one line per job: `done<TAB>input<TAB>path` or `failed<TAB>input<TAB>message`.

## JSON contract

### `--json` (one line per job)

Each finished job prints one object on stdout, not wrapped in an envelope. Keys: `input`, `id`, `ok`, `error`, `title`, `media_path`, `media_meta`, `txt`, `md`, `srt`, `copied`, `words`.

### `--request` (one JSON object in, one JSON value out)

Pass the request inline, or pass `-` and send it on stdin. Put every option inside the JSON. The only flag allowed beside `--request` is `--dry-run`.

- `command`: required. `doctor`, `transcribe` or `extract`.
- `inputs`: array of links or absolute paths. `input`: one more item.
- `out`, `workspace`: absolute directory paths.
- `timeout_min`: positive number of minutes.
- `media` (extract only): `{"action":"download","video":"p720"}` or `{"action":"download","audio":"compact"}`.
- `dry_run`: boolean.

```bash
"$ENGINE" --request '{"command":"doctor"}'
printf '%s\n' '{"command":"transcribe","inputs":["/Users/me/Movies/clip.mp4"],"out":"/Users/me/Documents/transcripts"}' | "$ENGINE" --request -
```

A transcribe or extract request prints one envelope. Results keep input order.

```json
{
  "ok": true,
  "command": "transcribe",
  "results": [
    {
      "input": "/Users/me/Movies/clip.mp4",
      "id": "cli-...",
      "ok": true,
      "txt": "/.../clip.txt",
      "md": "/.../clip.md",
      "srt": "/.../clip.srt",
      "words": [{"text": "hello", "start": 0.10, "end": 0.42}]
    }
  ]
}
```

`ok` on the envelope is true only when every result succeeded. Each result also has `error`: `null` on success, or `{"code": "...", "message": "..."}`. Failed results can have `words: null`; treat `null` as no words. A timing file that cannot be read gives `ok: false` with a coded error. The engine never reports success with missing words.

A request-level failure prints:

```json
{"ok": false, "error": {"code": "invalid_request", "message": "..."}}
```

## Exit codes

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Everything finished. | Read the results. |
| 1 | At least one job failed or timed out. | Read each `error.code`. Retry only failed inputs, and only after the cause changes. |
| 2 | Usage or request error, including `unsupported_input`. | Fix the command. Do not repeat it unchanged. |
| 3 | ScrapeRight Pro is required (`license_required`). | Stop. Tell the user Pro is needed and is activated in the app (Settings → Pro). |
| 10 | The engine failed to start (`engine_start_failed`). | Run `doctor` and report its JSON. Do not loop. |

Other codes you may see: `job_failed`, `cancelled`, `timeout`, `copy_failed`, `queue_failed`, `timing_export_unreadable`, `timing_export_malformed`, `media_export_missing`, `invalid_request`, `unknown_command`.

The CLI has no separate sign-in or rate-limit code. Read the `message`. If it says sign-in is needed, tell the user to sign in to that service in the app (Settings → Accounts), then retry. If it says blocked or rate limited, wait before retrying.

## Limits and safety

- Runs locally. Downloads come from the link you pass. The speech model runs on this machine.
- `transcribe` and `extract` need ScrapeRight Pro. `doctor` and `--dry-run` do not.
- Extract never loads the speech model. Transcribe waits if another process holds it.
- A CLI run uses its own queue and never changes the app's queue.
- The CLI has no option for passwords, tokens, or cookies. Never put them in arguments or JSON. Sign in inside the app.
- A `--workspace` run uses a private settings and data root. It does not read the app's library, and credentials are never copied into it.
