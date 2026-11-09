# Run `pulse chat <hook>` with the hook's stdin, or `pulse context-hook <args…>` for the Membrane
# context hooks. Silent and successful when Pulse is absent. Arguments are read from $args so
# that `--wire` and `--event` reach Pulse unchanged.
$hook = $args[0]
$rest = @($args | Select-Object -Skip 1)
$pulse = (Get-Command pulse -ErrorAction SilentlyContinue).Source
if (-not $pulse -and $env:LOCALAPPDATA) {
  $candidate = Join-Path $env:LOCALAPPDATA 'Programs\Pulse\Helpers\pulse.exe'
  if (Test-Path -LiteralPath $candidate) { $pulse = $candidate }
}
if (-not $pulse) { exit 0 }
if ($hook -eq 'context-hook') {
  $input | & $pulse context-hook @rest
  exit 0
}
$input | & $pulse chat $hook
exit 0
