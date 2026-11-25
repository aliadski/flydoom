#!/usr/bin/env bash
# Watch the connectome play, live: the Doom window plus the neural dashboard.
#
#   scripts/live.sh                                   # easy forage arena
#   scripts/live.sh health_gathering_forage_easy 42   # the longest-lived seed we saw
#   scripts/live.sh defend_the_center                 # any scenario name works
#
# Runs experiments/m5_closed_loop.py with --paper (the behav_forage2
# configuration). Build the easy arena first with scripts/build_easy_arena.py
# if flydoom/wads/health_gathering_forage_easy.wad is missing.
#
# ViZDoom opens its window where the dashboard then opens on top of it, so on
# X11/XWayland this run's Doom window is moved left and enlarged with xdotool
# (apt install xdotool; position via DOOM_X/DOOM_Y/DOOM_W/DOOM_H). Without
# xdotool, move the dashboard aside by hand.
#
# Stop with Ctrl-C, or close the dashboard once the run ends. Extra arguments
# after the seed go to m5_closed_loop.py unchanged (a later --tics wins).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCENARIO="${1:-health_gathering_forage_easy}"
SEED="${2:-}"
shift $(( $# < 2 ? $# : 2 ))

PY="${PYTHON:-$ROOT/.venv/bin/python}"
X="${DOOM_X:-60}" Y="${DOOM_Y:-300}" W="${DOOM_W:-960}" H="${DOOM_H:-720}"
KIDS="$(mktemp)"

# ViZDoom engines are child processes that ignore SIGTERM, so a killed Python
# leaves them running with their windows open. Record them while they live,
# and make sure none outlives this script.
doom_children() {
    local p
    for p in $(pgrep -P "$1" 2>/dev/null); do
        grep -q vizdoom "/proc/$p/cmdline" 2>/dev/null && echo "$p"
    done
}

place_doom_window() {
    local kid w
    for _ in $(seq 1 120); do
        doom_children "$1" >"$KIDS"
        for kid in $(cat "$KIDS"); do
            w=$(xdotool search --pid "$kid" 2>/dev/null | head -1)
            if [[ -n "$w" ]]; then
                sleep 0.5
                xdotool windowmove "$w" "$X" "$Y" windowsize "$w" "$W" "$H" \
                    windowraise "$w" 2>/dev/null
                return
            fi
        done
        sleep 0.5
    done
}

cleanup() {
    [[ -n "${PID:-}" ]] && doom_children "$PID" >>"$KIDS"
    [[ -n "${PID:-}" ]] && kill "$PID" 2>/dev/null
    local k
    for k in $(sort -u "$KIDS"); do
        grep -q vizdoom "/proc/$k/cmdline" 2>/dev/null && kill -9 "$k" 2>/dev/null
    done
    rm -f "$KIDS"
    # ViZDoom rewrites _vizdoom.ini on every run; restore the tracked copy.
    git -C "$ROOT" checkout -q -- _vizdoom.ini 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT TERM

"$PY" -u experiments/m5_closed_loop.py --live --paper --tics 10500 \
    --scenario "$SCENARIO" ${SEED:+--seed "$SEED"} "$@" &
PID=$!

if [[ -n "${DISPLAY:-}" ]] && command -v xdotool >/dev/null; then
    place_doom_window "$PID" &
else
    echo "xdotool or DISPLAY missing: the Doom window may open behind the dashboard" >&2
fi

wait "$PID"
