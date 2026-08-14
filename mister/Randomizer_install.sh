#!/bin/bash
# ============================================================================
#  ALTTPR/SMZ3 randomizer + game browser for MiSTer FPGA
#
#  Installs two things that share one small web server:
#    * the seed page   - generate, pick and follow ALTTPR and SMZ3 seeds
#    * the game browser - launch any game from your phone
#
#  ⚠️ NO ROMS SHIP WITH THIS. The browser lists the games already on YOUR SD
#  card; if it finds none, you have none to list. The base ROMs for seed
#  generation must be your own as well (step 6 looks for them).
#
#  Put this file in /media/fat/Scripts/ and run it from the MiSTer menu
#  (Scripts -> Randomizer_install). It can be re-run at any time; nothing you
#  already have is overwritten needlessly.
#
#  Requirements: a MiSTer FPGA and a Home Assistant server (HA OS or
#  Supervised) with the add-on "SMZ3 and ALTTPR logic" installed.
# ============================================================================
set -uo pipefail

VERSION="1.2.0"

# Where the package is fetched from if it is not already next to this script.
# That way it is enough to put THIS file in Scripts/ - it fetches the rest
# itself, the same way update_all.sh does.
PAYLOAD_URL="${PAYLOAD_URL:-https://raw.githubusercontent.com/frystien-png/mister-randomizer/main/mister/randomizer-payload.tar.gz}"

# FAT can be pointed somewhere else to rehearse the installation without
# touching a real setup: FAT=/tmp/test ./Randomizer_install.sh
# In that mode no running server is touched either.
FAT="${FAT:-/media/fat}"
TESTMODE=0
[ "$FAT" = "/media/fat" ] || TESTMODE=1
SCRIPTS="$FAT/Scripts"
MG="$SCRIPTS/.mistergames"
RND="$SCRIPTS/.randomizer"
STARTUP="$FAT/linux/user-startup.sh"
CONF="$MG/randomizer.conf"
OLD_CONF="$MG/logik.conf"          # name used up to and including 1.1.0
MARK_START="# >>> randomizer install >>>"
MARK_END="# <<< randomizer install <<<"

# The user's own notes. They are NEVER overwritten on a reinstall -
# progress.json holds their dungeon rewards, spoilers.json what they chose to
# look at. Zeroing those on an update would erase their run.
KEEP="progress.json medallions.json spoilers.json checks.json logic.json
      annotations.json"

# --- output ---------------------------------------------------------------
heading() { echo; echo "=== $* ==="; }
ok()      { echo "  [ok]   $*"; }
info()    { echo "         $*"; }
warn()    { echo "  [!]    $*"; }
err()     { echo "  [FAIL] $*" >&2; }

abort() {
    err "$*"
    echo
    echo "Installation aborted. Nothing half-finished was left outside $MG."
    press_key
    exit 1
}

# Fetches a file over HTTPS.
#
# ⚠️ The MiSTer's system certificates (/etc/ssl/certs/cacert.pem) are from JULY
# 2021 and do not recognise GitHub's current certificate. A plain `curl` dies
# on "unable to get local issuer certificate". Hence three attempts, in order -
# and NEVER --insecure, which would only hide the problem.
fetch() {
    url="$1"; dest="$2"

    # 1. The certificate list update_all.sh keeps fresh. Present on most
    #    MiSTers, since nearly everyone has run Update All at some point.
    dl_ca="$SCRIPTS/.config/downloader/cacert.pem"
    if [ -f "$dl_ca" ] \
       && curl -fsSL --connect-timeout 15 --cacert "$dl_ca" -o "$dest" "$url" 2>/dev/null; then
        return 0
    fi

    # 2. The system's own list - works on a MiSTer with newer firmware.
    curl -fsSL --connect-timeout 15 -o "$dest" "$url" 2>/dev/null && return 0

    # 3. wget has its OWN, newer certificate list (128 certificates) and copes
    #    with GitHub where curl fails. Measured to verify for real: it rejects
    #    both expired and self-signed certificates.
    wget -q -T 15 -O "$dest" "$url" 2>/dev/null && return 0

    rm -f "$dest"
    return 1
}

press_key() {
    echo
    echo "Press any key to close."
    read -r -n 1 -s 2>/dev/null || true
    echo
}

echo "============================================================"
echo " Randomizer for MiSTer FPGA - installation $VERSION"
echo "============================================================"

[ -d "$FAT" ] || abort "Cannot find $FAT. Is this running on a MiSTer?"

# ==========================================================================
# 1. The package
# ==========================================================================
heading "1/8  Fetching the package"

HERE="$(cd "$(dirname "$0")" && pwd)"
TAR=""
for candidate in "$HERE/randomizer-payload.tar.gz" \
                 "$SCRIPTS/randomizer-payload.tar.gz"; do
    if [ -f "$candidate" ]; then TAR="$candidate"; break; fi
done

TMP="$(mktemp -d "$FAT/Scripts/.rndinst.XXXXXX" 2>/dev/null)" \
    || abort "Cannot create a working directory on the SD card."
# Clean up the working directory even if the script is interrupted halfway.
trap 'rm -rf "$TMP"' EXIT

if [ -n "$TAR" ]; then
    ok "using the package next to the script"
    info "$TAR"
elif [ -n "$PAYLOAD_URL" ]; then
    info "downloading from $PAYLOAD_URL"
    TAR="$TMP/payload.tar.gz"
    if ! fetch "$PAYLOAD_URL" "$TAR"; then
        err "The download failed."
        echo
        echo "  The usual cause is the MiSTer's old certificate list, which"
        echo "  does not recognise GitHub's certificate. Two ways to fix it:"
        echo
        echo "    1. Run Scripts -> update_all once. It installs a fresh"
        echo "       certificate list which this installer then finds on its"
        echo "       own."
        echo
        echo "    2. Or download the package on a computer and put the file"
        echo "       randomizer-payload.tar.gz next to this script:"
        echo "       $PAYLOAD_URL"
        echo
        abort "Cannot continue without the package."
    fi
    ok "downloaded ($(du -h "$TAR" | cut -f1))"
else
    abort "No package found. Put randomizer-payload.tar.gz next to this
         script, or set PAYLOAD_URL at the top of it."
fi

tar -xzf "$TAR" -C "$TMP" || abort "The package cannot be unpacked."
[ -d "$TMP/mistergames" ] && [ -d "$TMP/randomizer" ] \
    || abort "The package does not look right."
ok "package unpacked"

# ==========================================================================
# 2. Laying out the files
# ==========================================================================
heading "2/8  Laying out the files"

mkdir -p "$MG" "$RND" || abort "Cannot create $MG"

# Set aside what belongs to the user before we copy over the top.
SAVED="$TMP/saved"
mkdir -p "$SAVED"
for f in $KEEP; do
    [ -f "$MG/$f" ] && cp -p "$MG/$f" "$SAVED/$f"
done

# ⚠️ page.py is the game browser, and it may well be YOUR own - several people
# have built one themselves. The package's copy is stamped by
# build_payload.sh, so we can tell them apart:
#
#   no page.py           -> ours is put there
#   stamped page.py      -> ours from last time, updated
#   placeholder from 1.0 -> the old stub, replaced by the real browser
#   unstamped page.py    -> YOURS. Left alone. Ours is placed next to it as
#                           page.py.new so you can look at it in peace
STAMP="distributed with mister-randomizer"
INSTALL_PAGE=1
if [ -f "$MG/page.py" ]; then
    if grep -q "$STAMP" "$MG/page.py" 2>/dev/null; then
        info "page.py: updating the game browser from the package"
    elif grep -q "Attrapp\|placeholder" "$MG/page.py" 2>/dev/null; then
        info "page.py: replacing the old placeholder with the real browser"
    else
        INSTALL_PAGE=0
        cp -p "$TMP/mistergames/page.py" "$MG/page.py.new" 2>/dev/null
        ok "page.py: you have a browser of your own - it is left untouched"
        info "the package's version is at $MG/page.py.new if you want to compare"
    fi
fi
[ "$INSTALL_PAGE" = "1" ] || rm -f "$TMP/mistergames/page.py"

# -r is needed: lang/ is a directory, and without the flag cp skips it and
# returns an error on top of that - which aborted the whole installation.
# Your own language files in lang/ survive: cp adds and never removes.
cp -rp "$TMP"/mistergames/* "$MG"/ 2>/dev/null \
    || abort "Cannot copy to $MG"
cp -rp "$TMP"/randomizer/* "$RND"/ 2>/dev/null \
    || abort "Cannot copy to $RND"

# Put the user's own files back.
RESTORED=0
for f in $KEEP; do
    if [ -f "$SAVED/$f" ]; then
        cp -p "$SAVED/$f" "$MG/$f"
        RESTORED=$((RESTORED + 1))
    fi
done
[ "$RESTORED" -gt 0 ] && ok "kept $RESTORED of your own files (notes, map markers)"

# Old .pyc files must not stay - they are built from the previous version and
# Python silently prefers them if the timestamps happen to look right.
rm -f "$MG"/*.pyc "$RND"/*.pyc "$RND"/*/*.pyc 2>/dev/null

# Menu entries from before 1.2.0 had Swedish names. Remove them, or the menu
# shows both the old and the new one and they do the same thing.
rm -f "$SCRIPTS/ALTTPR_ny_seed.sh" "$SCRIPTS/SMZ3_ny_seed.sh" 2>/dev/null

for f in ALTTPR_new_seed.sh SMZ3_new_seed.sh; do
    cp -p "$TMP/scripts/$f" "$SCRIPTS/$f" && chmod +x "$SCRIPTS/$f"
done
ok "menu entries ALTTPR_new_seed and SMZ3_new_seed in place"
ok "files laid out in .mistergames/ and .randomizer/"

# The settings file was called logik.conf up to 1.1.0. Carry it over rather
# than silently starting from scratch - it holds the language choice and the
# Home Assistant address.
if [ -f "$OLD_CONF" ] && [ ! -f "$CONF" ]; then
    sed 's/^SPRAK=/MISTER_LANG=/' "$OLD_CONF" > "$CONF" && rm -f "$OLD_CONF"
    ok "settings carried over from logik.conf to randomizer.conf"
fi

# ==========================================================================
# 3. Language
# ==========================================================================
heading "3/8  Language"

# The pages are written in English and translated as they are served, using
# the dictionaries in .mistergames/lang/. The menu is built from the files
# ACTUALLY in there - drop your own de.json in and German shows up here
# without this file needing a single change.
CHOSEN_LANG=""
[ -f "$CONF" ] && CHOSEN_LANG="$(sed -n 's/^MISTER_LANG=//p' "$CONF" | tr -d '"' | head -1)"

LANG_DIR="$MG/lang"
LANG_CODES=""
if [ -d "$LANG_DIR" ]; then
    # English first - it is the default. Then the rest alphabetically.
    for f in "$LANG_DIR"/en.json $(ls "$LANG_DIR"/*.json 2>/dev/null | grep -v '/en\.json$'); do
        [ -f "$f" ] || continue
        code="$(basename "$f" .json)"
        [ "$code" = "TEMPLATE" ] && continue
        LANG_CODES="$LANG_CODES $code"
    done
fi

if [ -z "$LANG_CODES" ]; then
    warn "no language files found - the pages are shown in English"
else
    # The language's own name is in the file as "__name". No python dependency
    # for something this small: the line is picked out with sed.
    name_of() {
        n="$(sed -n 's/.*"__name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
             "$LANG_DIR/$1.json" | head -1)"
        [ -n "$n" ] && echo "$n" || echo "$1"
    }

    echo
    i=0
    DEFAULT=1
    for code in $LANG_CODES; do
        i=$((i + 1))
        [ "$code" = "${CHOSEN_LANG:-en}" ] && DEFAULT=$i
        printf "    %d) %-12s (%s)\n" "$i" "$(name_of "$code")" "$code"
    done
    echo
    printf "  Choose language [%d]: " "$DEFAULT"
    read -r answer
    answer="$(echo "$answer" | tr -d ' \r')"
    [ -n "$answer" ] || answer="$DEFAULT"

    CHOSEN_LANG=""
    i=0
    for code in $LANG_CODES; do
        i=$((i + 1))
        [ "$i" = "$answer" ] && CHOSEN_LANG="$code"
        [ "$code" = "$answer" ] && CHOSEN_LANG="$code"   # "fr" also works
    done
    if [ -z "$CHOSEN_LANG" ]; then
        CHOSEN_LANG="en"
        warn "did not understand the choice - using English"
    fi
    ok "language: $(name_of "$CHOSEN_LANG") ($CHOSEN_LANG)"
    info "Your own language? Copy lang/TEMPLATE.json to lang/<code>.json,"
    info "translate it, and run this installer again."
fi

# ==========================================================================
# 4. Home Assistant's address
# ==========================================================================
heading "4/8  Looking for Home Assistant"

MY_IP="$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p')"
[ -n "$MY_IP" ] || MY_IP="(unknown)"
info "the MiSTer's own address: $MY_IP"

# Does something on :8123 answer that looks like Home Assistant?
is_ha() {
    curl -sf -m 5 -o /dev/null "http://$1:8123/" 2>/dev/null
}

resolve() {
    # ⚠️ busybox nslookup also prints the DNS server's own address, and that
    # line ends in ":53". Take only addresses without a port, and skip
    # localhost.
    nslookup "$1" 2>/dev/null \
        | awk '/^Address/ {print $NF}' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
        | grep -v '^127\.' \
        | head -1
}

HA_IP=""
PREVIOUS=""
[ -f "$CONF" ] && PREVIOUS="$(sed -n 's/^HA_IP=//p' "$CONF" | tr -d '"' | head -1)"

if [ -n "$PREVIOUS" ] && is_ha "$PREVIOUS"; then
    HA_IP="$PREVIOUS"
    ok "using the address from the last installation: $HA_IP"
else
    # ⚠️ The MiSTer cannot resolve .local - nsswitch is "files dns" and there
    # is no avahi. HA's own mDNS announcement is therefore useless from here,
    # even though an ordinary computer on the same network finds it at once.
    # The router's DHCP name "homeassistant" without a suffix does work.
    for name in homeassistant homeassistant.local hassio; do
        candidate="$(resolve "$name")"
        [ -n "$candidate" ] || continue
        info "$name -> $candidate, checking :8123 ..."
        # ⚠️ The hit has to be verified. Otherwise an arbitrary machine that
        # happens to be called "homeassistant" can be chosen, and the mistake
        # only shows up many steps later.
        if is_ha "$candidate"; then
            HA_IP="$candidate"
            ok "Home Assistant found at $HA_IP (via $name)"
            break
        fi
        info "  did not answer on :8123, moving on"
    done
fi

if [ -z "$HA_IP" ]; then
    warn "did not find Home Assistant automatically."
    NET="$(echo "$MY_IP" | sed 's/\.[0-9]*$/./')"
    echo
    echo "  Enter the server's IP address. The MiSTer is on ${NET}x,"
    echo "  so it is probably on the same network."
    echo
    while :; do
        printf "  Home Assistant's IP (empty = skip): "
        read -r answer
        answer="$(echo "$answer" | tr -d ' \r')"
        [ -z "$answer" ] && { warn "skipping - fill $CONF in later"; break; }
        if is_ha "$answer"; then
            HA_IP="$answer"; ok "answers on :8123 - accepted"; break
        fi
        warn "no Home Assistant answered at http://$answer:8123/ - try again"
    done
fi

# The address is kept in a small file of its own rather than in the code, so
# it can be changed without reinstalling: edit randomizer.conf and restart.
# ⚠️ The file is written EVEN when Home Assistant was not found. The language
# choice lives here too, and the first version only wrote the file if HA_IP
# existed - so anyone who skipped Home Assistant lost their language silently.
{
    echo "# Settings for the randomizer server. Change them here and restart"
    echo "# the MiSTer - the installer does not have to be run again."
    echo ""
    echo "# The language of the pages. The codes are the file names in"
    echo "# .mistergames/lang/."
    echo "MISTER_LANG=\"${CHOSEN_LANG:-en}\""
    if [ -n "$HA_IP" ]; then
        echo ""
        echo "# The Home Assistant add-on that runs the reachability logic."
        echo "HA_IP=\"$HA_IP\""
        echo "REACHD_URL=\"http://$HA_IP:8183/reach\""
        echo "SMZ3_REACH_URL=\"http://$HA_IP:8183/smz3reach\""
    fi
} > "$CONF"
ok "settings saved in $CONF"

if [ -n "$HA_IP" ]; then
    if curl -sf -m 5 -o /dev/null "http://$HA_IP:8183/health" 2>/dev/null; then
        ok "the logic add-on answers at $HA_IP:8183"
    else
        warn "the add-on does NOT answer at $HA_IP:8183 yet."
        info "Install and start \"SMZ3 and ALTTPR logic\" in Home Assistant."
        info "The map still works, just without coloured dots."
    fi
fi

# ==========================================================================
# 5. Autostart
# ==========================================================================
heading "5/8  Autostart at boot"

# ⚠️ user-startup.sh must be APPENDED to, never overwritten. The file can hold
# other people's own lines (NAS mounts, core status to HA), and an installer
# that overwrites it destroys their setup.
mkdir -p "$(dirname "$STARTUP")"
if [ ! -f "$STARTUP" ]; then
    cat > "$STARTUP" <<'EOF'
#!/bin/sh
# S99user calls us with start|stop|restart - only start on start/restart
case "$1" in
    stop) exit 0;;
esac
EOF
    chmod +x "$STARTUP"
    ok "created $STARTUP"
fi

# ⚠️ The file MUST be called user-startup.sh without an underscore.
# /etc/init.d/S99user only starts that variant; a file called
# _user-startup.sh is never run, and everything looks fine anyway until the
# next reboot.
if [ -f "$FAT/linux/_user-startup.sh" ] && [ ! -s "$STARTUP" ]; then
    warn "there is a _user-startup.sh with an underscore - it NEVER runs."
    info "Rename it to user-startup.sh if it contains anything you want."
fi

# Is somebody other than us already starting server.py from here? Then we must
# not add a second start line: the new process would die silently on "Address
# already in use" while the old one keeps serving.
OTHER_START=0
if grep -q '\.mistergames/server\.py' "$STARTUP" 2>/dev/null; then
    if ! sed -n "/$MARK_START/,/$MARK_END/p" "$STARTUP" 2>/dev/null \
         | grep -q '\.mistergames/server\.py'; then
        OTHER_START=1
    fi
fi

# Idempotence: if our block is already there, cut it out and add a new one.
if grep -qF "$MARK_START" "$STARTUP" 2>/dev/null; then
    sed -i "/$MARK_START/,/$MARK_END/d" "$STARTUP"
    info "replacing the block from the previous installation"
fi
# The marker was Swedish up to 1.1.0 - remove that block too, or the server
# gets started twice.
if grep -qF "# >>> randomizer-installation >>>" "$STARTUP" 2>/dev/null; then
    sed -i "/# >>> randomizer-installation >>>/,/# <<< randomizer-installation <<</d" "$STARTUP"
    info "removed the block from a pre-1.2.0 installation"
fi

BLOCKFILE="$TMP/block.sh"
{
    echo ""
    echo "$MARK_START"
    echo "# The randomizer server. The logic service's address is read from"
    echo "# randomizer.conf, so it can be changed without touching this file."
    echo "if [ -f $CONF ]; then"
    echo "    . $CONF"
    echo "    export MISTER_LANG REACHD_URL SMZ3_REACH_URL"
    echo "fi"
    if [ "$OTHER_START" = "1" ]; then
        echo "# The server is already started below - we only set the"
        echo "# addresses, so that start line picks them up."
    else
        echo "if [ -f $MG/server.py ]; then"
        echo "    setsid nohup python3 $MG/server.py \\"
        echo "        > /tmp/mistergames.log 2>&1 < /dev/null &"
        echo "fi"
    fi
    echo "$MARK_END"
    echo ""
} > "$BLOCKFILE"

if [ "$OTHER_START" = "1" ]; then
    # ⚠️ The block MUST end up BEFORE the existing start line. Put it last in
    # the file and the server has already started by the time the variables
    # are set, and it carries on against the default address - without a
    # single error message.
    awk -v bf="$BLOCKFILE" '
        !done_ && /\.mistergames\/server\.py/ {
            while ((getline line < bf) > 0) print line
            close(bf); done_ = 1
        }
        { print }
    ' "$STARTUP" > "$TMP/startup.new" \
        && cat "$TMP/startup.new" > "$STARTUP" \
        || abort "Could not update $STARTUP"
    ok "your existing start line is kept - the addresses are set before it"
else
    cat "$BLOCKFILE" >> "$STARTUP"
    ok "the server starts automatically at boot"
fi
chmod +x "$STARTUP"

# ==========================================================================
# 6. The base ROMs
# ==========================================================================
heading "6/8  Checking the base ROMs"

# No ROMs ship with this and none can. The user has to have their own original
# dumps. Most people already have them among their SNES ROMs, so we look.
mkdir -p "$RND/base"
ALTTP_MD5=03a63945398191337e896e5771f77173
SM_MD5=21f3e98df4780ee1c667b84e57d88675

md5_of() { md5sum "$1" 2>/dev/null | cut -d' ' -f1; }

# ⚠️ Many SNES dumps carry a 512-byte header. Such a copy is 1 048 576 + 512
# bytes and gets a COMPLETELY different md5. Strip the first 512 bytes and it
# matches - without that step the user is told "wrong ROM" even though the ROM
# is right.
md5_without_header() {
    dd if="$1" bs=512 skip=1 2>/dev/null | md5sum | cut -d' ' -f1
}

# Tests a file against the right sum. Writes it to base/ on a hit.
try_rom() {
    src="$1"; expected="$2"; dest="$3"
    [ -f "$src" ] || return 1
    if [ "$(md5_of "$src")" = "$expected" ]; then
        cp -f "$src" "$RND/base/$dest" && return 0
    fi
    if [ "$(md5_without_header "$src")" = "$expected" ]; then
        dd if="$src" bs=512 skip=1 of="$RND/base/$dest" 2>/dev/null && return 0
    fi
    return 1
}

have_rom() {
    [ -f "$RND/base/$1" ] && [ "$(md5_of "$RND/base/$1")" = "$2" ]
}

SEARCH="$FAT/games/SNES"
searched=0

for pair in "alttp.smc:$ALTTP_MD5:1048576:zelda|link|triforce|kamigami" \
            "sm.smc:$SM_MD5:3145728:metroid"; do
    dest="${pair%%:*} "; dest="${dest% }"
    rest="${pair#*:}"; expected="${rest%%:*}"
    rest="${rest#*:}"; size="${rest%%:*}"
    pattern="${rest#*:}"

    if have_rom "$dest" "$expected"; then
        ok "$dest is already there and matches"
        continue
    fi

    [ "$searched" = "0" ] && { info "looking through your SNES ROMs ..."; searched=1; }
    found=0

    # Step 1: plain files of exactly the right size (with or without header).
    # The size filter makes the search cheap even in a collection of thousands
    # of ROMs - md5 only has to be computed for a handful.
    if [ -d "$SEARCH" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            if try_rom "$f" "$expected" "$dest"; then
                ok "$dest found: $f"; found=1; break
            fi
        done <<EOF
$(find "$SEARCH" -type f \( -size ${size}c -o -size $((size + 512))c \) 2>/dev/null)
EOF
    fi

    # Step 2: inside zip archives. The MiSTer reads ROMs straight out of .zip,
    # so most people keep their whole collection packed. Filter by name first -
    # otherwise we would unpack hundreds of archives for nothing.
    if [ "$found" = "0" ] && [ -d "$SEARCH" ]; then
        while IFS= read -r z; do
            [ -n "$z" ] || continue
            rm -rf "$TMP/zip"; mkdir -p "$TMP/zip"
            unzip -o -q -j "$z" -d "$TMP/zip" 2>/dev/null || continue
            for f in "$TMP/zip"/*; do
                if try_rom "$f" "$expected" "$dest"; then
                    ok "$dest found in $(basename "$z")"; found=1; break
                fi
            done
            [ "$found" = "1" ] && break
        done <<EOF
$(find "$SEARCH" -type f -name '*.zip' 2>/dev/null | grep -i -E "$pattern")
EOF
        rm -rf "$TMP/zip"
    fi

    if [ "$found" = "0" ]; then
        warn "$dest was not found."
        info "Put your own original dump here:"
        info "  $RND/base/$dest"
        info "  size $size bytes, md5 $expected"
        info "Then run this installer again - it will find it."
    fi
done

have_rom alttp.smc "$ALTTP_MD5" && have_rom sm.smc "$SM_MD5" \
    && ok "both base ROMs in place - seed generation works" \
    || warn "the map and tracker work anyway; only generating new seeds
         needs the base ROMs."

# ==========================================================================
# 7. SNI - live reading of SNES memory (optional)
# ==========================================================================
heading "7/8  Live reading of SNES memory (SNI)"

# Without this the tracker still works, but it only sees what has been written
# to the SD card - that is, only when you open the OSD menu. With SNI the
# server reads the game's memory directly and the map follows along as you
# play.
#
# Three parts are required. Two of them are already in MiSTer's own
# distribution (the SNES core since March 2026 and the main binary since
# April); what is missing is the daemon itself, distributed separately.
SNID_URL="https://github.com/NobodyNada/snid/releases/download/20260607_1/snid"
SNID_SHA=71b4a76ccb3e1728253a801e05bb6d91970589e9c2fd44813a281fb7b1b89b93
SNID="$FAT/snid"
# Overridable so that the riskiest branch - writing into the read-only system
# image - can be rehearsed against a copy instead of for real.
UARTMODE="${UARTMODE:-/usr/sbin/uartmode}"

# Does the main binary support SNI at all? It looks for the daemon at a fixed
# path, so the string is in the binary on every version that can do it.
if ! grep -q "media/fat/snid" "$FAT/MiSTer" 2>/dev/null; then
    warn "your MiSTer binary is too old for SNI - skipping."
    info "Run Scripts -> update_all and the support comes with it."
elif [ -f "$SNID" ] && [ "$(sha256sum "$SNID" | cut -d' ' -f1)" = "$SNID_SHA" ]; then
    ok "snid is already there and matches"
else
    echo
    echo "  Live reading makes the map update WHILE you play, instead of"
    echo "  only when you open the OSD menu. It needs a 7 MB download"
    echo "  (snid, by NobodyNada)."
    echo
    printf "  Install it? [Y/n]: "
    read -r answer
    case "$answer" in
        [nN]*) info "skipping - can be installed later by re-running this" ;;
        *)
            if fetch "$SNID_URL" "$TMP/snid"; then
                got="$(sha256sum "$TMP/snid" | cut -d' ' -f1)"
                if [ "$got" != "$SNID_SHA" ]; then
                    # Half a download or a substituted file - better to run without.
                    warn "snid has the wrong checksum, NOT installed."
                    info "expected $SNID_SHA"
                    info "got      $got"
                else
                    cp -f "$TMP/snid" "$SNID" && chmod +x "$SNID"
                    ok "snid installed ($(du -h "$SNID" | cut -f1))"
                fi
            else
                warn "could not fetch snid - see the note about certificates above."
            fi
            ;;
    esac
fi

# ⚠️ /usr/sbin/uartmode has to know about mode 6, or the daemon is never
# started when you pick SNI in the menu. The script lives in the READ-ONLY
# linux.img, which update_all does not touch - on a MiSTer that has been around
# a while it is therefore still stuck at modes 1-5. We do not touch the rootfs
# without asking.
if [ -x "$SNID" ] && ! grep -q "uartmode6" "$UARTMODE" 2>/dev/null; then
    echo
    echo "  The system file $UARTMODE is too old and does not know about"
    echo "  the SNI mode. Without it the daemon never starts."
    echo
    echo "  It lives in the MiSTer's read-only system image. I can update"
    echo "  it - a copy of the original is saved on the SD card as"
    echo "  uartmode.original, and a firmware update can later overwrite"
    echo "  the change (run this installer again if it does)."
    echo
    printf "  Update the system file? [Y/n]: "
    read -r answer
    case "$answer" in
        [nN]*) warn "skipping - SNI will not start" ;;
        *)
            if fetch "https://raw.githubusercontent.com/MiSTer-devel/MiSTer_MidiLink/master/uartmode" \
                     "$TMP/uartmode" && grep -q "uartmode6" "$TMP/uartmode"; then
                cp -p "$UARTMODE" "$FAT/uartmode.original" 2>/dev/null
                RW=0
                if [ "$TESTMODE" = "1" ]; then
                    RW=1              # rehearsal: the file is not in the rootfs
                elif mount -o remount,rw / 2>/dev/null; then
                    RW=1
                fi
                if [ "$RW" = "1" ]; then
                    cp "$TMP/uartmode" "$UARTMODE" && chmod +x "$UARTMODE"
                    # ⚠️ Back to read-only NO MATTER how the copy went. Leave
                    # the rootfs writable and a power cut risks damaging the
                    # system image.
                    [ "$TESTMODE" = "1" ] || mount -o remount,ro / 2>/dev/null
                    ok "system file updated (original: uartmode.original)"
                else
                    warn "could not make the system image writable"
                fi
            else
                warn "could not fetch a uartmode script with mode 6"
            fi
            ;;
    esac
fi

if [ -x "$SNID" ]; then
    echo
    info "THE LAST STEP IS YOURS, once:"
    info "  start a SNES game, open the OSD menu and choose"
    info "  UART MODE -> SNI"
    info "The choice is saved per core and restored automatically."
    info "It cannot be done for you from here: the mode is sent to the"
    info "core by the menu, not by any file."
fi

# ==========================================================================
# 8. Starting the server
# ==========================================================================
heading "8/8  Starting the server"

if [ "$TESTMODE" = "1" ]; then
    info "test mode ($FAT) - no server is touched."
    STARTED=1
fi
if [ "$TESTMODE" = "0" ]; then

# ⚠️ The MiSTer has no pkill - busybox lacks it. `pkill -f server.py` only
# gives "command not found", the old process lives on, the new one dies
# silently on "Address already in use", and the OLD one carries on serving the
# OLD code. Always kill by explicit PID.
PIDS="$(ps ax 2>/dev/null | grep '[s]erver\.py' | awk '{print $1}')"
if [ -n "$PIDS" ]; then
    info "stopping the old process (PID $(echo $PIDS | tr '\n' ' '))"
    kill $PIDS 2>/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10; do
        ps ax 2>/dev/null | grep -q '[s]erver\.py' || break
        sleep 1
    done
fi

# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF" && export MISTER_LANG REACHD_URL SMZ3_REACH_URL
setsid nohup python3 "$MG/server.py" > /tmp/mistergames.log 2>&1 < /dev/null &

# The server indexes the games folders before it starts listening, so a single
# attempt right after start gives a false alarm.
STARTED=0
for i in $(seq 1 30); do
    if curl -sf -m 3 -o /dev/null "http://127.0.0.1:8182/api/status" 2>/dev/null; then
        ok "the server answers (after ${i}s)"; STARTED=1; break
    fi
    sleep 1
done
if [ "$STARTED" = "0" ]; then
    err "the server does not answer after 30 s."
    info "Look in /tmp/mistergames.log for the reason."
    tail -5 /tmp/mistergames.log 2>/dev/null | sed 's/^/         /'
fi

fi   # TESTMODE = 0

# ==========================================================================
# Summary
# ==========================================================================
echo
echo "============================================================"
echo " Done"
echo "============================================================"
echo
echo "  Game browser:   http://$MY_IP:8182/"
echo "  Seed page:      http://$MY_IP:8182/seeds"
echo "  New seeds:      MiSTer menu -> Scripts -> ALTTPR_new_seed"
echo "                                         -> SMZ3_new_seed"
if [ -n "$HA_IP" ]; then
    echo "  Home Assistant: $HA_IP  (the logic on :8183)"
fi
echo
echo "  To have the pages in Home Assistant, add one card of type"
echo "  \"webpage\" per page with these addresses:"
echo
echo "      http://$MY_IP:8182/        (the game browser)"
echo "      http://$MY_IP:8182/seeds   (the seeds)"
echo
echo "  ⚠️ The browser switches core the moment you pick a game, and"
echo "  the MiSTer only flushes save memory to the SD card when the OSD"
echo "  menu is opened. Unsaved progress is therefore lost on a core"
echo "  switch. Habit: open and close the OSD after you save in the"
echo "  game - the save file then lands on the card, and the tracker"
echo "  sees it."
echo

press_key
