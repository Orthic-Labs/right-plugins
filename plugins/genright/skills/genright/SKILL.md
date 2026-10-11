---
name: genright
description: Generate images, video and voice and check GenRight jobs, models, credentials and spend with the genright-engine CLI; use when the user asks to generate an image with GenRight, check my GenRight job, see GenRight spend or balances, or which GenRight models are installed.
---

# genright

Drive the GenRight engine from the shell with the Bash tool. Parse stdout as JSON and read fields by name. Treat a non-zero exit as failure.

The engine ships inside the installed app. It is not on PATH. Do not build GenRight, search the disk for it, or install it.

Examples use `$GE`. Each Bash call starts a new shell, so define it in the same command:
`GE=/Applications/GenRight.app/Contents/MacOS/genright-engine; "$GE" doctor`

## 1. Find the engine

- macOS: `/Applications/GenRight.app/Contents/MacOS/genright-engine`.
- Windows: `%LOCALAPPDATA%\GenRight\genright-engine.exe` (the default per-user install); if it is not there, use `genright-engine.exe` in the install folder named by the GenRight uninstall registry entry.
- Verify with `"$GE" doctor`. Exit 0 and JSON with `app_version` means the engine works.
- If the binary is absent, tell the user GenRight is not installed and stop.

## 2. Calling convention

`genright-engine <words> [--input '<json object>' | --input -] [--dry-run] [--wait] [--wait-timeout <s>] [--request-id <id>]`

- `--input '<json>'` takes one JSON object. `--input -` reads it from stdin. Stdin is never read otherwise. Omitted input means `{}`.
- `--provider`, `--model` and `--prompt` are shortcuts merged into the input object.
- `--wait` sets input `wait:true`. `--wait-timeout` sets `wait_timeout_s`. `--request-id` sets `request_id`.
- Success: one JSON value on stdout, exit 0.
- Failure: `{"error":{"code":"...","message":"...","details":{}}}` on stdout. `details` is optional. Exit 1 is a command error. Exit 2 is a usage or input error; usage text goes to stderr.
- Progress: `generate --wait`, `job wait` and `media generate --wait` write NDJSON lines to stderr, one per event: `{"event":"job.progress","job_id":"...","status":"...","stage":"...","attempt":1,"at":"...","message":"..."}`. `stage` is `submitted`, `polling`, `downloading`, `complete` or `failed`. The answer is always on stdout; progress is optional.
- Never parse human text. Use the field names below.

## 3. Discover readiness and models

- `"$GE" doctor`: `app_version`, `contract_version`, and `readiness.generation.providers[]`. Each provider has `configured` (a key is stored) and `runtime` (local engines: `ready`, plus `code` such as `not_installed` when not ready).
- `"$GE" media modalities`: one entry per kind. `state` is `available`, `unconfigured` or `unsupported`. Each provider reports `credential` (`configured`, `unconfigured` or `not_required`), `installed`, `ready` and `models`. Add `--input '{"probe":true}'` only when a live local-runtime check matters: it contacts local runtimes.
- `"$GE" models`: a flat array of `{provider, model, kind, label, est_usd}`. Rows may also carry `durations_s` or `min_duration_s`/`max_duration_s`, and `references` for image models that take reference images.
- `"$GE" studio models catalog`: local model entries with `readiness` and `installable`.
- `"$GE" studio models install.status [<model-id>]`: install progress.
- `"$GE" apps`: installed Orthic Labs apps. Read-only.

## 4. Estimate, consent, generate

1. Pick a `ready` kind and model from `media modalities` or `models`.
2. Estimate without side effects:
   `"$GE" media generate image --dry-run --input '{"model":"<model>","prompt":"<text>","params":{}}'`
   The result is `{"dry_run":true,"est_usd":...,"would_submit":{...}}`. Nothing is stored or sent.
3. Show the user the provider, model, `est_usd` and prompt. Ask for an explicit yes for this run.
4. Generate after the yes:
   `"$GE" media generate image --wait --wait-timeout 300 --request-id <id> --input '{"model":"<model>","prompt":"<text>","params":{}}'`
5. Read the final record. When `status` is `complete`, read `result.assets[].path`, `sha256`, `bytes` and `mime`.

Notes:
- Use `media generate <kind>`, not `generate <kind>`. `media generate` infers `provider` when exactly one provider offers the model. If the error is `ambiguous_route`, pass `"provider"` in the input.
- Kinds: `image video voice avatar music sfx upscale lipsync text extend motion_control replace_object restyle`. `extend`, `motion_control`, `replace_object` and `restyle` have no model declared, so they fail with `unsupported_kind`.
- `--request-id` is idempotent. The same id returns the same job with `deduplicated:true` and no new spend. Use one id per user intent and reuse it when re-running after a crash.
- Without `--wait`, the call returns at once with `job_id`, `status`, `est_usd`, `request_id` and `deduplicated`. Follow it with `job wait`.
- `--wait-timeout N` on timeout returns the record with `timed_out:true`, exit 0. The job keeps running in a detached runner. Check it later. Do not resubmit it.

## 5. Check, wait, read and acknowledge jobs

- `"$GE" job status <job_id>`, or `"$GE" job status --request-id <id>`. Add `--input '{"events":true}'` for the last 200 progress events. Terminal statuses are `complete`, `failed` and `cancelled`. `submitted` and `running` are still in progress. `outcome_unknown` needs the user (section 6).
- `"$GE" job wait <job_id> --wait-timeout 120`: blocks until the job is terminal or the timeout passes. `timed_out` says which.
- `"$GE" job result <job_id>`: the result descriptor with `assets[]`. Errors: `not_ready` (still running), `job_not_successful` (failed or cancelled), `result_cleaned` (already acknowledged and cleaned up).
- `"$GE" job list --input '{"status":"complete","limit":20}'`: newest first, with `truncated`.
- `"$GE" job ack <job_id> --input '{"consumer":"<your name>"}'`: run it only after the assets are safely imported. GenRight keeps un-acknowledged results.
- `"$GE" job cancel <job_id>`: stops an unfinished job and releases its open spend reservation. Confirm with the user first. Refused for `outcome_unknown` and `result_recovered` jobs. A finished job's assets are never removed.
- `"$GE" asset resolve <asset_id>`: `{asset_id, job_id, path, sha256, bytes, mime, exists}`. `exists:false` means the record is known but the file is gone.
- Do not run `job run`. It is internal.

## 6. outcome_unknown and result_recovered

A paid submit may already have reached the provider. GenRight then holds the job. `job status` shows `"outcome_unknown":{"attempt":...,"reserved_usd":...,"idempotency_key":"...","resolve":["resubmit","abandon"]}`. Never resubmit on your own. Ask the user which option applies, then run one of:

- `"$GE" job resolve <job_id> --resubmit`: the user confirmed with the provider that nothing ran. The held reservation is released, and one new attempt starts with a new key and reservation. After three attempts the error is `max_attempts`.
- `"$GE" job resolve <job_id> --abandon`: the job ends `failed` with `outcome_unknown_abandoned`. The held amount stays counted as spent, because the charge may have happened.
- `"$GE" job resolve <job_id> --adopt`: only when the error is `result_recovered`, meaning a paid result was saved locally. This imports that result and never sends the request again.

`job resolve` works only on `outcome_unknown` jobs (`not_outcome_unknown` otherwise). `job_busy` means another process is running the job.

## 7. Money and consent (binding)

- Any run that reserves spend needs the user's explicit go-ahead for that specific run. Show the provider, model and `est_usd` first. Consent does not carry to later runs.
- Keyless local providers (`needs_key:false`, `credential:not_required`, such as `local-*` and `realesrgan`) cost nothing. Their `est_usd` is 0.
- Other paid routes, such as character training, translation with a paid model or avatar generation, also need that per-run go-ahead. Do not start them unless the user asks for that exact run.
- Never raise or change a spend cap unless the user asks. `"$GE" spend set_cap --input '{"cap_usd":<n>}'` is user-directed only.
- Check the ledger: `"$GE" spend status` returns `{day, cap_usd, reserved_usd, actual_usd}`. Show the user these numbers when a paid run is close to the cap.
- NanoBanana reference images: a local file in `params.image_urls` is uploaded to the user's own fal storage. This needs `"confirm_fal_upload": true` at the top level of the input (not inside `params`), and only after the user says yes for this run. Never default it. A `--dry-run` needs no confirmation and reports `requires_fal_upload_confirmation` and `local_references`.
- `"$GE" asset delete <asset_id>` (or `--input '{"path":"<absolute path>"}'`) removes files from disk and cannot be undone. Confirm with the user first.
- Credentials: never print a key, and never ask the user to paste one into chat. `"$GE" credentials status` reports presence and source only. To add a key, tell the user to open GenRight, then Settings > Providers > API keys. Do not run `credentials set`, `credentials import-env`, `credentials migrate` or `credentials test`. `test` makes a live provider call.
- Installing a local model downloads multi-gigabyte files (`musicgen-small` is about 3.6 GB). Ask first, then run `"$GE" studio models install <model-id>`.

## 8. Error codes and next steps

| `error.code` | Meaning | Next step |
|---|---|---|
| `not_installed` | A local engine or model file is missing. Retryable: the job pauses. | Report it. Install only with the user's go-ahead (section 7). |
| `no_credentials` | No stored key for a paid provider. | Tell the user to add the key in Settings > Providers > API keys. |
| `no_key` | No fal key, required for a NanoBanana local-image upload. | Same as above, for fal. |
| `spend_cap` | The daily cap would be exceeded. Nothing was sent. | Report `spend status`. Only the user can raise the cap. |
| `invalid_request` | An unknown top-level or `params` key. The message names it. | Fix the input. Do not retry unchanged. |
| `invalid_input` | A missing or malformed field. | Fix the input. |
| `upload_confirmation_required` | A local reference needs consent for this run. `details` lists the paths. | Ask the user. Rerun with `confirm_fal_upload: true` only after a yes. |
| `outcome_unknown` | A paid submit may have run. The job is held. | Section 6. Never resubmit on your own. |
| `result_recovered` | A paid result is saved locally. | Use `job resolve <id> --adopt`. Never resubmit. |
| `runtime_load_failed` | The runtime file exists but the OS refuses to load it. Not retryable. | Report the message and stop. |
| `price_stale` | The model price is over 60 days old. | Report it. Do not retry. |
| `unsupported_kind`, `unknown_kind`, `unknown_model`, `ambiguous_route` | The kind or model is wrong, or the provider is ambiguous. | Choose a listed kind or model, or pass `provider`. |
| `job_not_found`, `asset_not_found` | Wrong id. | Check the id with `job list` or `asset resolve`. |
| `locked_elsewhere` | Another process is running the job. This is a status, not a failure. | Follow it with `job wait`. |

Any other code: report the `error.code` and `error.message` exactly. Do not retry silently.

## 9. Typical flows

- Readiness: `"$GE" doctor`, then `"$GE" media modalities`.
- Generate: `"$GE" models` for the model and `est_usd`, then the dry run, then the user's yes, then `media generate ... --wait`, then read `result.assets[].path`.
- Later: `"$GE" job status <id>` or `"$GE" job wait <id> --wait-timeout 120`, then `"$GE" job result <id>`, then `job ack` after import.
- Money check: `"$GE" spend status`.
