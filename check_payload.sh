#!/bin/bash
# Checks that the distribution package contains NOT ONE ROM - or anything else
# that must not be shared.
#
#   ./check_payload.sh [tarball-or-directory]
#
# Default: mister/randomizer-payload.tar.gz
#
# Run automatically by build_payload.sh before the tarball is allowed to exist,
# but it also works by hand on a file you downloaded:
#   ./check_payload.sh ~/Downloads/randomizer-payload.tar.gz
#
# Exits with 0 = clean, 1 = something has to go.
#
# ⚠️ The guard is deliberately paranoid and stops things that merely "look
# like" a ROM. A false positive costs one line in the exception list below; a
# ROM that slips through costs considerably more.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$HERE/mister/randomizer-payload.tar.gz}"

# File extensions that must NEVER occur. ROMs, disc images and archives that
# could hide either.
# ⚠️ "md" is NOT in the list, even though Mega Drive ROMs use it: every
# README.md would then be flagged. A real .md ROM is still caught by the size
# and binary checks further down.
ROM_EXT='smc|sfc|fig|swc|srm|nes|unf|fds|gb|gbc|gba|n64|z64|v64|u64|
         smd|gen|bin|sms|gg|sg|col|pce|sgx|iso|cue|chd|img|ccd|mdf|
         nrg|cdi|gdi|a26|a52|a78|lnx|ngp|ngc|ws|wsc|vb|d64|adf|dsk|st|
         tap|cas|rom|zip|7z|rar|vhd'

# Exceptions: files that are LARGE or look binary but demonstrably belong.
# Every line has to be justifiable.
#   randomizer/zsm.ips  - SMZ3's own patch. An IPS is a LIST OF CHANGES applied
#                         to the user's own ROMs; it holds nothing of the
#                         original games and ships with every SMZ3 randomizer.
#                         Without it no seeds can be built.
#   mistergames/*.png   - the map images and sprite sheets the pages draw with.
EXCEPTIONS='^randomizer/zsm\.ips$|^mistergames/[a-z0-9-]+\.png$'

# Secrets and working traces that must not travel either.
FORBIDDEN_NAMES='ha_token|nas_credentials|\.pem$|id_rsa|id_ed25519|\.env$|
                 ^backup-|\.bak$|\.pyc$'

# Size limit. Anything larger has to be in EXCEPTIONS to get through - that is
# the rule which catches a ROM renamed to something innocent. The largest
# legitimate file (outside the exceptions) is seedpage.py at 104 K, so 400 K is
# plenty of headroom.
MAX_BYTES=$((400 * 1024))

# User state that must ship EMPTY - otherwise somebody's own notes are
# distributed and the next user gets a map full of progress that is not theirs.
MUST_BE_EMPTY='checks.json logic.json progress.json medallions.json spoilers.json'

# --- unpack if we were given a tarball ------------------------------------
CLEANUP=""
if [ -d "$TARGET" ]; then
    ROOT="$TARGET"
    SOURCE="the directory $TARGET"
elif [ -f "$TARGET" ]; then
    ROOT="$(mktemp -d)"
    CLEANUP="$ROOT"
    tar -xzf "$TARGET" -C "$ROOT" || { echo "Cannot unpack $TARGET" >&2; exit 1; }
    SOURCE="$TARGET ($(du -h "$TARGET" | cut -f1))"
else
    echo "Neither a file nor a directory: $TARGET" >&2
    exit 1
fi
trap '[ -n "$CLEANUP" ] && rm -rf "$CLEANUP"' EXIT

# The patterns above are written across several lines for readability - strip
# the line breaks and indentation before they are used.
join() { echo "$1" | tr -d ' \n'; }
RE_ROM="\.($(join "$ROM_EXT"))$"
RE_NAMES="$(join "$FORBIDDEN_NAMES")"

echo "Checking $SOURCE"
echo

FAULTS=0
complain() { echo "  [ROM?] $*"; FAULTS=$((FAULTS + 1)); }

# All paths relative to the package root, so the rules can be written the way
# they appear in the tarball.
# .git is left out: its objects are compressed and would only produce noise.
# What is already in the history is a different question from what is packed now.
FILES="$(cd "$ROOT" && find . -type f -not -path './.git/*' \
         | sed 's|^\./||' | sort)"

# Running the guard on the REPOSITORY itself rather than on a payload needs
# three more exceptions. They apply only here and would be dangerous in a
# payload:
#
#   check_payload.sh   contains the patterns and matches itself
#   the payload        is a tarball: binary and large by definition, and it is
#                      checked separately and more thoroughly by the build
#   git-ignored files  exist on disk but are never published (.mister-ip)
if [ -d "$ROOT/.git" ]; then
    echo "  (repository mode: skipping the guard itself, the payload and"
    echo "   anything git ignores - the payload is checked by build_payload.sh)"
    echo
    IGNORED=""
    if command -v git >/dev/null 2>&1; then
        IGNORED="$(cd "$ROOT" && git ls-files --others --ignored \
                   --exclude-standard 2>/dev/null)"
    fi
    KEEP=""
    for f in $FILES; do
        case "$f" in
            check_payload.sh|mister/randomizer-payload.tar.gz) continue ;;
        esac
        for i in $IGNORED; do
            [ "$f" = "$i" ] && continue 2
        done
        KEEP="$KEEP$f
"
    done
    FILES="$(echo "$KEEP" | grep -v '^$' | sort)"
fi

# --- 1. file extensions ---------------------------------------------------
while IFS= read -r f; do
    [ -n "$f" ] || continue
    echo "$f" | grep -qE "$EXCEPTIONS" && continue
    complain "ROM extension: $f"
done <<EOF
$(echo "$FILES" | grep -iE "$RE_ROM")
EOF

# --- 2. base/ must be empty apart from the note ---------------------------
while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$f" = "randomizer/base/PUT_ROMS_HERE.txt" ] && continue
    complain "sits in base/, where only the user's own ROMs belong: $f"
done <<EOF
$(echo "$FILES" | grep '^randomizer/base/')
EOF

# --- 3. size --------------------------------------------------------------
while IFS= read -r f; do
    [ -n "$f" ] || continue
    echo "$f" | grep -qE "$EXCEPTIONS" && continue
    n=$(stat -c %s "$ROOT/$f")
    [ "$n" -le "$MAX_BYTES" ] && continue
    complain "$((n / 1024)) K - larger than the $((MAX_BYTES / 1024)) K limit: $f"
done <<EOF
$FILES
EOF

# --- 4. secrets and working traces ----------------------------------------
while IFS= read -r f; do
    [ -n "$f" ] || continue
    complain "must not be distributed: $f"
done <<EOF
$(echo "$FILES" | grep -E "$RE_NAMES")
EOF

# --- 4b. leaked network details and secrets -------------------------------
# ⚠️ This is the check that is hardest to do by eye. An IP address from a home
# network, a NAS name or the tail of a token looks innocent in a diff but stays
# in a public repository forever. The rules are deliberately broad: better one
# line in the exceptions than an address out on GitHub.
#
# Addresses in the documentation SHOULD be writable. They then have to be clear
# examples - 192.168.1.50 and 192.168.1.x - and nothing else.
IP_EXAMPLES='192\.168\.1\.50|192\.168\.1\.x|127\.0\.0\.1|0\.0\.0\.0'

# Private addresses (RFC 1918), MAC addresses, and anything that looks like a
# secret.
LEAKS='(^|[^0-9.])(10\.[0-9]{1,3}|192\.168\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3})\.[0-9]{1,3}
      |([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}
      |username=|password=|passwd=|psk=
      |Bearer [A-Za-z0-9_-]{20}|eyJ[A-Za-z0-9_-]{20}
      |BEGIN [A-Z ]*PRIVATE KEY'

# Mail addresses are their own rule, because LICENCE FILES legitimately carry
# one - the WTFPL text names Sam Hocevar with his address, and refusing to ship
# it would mean shipping the code without its licence. Everywhere else an
# address is a leak.
MAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# ⚠️ Your own words - machine names, share names, user names - do NOT belong
# here. The first version listed them in plain text, which put them in a public
# file in order to look for themselves. They go in .private-words next to the
# script instead, one regex per line, and that file is git-ignored:
#
#     my-server
#     MyNasShare
#     /home/myname
#
# Without the file only the general patterns above are checked.
PRIVATE="$HERE/.private-words"
if [ -f "$PRIVATE" ]; then
    EXTRA="$(grep -v '^[[:space:]]*\(#\|$\)' "$PRIVATE" | tr '\n' '|' | sed 's/|$//')"
    [ -n "$EXTRA" ] && LEAKS="$LEAKS|$EXTRA"
fi

RE_LEAK="$(join "$LEAKS")|$(join "$MAIL")"
RE_LEAK_LICENCE="$(join "$LEAKS")"

# ⚠️ The hits are collected in a file rather than counted in the loop. A while
# loop behind a pipe runs in a SUBSHELL, so a counter incremented there is back
# to zero when the loop ends - the faults would have been reported but never
# stopped the build.
HITS="$(mktemp)"
trap '[ -n "$CLEANUP" ] && rm -rf "$CLEANUP"; rm -f "$HITS"' EXIT

for f in $FILES; do
    # Text files only - a PNG full of random bytes would otherwise false-alarm.
    case "$(file -b --mime "$ROOT/$f" 2>/dev/null)" in
        text/*|*charset=us-ascii|*charset=utf-8) ;;
        *) continue ;;
    esac
    # A licence file is judged without the mail rule - see MAIL above.
    re="$RE_LEAK"
    case "$(basename "$f")" in
        LICENSE|LICENCE|COPYING|NOTICE) re="$RE_LEAK_LICENCE" ;;
    esac
    # Known example addresses are removed BEFORE the judgement.
    grep -nE "$re" "$ROOT/$f" 2>/dev/null \
        | grep -vE "$IP_EXAMPLES" \
        | cut -c1-120 \
        | sed "s|^|$f:|" >> "$HITS"
done

while IFS= read -r line; do
    [ -n "$line" ] || continue
    complain "network detail or secret: $line"
done < "$HITS"

# --- 4c. the archive's own metadata ---------------------------------------
# ⚠️ A tar archive stores an owner name per entry, and unpacking throws it away
# - so every check above, which works on the extracted files, is blind to it.
# The builder's username otherwise ships inside the tarball on every single
# file. Only checked when we were handed an archive.
if [ -n "$CLEANUP" ]; then
    OWNERS="$(tar -tvzf "$TARGET" 2>/dev/null | awk '{print $2}' | sort -u)"
    for o in $OWNERS; do
        case "$o" in
            root/root|0/0) continue ;;
        esac
        complain "the archive is owned by \"$o\" - rebuild with tar --owner=root --group=root --numeric-owner"
    done
fi

# --- 5. user state must be empty ------------------------------------------
for f in $MUST_BE_EMPTY; do
    p="$ROOT/mistergames/$f"
    [ -f "$p" ] || continue
    content="$(tr -d ' \n\r' < "$p")"
    [ "$content" = "{}" ] && continue
    complain "$f is not empty ($(stat -c %s "$p") bytes) - those are somebody's own notes"
done

# --- 6. last net: binary content none of the above caught -----------------
# A file without text content that is NOT one of the known images or patches
# has no business in the package. Catches a ROM that has been both renamed and
# truncated.
while IFS= read -r f; do
    [ -n "$f" ] || continue
    echo "$f" | grep -qE "$EXCEPTIONS" && continue
    # Empty files (package __init__.py, for one) are reported by `file` as
    # "inode/x-empty" and are by definition not ROMs.
    [ -s "$ROOT/$f" ] || continue
    kind="$(file -b --mime "$ROOT/$f")"
    case "$kind" in
        text/*|*charset=us-ascii|*charset=utf-8) continue ;;
    esac
    complain "binary file of unknown type ($kind): $f"
done <<EOF
$FILES
EOF

echo
COUNT="$(echo "$FILES" | wc -l)"
if [ "$FAULTS" -gt 0 ]; then
    echo "STOP: $FAULTS thing(s) out of $COUNT must not be distributed."
    echo "Remove them from the build, or add a justified line to EXCEPTIONS."
    exit 1
fi
echo "Clean: $COUNT files, no ROMs, no secrets, empty user state."
exit 0
