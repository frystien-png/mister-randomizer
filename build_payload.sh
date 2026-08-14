#!/bin/bash
# Builds the MiSTer half of the distribution package from the RUNNING MiSTer.
#
# The MiSTer is the source - the code lives there, not here. This script
# fetches home what is to be distributed, leaves out anything personal, and
# packs a tarball that Randomizer_install.sh rolls out on the next user's
# machine.
#
#   ./build_payload.sh [MiSTer IP]
#
# Result: mister/randomizer-payload.tar.gz
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# The MiSTer's address comes from outside, never from the code:
#
#   ./build_payload.sh 192.168.1.50    argument
#   MISTER_IP=... ./build_payload.sh   environment variable
#   .mister-ip                         one line next to the script (git-ignored)
#
# ⚠️ The reason is that the repository is PUBLIC. A home address as a default
# in the code stays in the git history forever even if it is removed later,
# and it says something about somebody's network. Whoever clones this supplies
# their own.
MISTER="${1:-${MISTER_IP:-}}"
if [ -z "$MISTER" ] && [ -f "$HERE/.mister-ip" ]; then
    MISTER="$(tr -d ' \r\n' < "$HERE/.mister-ip")"
fi
if [ -z "$MISTER" ]; then
    echo "Give the MiSTer's address:" >&2
    echo "  ./build_payload.sh <ip>          or" >&2
    echo "  echo <ip> > $HERE/.mister-ip     (git-ignored, remembered next time)" >&2
    exit 1
fi
BUILD="$HERE/.build"
OUT="$HERE/mister/randomizer-payload.tar.gz"
# The logic files live in the parent directory and run both on the logic
# server and inside the HA add-on. The same file has to go to both.
SOURCE="$(cd "$HERE/.." && pwd)"
LOGIC="$HERE/smz3-logic/logic"

h_test() { ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$MISTER" true 2>&1; }

# ⚠️ The MiSTer is the source of half the package, so it has to be POWERED ON.
# It cannot be woken from here: the DE10-Nano does not support Wake-on-LAN at
# all (`ethtool eth0` reports "Supports Wake-on: d"), and `poweroff` only stops
# the SoC. Without this check the build instead dies on half a dozen scp
# errors, leaving half-finished files in .build.
if ! ANSWER="$(h_test)"; then
    echo "No contact with the MiSTer at $MISTER: ${ANSWER:-connection timed out}" >&2
    echo >&2
    echo "Switch it on and run again. It cannot be woken over the network -" >&2
    echo "the DE10-Nano has no Wake-on-LAN, the power has to be cut for real." >&2
    echo "The package already in mister/ is left untouched." >&2
    exit 1
fi

# ⚠️ The add-on's copies have to be refreshed HERE. The first version only
# built the MiSTer half, and the add-on's reachd.py then lagged behind without
# anything saying so - a fix to the logic landed on the logic server but not in
# what gets distributed. Found 2026-08-13 when a bottle fix existed in only
# half the places.
for f in reachd.py smz3_logic.py alttp_locmap.py; do
    if [ -f "$SOURCE/$f" ]; then
        cp -p "$SOURCE/$f" "$LOGIC/$f"
        echo "  addon/$f  <- $SOURCE/$f"
    else
        echo "  WARNING: cannot find $SOURCE/$f" >&2
    fi
done

echo "Building package from $MISTER"
rm -rf "$BUILD"
mkdir -p "$BUILD/mistergames" "$BUILD/randomizer" "$BUILD/scripts"

h() { ssh -o BatchMode=yes "root@$MISTER" "$@"; }

# ---------------------------------------------------------------- .mistergames
# The code and the data tables. NOT: ha_token and nas_credentials (secrets),
# ha_push.py and nas_mount.sh (a personal HA setup, not part of the randomizer
# package), backup-*/ and *.bak (working traces), *.pyc (rebuilt on their own
# and architecture-bound).
MG_FILES="server.py page.py seedpage.py annotatepage.py
          language.py lang_extract.py lang_check.py
          annotations.json chestflags.json sramflags.json smlocs.json
          smz3_locations.json skin-default.json skin-default.png sprites-sm.png"

for f in $MG_FILES; do
    echo "  .mistergames/$f"
    scp -q "root@$MISTER:/media/fat/Scripts/.mistergames/$f" "$BUILD/mistergames/$f"
done

# The language files. All except ones somebody added locally without sharing
# them - those are recognised by not being in this list.
echo "  .mistergames/lang/"
mkdir -p "$BUILD/mistergames/lang"
for f in TEMPLATE.json en.json sv.json es.json fr.json pl.json; do
    scp -q "root@$MISTER:/media/fat/Scripts/.mistergames/lang/$f" \
           "$BUILD/mistergames/lang/$f"
done

# User state: shipped EMPTY. progress.json, medallions.json and spoilers.json
# are per-seed notes and have no place in a package - but the files have to
# exist, or the first run gets an empty state to handle everywhere they are read.
for f in checks.json logic.json progress.json medallions.json spoilers.json; do
    echo "{}" > "$BUILD/mistergames/$f"
done

# The game browser ships with the package. It is plain HTML/CSS/JS without a
# single reference to anyone's network, and it builds its game list from
# /api/cores and /api/games - that is, from what is on the RECIPIENT'S SD card.
# No game names and absolutely no ROMs travel with the file.
#
# The receipt: the installer has to tell "the page.py I put there last time"
# (may be overwritten) from "the recipient's own browser" (must NEVER be
# overwritten). The copy is therefore stamped here - the original on the MiSTer
# is left alone, so it lacks the stamp and survives a reinstall on the machine
# it came from.
cat >> "$BUILD/mistergames/page.py" <<'PYEOF'

# >>> distributed with mister-randomizer >>>
# The stamp is added by build_payload.sh. The installer only overwrites a
# page.py that carries this line; a file without it is your own and is left
# untouched. Remove the line and your changes stop being overwritten.
PYEOF

# ------------------------------------------------------------------ .randomizer
# The generators. NOT: base/ (the user's own ROMs - must not be distributed),
# backup-*/ and *.pyc.
RND_FILES="gen_alttpr.py gen_smz3.py smz3build.py pngkrop.py
           fyll_samus_bilder.py zsm.ips"

for f in $RND_FILES; do
    echo "  .randomizer/$f"
    scp -q "root@$MISTER:/media/fat/Scripts/.randomizer/$f" "$BUILD/randomizer/$f"
done

for d in pyz3r bps; do
    echo "  .randomizer/$d/"
    mkdir -p "$BUILD/randomizer/$d"
    # Only .py - the .pyc files are rebuilt on their own at first run
    for f in $(h "ls /media/fat/Scripts/.randomizer/$d/*.py" | xargs -n1 basename); do
        scp -q "root@$MISTER:/media/fat/Scripts/.randomizer/$d/$f" \
               "$BUILD/randomizer/$d/$f"
    done
    # ⚠️ The licence files travel WITH the code, not just in the README.
    # pyz3r is Apache-2.0, which requires the licence text to be included and
    # modifications to be stated; bps is WTFPL and its own headers point at a
    # COPYING file. Vendoring the code without them is a licence violation,
    # quietly, in every copy that goes out.
    for f in LICENSE NOTICE COPYING; do
        scp -q "root@$MISTER:/media/fat/Scripts/.randomizer/$d/$f" \
               "$BUILD/randomizer/$d/$f" 2>/dev/null || true
    done
done

mkdir -p "$BUILD/randomizer/base"
cat > "$BUILD/randomizer/base/PUT_ROMS_HERE.txt" <<'EOF'
Your OWN original dumps go here:

  alttp.smc   1 048 576 bytes   md5 03a63945398191337e896e5771f77173
  sm.smc      3 145 728 bytes   md5 21f3e98df4780ee1c667b84e57d88675

(Zelda 3 Japanese 1.0 and Super Metroid JU respectively - both headerless.)

No ROMs ship with this package and none can. Run "Randomizer_install.sh"
again and it will look for them among your own SNES ROMs and copy them here.
EOF

# ---------------------------------------------------------------------- Scripts
for f in ALTTPR_new_seed.sh SMZ3_new_seed.sh; do
    echo "  Scripts/$f"
    scp -q "root@$MISTER:/media/fat/Scripts/$f" "$BUILD/scripts/$f"
done

# ------------------------------------------------------------------- the guard
# ⚠️ Nothing may be packed until the guard has had its say. The build fetches
# files from a real MiSTer full of ROMs, and one misspelled pattern above is
# enough to drag along something that must not be shared. The guard runs on the
# unpacked directory, BEFORE the tarball exists - so there is never a file to
# upload by accident.
echo
if ! "$HERE/check_payload.sh" "$BUILD"; then
    echo
    echo "Build aborted - no tarball written. $OUT is unchanged." >&2
    rm -rf "$BUILD"
    exit 1
fi

# ------------------------------------------------------------------------ pack
mkdir -p "$(dirname "$OUT")"
# ⚠️ --owner/--group/--numeric-owner. A tar archive stores the OWNER NAME of
# every file, and it is not visible in the extracted files - so the guard, which
# reads file contents, cannot see it either. Without these flags the builder's
# username travels inside the published tarball, in plain text, on every entry.
tar --owner=root --group=root --numeric-owner \
    -czf "$OUT" -C "$BUILD" mistergames randomizer scripts
rm -rf "$BUILD"

echo
echo "Done: $OUT ($(du -h "$OUT" | cut -f1))"
tar -tzf "$OUT" | sed 's/^/  /' | head -40
echo "  ... $(tar -tzf "$OUT" | wc -l) entries in total"
