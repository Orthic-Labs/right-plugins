# Run `pulse chat <hook>` with the hook's stdin. Silent and successful when Pulse is absent.
param([string]$Hook)
$pulse = (Get-Command pulse -ErrorAction SilentlyContinue).Source
if (-not $pulse -and $env:LOCALAPPDATA) {
  $candidate = Join-Path $env:LOCALAPPDATA 'Programs\Pulse\Helpers\pulse.exe'
  if (Test-Path -LiteralPath $candidate) { $pulse = $candidate }
}
if (-not $pulse) { exit 0 }
$input | & $pulse chat $Hook
exit 0
