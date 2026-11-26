#!/usr/bin/env bash
# Watch the connectome play, live, drawn exactly like the clips in media/:
# stock-Doom panel, the three cameras stitched into one view, both eyes lens by
# lens, the rates, steering, smell and a heading-up map.
#
#   scripts/live_footage.sh                  # media/flydoom.mp4's run: fly arena, seed 40
#   scripts/live_footage.sh 96               # another level
#   scripts/live_footage.sh 40 --mirror      # the mirrored-retina control
#   scripts/live_footage.sh 40 --every 2     # draw every other tic, ~2x the pace
#   SCENARIO=health_gathering_forage scripts/live_footage.sh 40
#
# It is scripts/record_gameplay.py with media/record.sh's flags and --live:
# the frames go to a window instead of ffmpeg. The fly dies on the stock acid
# floor in 10-30 s and a new life starts, until LIVE_SECONDS of game time (300).
# The same seed does not mean the same path as the clip: see media/README.md
# and scripts/action_trace.py. Stop with Ctrl-C or by closing the window.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SEED="${1:-40}"
shift $(( $# < 1 ? $# : 1 ))
PY="${PYTHON:-$ROOT/.venv/bin/python}"
export FLYDOOM_DEVICE="${FLYDOOM_DEVICE:-cuda}"

# ViZDoom rewrites _vizdoom.ini on every run; restore the tracked copy.
trap 'git -C "$ROOT" checkout -q -- _vizdoom.ini 2>/dev/null' EXIT

SCENARIO="${SCENARIO:-health_gathering_fly}"
LABEL="live · $SCENARIO · seed $SEED"
[[ " $* " == *" --mirror "* ]] && LABEL="$LABEL · retina mirrored (control)"

"$PY" -u scripts/record_gameplay.py --live --seconds "${LIVE_SECONDS:-300}" \
    --scenario "$SCENARIO" --seed "$SEED" \
    --wide --eye-map anatomical --fixed-turn --phasic-mdn --spiking-t4 \
    --optic-gain 16 --yaw-source DNp15 --touch --shadow \
    --label "$LABEL" "$@"
