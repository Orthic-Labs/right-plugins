#!/bin/sh
# Run `pulse chat <hook>` with the hook's stdin. Silent and successful when Pulse is absent,
# so a computer without Pulse never sees a hook error.
hook="$1"
pulse=""
if command -v pulse >/dev/null 2>&1; then
  pulse="pulse"
elif [ -x /Applications/Pulse.app/Contents/Helpers/pulse ]; then
  pulse="/Applications/Pulse.app/Contents/Helpers/pulse"
elif [ -n "$LOCALAPPDATA" ] && [ -x "$LOCALAPPDATA/Programs/Pulse/Helpers/pulse.exe" ]; then
  pulse="$LOCALAPPDATA/Programs/Pulse/Helpers/pulse.exe"
fi
[ -n "$pulse" ] || exit 0
exec "$pulse" chat "$hook"
