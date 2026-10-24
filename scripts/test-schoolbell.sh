#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
command -v lua5.1 >/dev/null
cd "$ROOT"
lua5.1 packages/schoolbell/tests/test_calendar.lua
python3 packages/schoolbell/tests/test_calendar_dates.py "$(command -v lua5.1)"
lua5.1 packages/schoolbell/tests/test_playback_queue.lua
lua5.1 packages/schoolbell/tests/test_player_model.lua
