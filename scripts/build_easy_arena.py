#!/usr/bin/env python3
"""Build health_gathering_forage_easy: the forage arena with a gentler floor.

WHY

In every health_gathering arena the floor is acid: sector special 83 takes
8 HP every 32 tics, so a player that never moves dies at tic 384 (11 s). The
medkits the level spawns give 20 HP each, and the model collects about one per
episode (median healed 18 in paper/data/behav_forage2). Its median survival is
448 tics against 384 for standing still -- so whatever the brain does, the
floor decides how long a clip lasts.

This arena exists to WATCH the model for longer, not to measure it. Every
number in the paper is from the stock drain; nothing here should be compared
with them.

WHAT CHANGES, and nothing else

  * The floor's special 83 is replaced by UDMF `damageamount`/`damageinterval`
    (default 2 HP per 32 tics, a quarter of the stock rate). Measured with a
    still player: 8/32 dies at tic 384, identical to special 83; 2/32 at 1568.
  * episode_timeout is raised from 2100 tics (60 s) to 10500 (5 min).

Walls, floor texture, food and poison sprites, the spawn script and the map
geometry are byte-for-byte the forage arena's.

    python scripts/build_easy_arena.py                 # 2 HP / 32 tics
    python scripts/build_easy_arena.py --damage 4      # half the stock drain
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WADS = ROOT / "flydoom" / "wads"
BASE = "health_gathering_forage"
NAME = "health_gathering_forage_easy"

STOCK_SPECIAL = "special = 83;\n"


def read_wad(path: Path) -> tuple[bytes, list[bytes], list[bytes]]:
    data = path.read_bytes()
    ident, nl, off = struct.unpack("<4sii", data[:12])
    names, blobs = [], []
    for i in range(nl):
        o, s, name = struct.unpack("<ii8s", data[off + 16 * i:off + 16 * i + 16])
        names.append(name)
        blobs.append(data[o:o + s])
    return ident, names, blobs


def write_wad(path: Path, ident: bytes, names: list[bytes],
              blobs: list[bytes]) -> None:
    body, dirs, pos = b"", [], 12
    for nm, b in zip(names, blobs):
        dirs.append(struct.pack("<ii8s", pos, len(b), nm))
        body += b
        pos += len(b)
    path.write_bytes(struct.pack("<4sii", ident, len(names), 12 + len(body))
                     + body + b"".join(dirs))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--damage", type=int, default=2,
                    help="HP the floor takes per interval (stock: 8)")
    ap.add_argument("--interval", type=int, default=32,
                    help="tics between floor hits (stock: 32)")
    ap.add_argument("--timeout", type=int, default=10500,
                    help="episode_timeout in tics (stock: 2100)")
    ap.add_argument("--out", type=Path, default=WADS)
    args = ap.parse_args()

    ident, names, blobs = read_wad(WADS / f"{BASE}.wad")
    i = [n.rstrip(b"\0") for n in names].index(b"TEXTMAP")
    tm = blobs[i].decode("latin1")
    if tm.count(STOCK_SPECIAL) != 1:
        raise SystemExit(f"expected one floor sector with {STOCK_SPECIAL!r} "
                         f"in {BASE}.wad, found {tm.count(STOCK_SPECIAL)}")
    tm = tm.replace(STOCK_SPECIAL, f"damageamount = {args.damage};\n"
                                   f"damageinterval = {args.interval};\n")
    blobs[i] = tm.encode("latin1")

    args.out.mkdir(parents=True, exist_ok=True)
    write_wad(args.out / f"{NAME}.wad", ident, names, blobs)

    cfg = (WADS / f"{BASE}.cfg").read_text()
    cfg = cfg.replace(f"{BASE}.wad", f"{NAME}.wad")
    cfg = cfg.replace("episode_timeout = 2100", f"episode_timeout = {args.timeout}")
    (args.out / f"{NAME}.cfg").write_text(cfg)

    still = 100 // args.damage * args.interval if args.damage else None
    print(f"wrote {args.out / NAME}.wad and .cfg")
    print(f"  floor: {args.damage} HP / {args.interval} tics "
          f"(stock 8 / 32); a still player lasts ~{still} tics "
          f"({still / 35:.0f} s)" if still else "  floor: no damage")
    print(f"  episode_timeout: {args.timeout} tics ({args.timeout / 35:.0f} s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
