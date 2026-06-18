#!/usr/bin/env python3
"""Quest duplicate-detection tool.

Guards against installing the same quest twice under different naming
conventions (the bug that put "MA4 -2A-" in as q628 when "Maximum Attack
4th Stage -2A-" already existed as bundled q497).

Backed by dashboard/quest-provenance.json — each entry's `name` plus its
optional `aliases` list are all normalized into one lookup index.

Usage:
  # Internal consistency: flag any two catalogued quests that collide
  python3 scripts/quest-dedup-check.py --self-check

  # Check candidate name(s) before installing
  python3 scripts/quest-dedup-check.py "Maximum Attack 4th Stage -2A-"
  python3 scripts/quest-dedup-check.py "MA4 -2A-"        # alias still matches

  # Check a directory of .qst files (matches by filename stem)
  python3 scripts/quest-dedup-check.py --dir /tmp/new-quests

Exit code is non-zero if any collision/duplicate is found, so it can gate
a future install script in CI or a pre-commit hook.
"""
import argparse, json, os, re, sys

PROV = os.path.join(os.path.dirname(__file__), "..", "dashboard", "quest-provenance.json")


def normalize(name: str) -> str:
    """Collapse a quest name to a comparison key.

    Lowercase, strip everything but alphanumerics, and fold the common
    "MA4"/"Maximum Attack 4" + "MAE"/"Maximum Attack E" abbreviations so
    short and long forms land on the same key even without an explicit
    alias entry.
    """
    s = (name or "").lower()
    s = s.replace("maximum attack 4th stage", "ma4")
    s = s.replace("maximum attack 4", "ma4")
    s = s.replace("maximum attack e:", "mae")
    s = s.replace("maximum attack e", "mae")
    s = s.replace("maximum attack s", "mas")
    s = s.replace("maximum attack", "ma")
    s = s.replace("random attack xrd", "raxrd")
    return re.sub(r"[^a-z0-9]", "", s)


def build_index(prov: dict) -> dict:
    """normalized-key -> list of (quest_number, display_name, via)."""
    idx = {}
    for num, e in prov.items():
        if num.startswith("_") or not isinstance(e, dict):
            continue
        names = [(e.get("name"), "name")] + [(a, "alias") for a in e.get("aliases", [])]
        for nm, via in names:
            if not nm:
                continue
            idx.setdefault(normalize(nm), []).append((num, e.get("name"), via))
    return idx


def self_check(prov: dict) -> int:
    """Flag quests that look like the same thing under two numbers.

    Dup key is (normalized-name, episode): two entries that share both are
    candidates for being the same quest. We then partition:

      - "actionable" = the group involves at least one custom entry. These
        are the ones our own installs could have duplicated, so they're
        printed in full with each entry's platform.
      - "expected" = every entry is Sega `original`. PSO ships the same
        Sega story/event quest at several numbers for different client
        versions (e.g. Planet Ragol at DC q151 / GC q180 / BB q401); that
        multi-version spread is intentional, so we only summarize a count.

    NOTE: provenance records a single `platform` (original release), not
    which client-version files a number actually bundles, so a same-name
    pair on *different* platforms is usually a legitimate per-version copy,
    not a true duplicate. When the printed platforms differ, it's almost
    always fine; confirm a true dup by decoding the files. Exit is non-zero
    only when an actionable same-platform collision is found.
    """
    by_key = {}
    for num, e in prov.items():
        if num.startswith("_") or not isinstance(e, dict):
            continue
        names = [e.get("name")] + e.get("aliases", [])
        ep = e.get("episode")
        seen_keys = set()
        for nm in names:
            if not nm:
                continue
            k = (normalize(nm), ep)
            if k in seen_keys:
                continue  # don't double-count an entry via its own alias
            seen_keys.add(k)
            by_key.setdefault(k, []).append((num, e.get("name"),
                                             e.get("classify"), e.get("platform")))

    actionable, expected = [], 0
    for (key, ep), hits in by_key.items():
        nums = {n for n, _, _, _ in hits}
        if len(nums) < 2:
            continue
        if any(c == "custom" for _, _, c, _ in hits):
            actionable.append((key, ep, hits))
        else:
            expected += 1

    hard_dupes = 0
    if actionable:
        print(f"⚠ {len(actionable)} collision group(s) involving custom quests "
              f"(review — platform shown; differing platforms are usually OK):")
        for key, ep, hits in sorted(actionable):
            plats = {p for _, _, _, p in hits}
            tag = "SAME platform — LIKELY TRUE DUP" if len(plats) == 1 else "different platforms — likely per-version copies"
            if len(plats) == 1:
                hard_dupes += 1
            print(f"  [{key} | Ep{ep}] {tag}")
            for n, nm, c, p in sorted(hits):
                print(f"      q{n}: {nm!r} ({c}, {p})")
    if expected:
        print(f"ℹ {expected} all-original cross-version groups suppressed "
              f"(Sega quests intentionally bundled at multiple version-numbers).")
    if hard_dupes == 0:
        print("✓ No same-platform duplicate installs detected.")
        return 0
    print(f"✗ {hard_dupes} same-platform collision(s) need resolution.")
    return 1


def check_names(prov: dict, names: list) -> int:
    idx = build_index(prov)
    found = 0
    for cand in names:
        hits = idx.get(normalize(cand), [])
        if hits:
            found += 1
            where = ", ".join(f"q{n} ({nm!r} via {via})" for n, nm, via in hits)
            print(f"✗ {cand!r} DUPLICATES existing: {where}")
        else:
            print(f"✓ {cand!r} is new (no match).")
    return 1 if found else 0


def main():
    ap = argparse.ArgumentParser(description="PSO quest duplicate checker")
    ap.add_argument("names", nargs="*", help="candidate quest name(s) to check")
    ap.add_argument("--self-check", action="store_true",
                    help="flag collisions within the catalog itself")
    ap.add_argument("--dir", help="directory of .qst files to check by filename stem")
    args = ap.parse_args()

    with open(PROV) as f:
        prov = json.load(f)

    if args.self_check:
        sys.exit(self_check(prov))

    names = list(args.names)
    if args.dir:
        for fn in sorted(os.listdir(args.dir)):
            if fn.lower().endswith(".qst"):
                names.append(os.path.splitext(fn)[0])
    if not names:
        ap.error("provide quest name(s), --dir, or --self-check")
    sys.exit(check_names(prov, names))


if __name__ == "__main__":
    main()
