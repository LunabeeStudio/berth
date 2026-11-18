#!/usr/bin/env bash
# Usage: run-bar.sh
# Builds berth-bar from this checkout and runs it next to the installed one, on the same daemon. Ctrl-C quits it.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

swift build --product berth-bar
bar="$(swift build --show-bin-path)/berth-bar"

echo "berth-bar from $root, on the daemon of ${BERTH_HOME:-the default BERTH_HOME}. Ctrl-C quits it." >&2
echo "Launch at login and Auto update are shared with the installed berth-bar: toggling them here changes both." >&2

"$bar" &
pid=$!
# A background job of a script ignores SIGINT, so Ctrl-C reaches the bar as SIGTERM: it quits and closes its mirrors.
trap 'kill -TERM "$pid" 2>/dev/null || true' INT TERM
status=0
while kill -0 "$pid" 2>/dev/null; do
    status=0
    wait "$pid" || status=$?
done
exit "$status"
