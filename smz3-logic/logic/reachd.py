"""Reachability service for the ALTTP tracker.

Builds a seed-independent ALTTP world with Archipelago's logic once at start
and then answers the question "which locations can I reach with this
inventory".

It sits on a separate machine and not on the MiSTer for one reason:
Archipelago needs Python 3.11+, the MiSTer has 3.9.6. And not on the desktop
for another: that one is switched off while you are on your phone. This server
is on around the clock.

  POST /reach  {"items": {"boots": 1, "gloves": 2, ...}}
            -> {"reachable": [...], "locked": [...], "ms": 2}

The keys in "items" are LOGIC_ITEMS ids from the MiSTer's server.py.
"""
import json
import logging
import os
import sys
import time
import threading
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# AP_PATH set = run against an Archipelago checkout other than ~/ap. The HA
# add-on needs that (AP lives in /opt/ap there); without the variable the
# file behaves exactly as before, so the same file serves both places.
sys.path.insert(0, os.environ.get("AP_PATH") or os.path.expanduser("~/ap"))
logging.disable(logging.ERROR)

# Archipelago checks dependencies for ALL its worlds on import and asks
# interactively about pip-installing what is missing. As a service there is
# nobody to answer, so it hangs on input(). We only care about ALTTP and
# already have what is needed - disconnect the check.
import ModuleUpdate                                                  # noqa: E402
ModuleUpdate.update = lambda *a, **k: None
ModuleUpdate.update_ran = True

from BaseClasses import CollectionState, ItemClassification          # noqa: E402
from worlds.alttp.Dungeons import get_dungeon_item_pool              # noqa: E402
from worlds.alttp.InvertedRegions import mark_dark_world_regions     # noqa: E402
from worlds.alttp.ItemPool import difficulties                       # noqa: E402
from worlds.alttp.Items import item_factory                          # noqa: E402
from worlds.alttp.Options import GlitchesRequired                    # noqa: E402
from worlds.alttp.test.bases import LTTPTestBase                     # noqa: E402

from alttp_locmap import ap_names_for                                # noqa: E402

PORT = 8183

# MiSTerns LOGIC_ITEMS-id -> Archipelagos foremalsnamn. Alla 27 verifierade
# against item_table; AP spells "Titans Mitts" plural without an apostrophe
# and "Bug Catching Net", which is not what you would guess.
#
# Progressive items are handled by sending the specific level instead of
# counting "Progressive X" - both variants exist in item_table.
ITEM_MAP = {
    "boots": "Pegasus Boots",
    "flippers": "Flippers",
    "pearl": "Moon Pearl",
    "mirror": "Magic Mirror",
    "hammer": "Hammer",
    "hookshot": "Hookshot",
    "lamp": "Lamp",
    "firerod": "Fire Rod",
    "icerod": "Ice Rod",
    "somaria": "Cane of Somaria",
    "byrna": "Cane of Byrna",
    "cape": "Cape",
    "book": "Book of Mudora",
    "net": "Bug Catching Net",
    "flute": "Flute",
    "bow": "Bow",
    "boomerang": "Blue Boomerang",
    "powder": "Magic Powder",
    "bombos": "Bombos",
    "ether": "Ether",
    "quake": "Quake",
    "mushroom": "Mushroom",
    "shovel": "Shovel",
    # AP's rule for Sick Kid is state.has_group("Bottles"), and the group holds
    # both "Bottle" and the filled variants. The empty one therefore works as a
    # member. The MiSTer sends the COUNT, so to_ap_items() repeats the name -
    # several bottles are required in a few places.
    "bottle": "Bottle",
}
# Gloves and swords are level-based in SRAM: 0x354 and 0x359 respectively.
GLOVES = {1: "Power Glove", 2: "Titans Mitts"}
SWORDS = {1: "Fighter Sword", 2: "Master Sword", 3: "Tempered Sword",
          4: "Golden Sword"}


class _Build(LTTPTestBase):
    def runTest(self):
        pass


def build_world(medals=("Ether", "Quake")):
    """The same setup as worlds/alttp/test/vanilla/TestVanilla.py.

        That path is proven correct by 169 green tests, so we only deviate where
        the actual game differs: it is played with bombs from the start.
    """
    b = _Build()
    b.world_setup()
    mw = b.multiworld
    w = mw.worlds[1]
    w.options.glitches_required = GlitchesRequired.from_any("no_glitches")
    w.difficulty_requirements = difficulties["normal"]
    w.options.bombless_start.value = False
    w.options.shuffle_capacity_upgrades.value = 0
    w.er_seed = 0
    w.create_regions()
    w.create_items()
    mw.itempool.extend(get_dungeon_item_pool(mw))
    mark_dark_world_regions(mw, 1)
    # AFTER create_regions: it sets the medallions from the options and
    # skriver over allt man satt innan. Reglerna laser vardet nar de
    # evaluated, so having it right before set_rules is enough.
    w.required_medallions = list(medals)
    b.world.set_rules()
    return b, mw


MEDALS = ("Bombos", "Ether", "Quake")
_worlds = {}


def get_world(medals=("Ether", "Quake")):
    """One built world per medallion pair (Misery Mire, Turtle Rock).

        Nine possible combinations, 0.11 s to build - we cache them rather than
        rebuilding on every question. The location names are the same in every
        world, only the rules differ.
    """
    key = tuple(medals)
    if key not in _worlds:
        b, mw = build_world(key)
        pool = get_dungeon_item_pool(mw)
        _worlds[key] = {
            "b": b, "mw": mw,
            "by": {l.name: l for l in mw.get_locations(1)},
            "dung": [i for i in pool if not i.name.startswith("Big Key")],
            "bk": {i.name: i for i in pool if i.name.startswith("Big Key")},
        }
    return _worlds[key]


_W0 = get_world()
BUILD, MW = _W0["b"], _W0["mw"]
LOCS = [l for l in MW.get_locations(1)]
AP_NAMES = [l.name for l in LOCS]
BY_NAME = _W0["by"]

# The map markers live on the MiSTer - that is where they are added. A local
# copy here would go stale without anyone noticing. The file next to this one
# is only used when the MiSTer does not answer.
# ⚠️ No address as the default. run.sh sets MISTER_URL from the add-on's
# mister_ip option; without it the fallback file next to this one is used. A
# hardcoded address from one home network would ship out with the package and
# dessutom peka pa fel maskin hos alla andra.
MISTER_URL = os.environ.get("MISTER_URL", "")
LOCAL_ANNO = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "annotations.json")
ANNO_TTL = 600          # seconds before we ask the MiSTer again

MINE = {}
_anno_at = [0.0]
_anno_src = ["(inte laddad)"]
_cache = {}
_name_cache = {}


def _names_from_mister():
    with urllib.request.urlopen(MISTER_URL, timeout=5) as r:
        data = json.loads(r.read().decode())
    return [x["name"] for x in (data.get("saved") or []) if x.get("name")]


def _names_from_file():
    with open(LOCAL_ANNO) as f:
        return [k.split("|", 1)[1] for k in json.load(f)]


_anno_busy = threading.Lock()


def load_annotations(force=False):
    """Rebuilds map name -> AP locations. A silent no-op before the TTL expires.

        The update happens in the BACKGROUND when it is not forced. Otherwise a
        circle appears: the MiSTer asks us, we ask the MiSTer for markers, and the
        MiSTer sits waiting for our answer. Both time out and the map loses its
        opinion.
    """
    if not force and MINE and time.time() - _anno_at[0] < ANNO_TTL:
        return len(MINE)
    if not force and MINE:
        # Already have a map - update it without making anyone wait.
        if _anno_busy.acquire(blocking=False):
            def _bg():
                try:
                    load_annotations(force=True)
                finally:
                    _anno_busy.release()
            threading.Thread(target=_bg, daemon=True).start()
        return len(MINE)
    try:
        names, src = _names_from_mister(), "MiSTern"
    except Exception:                                          # noqa: BLE001
        try:
            names, src = _names_from_file(), "lokal fil (MiSTern svarade ej)"
        except Exception:                                      # noqa: BLE001
            return len(MINE)      # behall det vi redan har hellre an inget
    fresh = {}
    for n in names:
        if n not in fresh:
            fresh[n] = ap_names_for(n, AP_NAMES)
    if fresh != MINE:
        # The answers are cached per inventory and apply to the old map.
        _cache.clear()
        _name_cache.clear()
        MINE.clear()
        MINE.update(fresh)
    _anno_at[0] = time.time()
    _anno_src[0] = src
    return len(MINE)


def to_ap_items(items):
    """{"boots": 1, "gloves": 2} -> ["Pegasus Boots", "Titans Mitts"]"""
    out = []
    for key, val in items.items():
        if not val:
            continue
        if key == "gloves" or key == "mitt":
            continue          # hanteras samlat nedan
        if key in ("sword", "mastersword"):
            continue
        if key == "bottle":
            # The count matters: a few rules require more than one bottle.
            # Four at most, that is how many slots there are.
            out += ["Bottle"] * min(int(val), 4)
            continue
        name = ITEM_MAP.get(key)
        if name:
            out.append(name)
    g = max(int(items.get("gloves") or 0), 2 if items.get("mitt") else 0)
    if g:
        out.append(GLOVES[min(g, 2)])
    s = max(int(items.get("sword") or 0), 2 if items.get("mastersword") else 0)
    if s:
        out.append(SWORDS[min(s, 4)])
    return out


# Dungeon rewards. They are not in SRAM as items but in the player's own
# progress.json, where boss and reward are ticked off. Without them everything
# behind crystals is permanently unreachable: Ganons Tower needs seven, and
# via Turtle Rock.
PRIZES = ["Crystal %d" % i for i in range(1, 8)] + [
    "Green Pendant", "Red Pendant", "Blue Pendant",
    # Events, not items. Without "Beat Agahnim 1" the Lumberjack Tree, among
    # others, is permanently unreachable - the tree only splits once he is
    # beaten. Read from 0x3C5 in SRAM.
    "Beat Agahnim 1", "Beat Agahnim 2"]

# Upgrades that are not "have / have not" but levels. The Master Sword is
# enough for everything the logic requires; Golden is never needed.
UPGRADES = ["Power Glove", "Titans Mitts", "Fighter Sword", "Master Sword"]


def all_names():
    """Everything the logic can take into account, as AP item names."""
    return sorted(set(ITEM_MAP.values()) | set(UPGRADES) | set(PRIZES))


# Keys, big keys, maps and compasses. In an ordinary ALTTPR seed they sit
# INSIDE their own dungeon, so whoever gets in finds them on the way. Without
# them everything behind a locked door is permanently unreachable - that was
# why Mimic Cave said "impossible": it is reached through Turtle Rock.
_ALL_DUNGEON_ITEMS = get_dungeon_item_pool(MW)

# Sma nycklar FORBRUKAS nar en dorr oppnas, sa antalet i SRAM sager inget om
# which doors are already open - those we hand out. Big keys are never
# consumed and are read exactly from 0x366, so they are only handed out when held.
DUNGEON_ITEMS = [i for i in _ALL_DUNGEON_ITEMS
                 if not i.name.startswith("Big Key")]
BIG_KEYS = {i.name: i for i in _ALL_DUNGEON_ITEMS
            if i.name.startswith("Big Key")}


def _state_for(names, medals=("Ether", "Quake")):
    w = get_world(medals)
    state = CollectionState(w["mw"])
    for it in w["dung"]:
        it.classification = ItemClassification.progression
        state.collect(it, prevent_sweep=True)
    for n in names:
        it = w["bk"].get(n)
        if it is not None:
            it.classification = ItemClassification.progression
            state.collect(it, prevent_sweep=True)
    if names:
        for it in item_factory(sorted(names), w["b"].world):
            it.classification = ItemClassification.progression
            state.collect(it, prevent_sweep=True)
    state.sweep_for_advancements()
    state.update_reachable_regions(1)
    return state


def reach_names(names, medals=("Ether", "Quake")):
    """Reachable map dots for a given set of AP items.

        Its own cache: the minimisation in missing_for asks hundreds of questions
        per location, and most of them repeat between locations.
    """
    key = (tuple(medals), tuple(sorted(names)))
    if key in _name_cache:
        return _name_cache[key]
    state = _state_for(names, medals)
    by = get_world(medals)["by"]
    ok = set()
    for name, aps in MINE.items():
        if any(by[a].can_reach(state) for a in aps if a in by):
            ok.add(name)
    if len(_name_cache) < 4000:
        _name_cache[key] = ok
    return ok


def reachable(items, extra=(), medals=("Ether", "Quake")):
    """Reachable map dots. Shares the state build with reach_names, so that
        /reach, /missing and /reachlocs always agree.

        It used to build its OWN CollectionState without dungeon keys, while the
        other two went through _state_for, which hands them out. Mimic Cave is
        reached through Turtle Rock - the map said locked, /missing said
        reachable.
    """
    load_annotations()          # TTL-gatad; hamtar bara nar den ar gammal
    t0 = time.time()
    names = set(to_ap_items(items)) | {x for x in extra if x}
    ok = reach_names(names, medals)
    return {
        "reachable": sorted(ok),
        "locked": sorted(set(MINE) - ok),
        "ms": int((time.time() - t0) * 1000),
    }


def missing_for(items, name, extra=(), medals=("Ether", "Quake")):
    """What is missing to reach a location? Returns AP item names.

        "single" = items that are enough on their own (alternatives, OR between).
        "combo"  = a set that together is enough.

        The method is minimisation, not construction: start with everything and
        remove one item at a time as long as the location is still reachable.
        Building up greedily towards "most reachable locations overall" does not
        steer towards the goal - for Bombos Tablet it picked lamp and flippers
        when the answer is book and sword.
    """
    load_annotations()
    if name not in MINE:
        return {"okand": True}
    har = set(to_ap_items(items)) | {x for x in extra if x}
    if name in reach_names(har, medals):
        return {"nabar": True, "single": [], "combo": []}

    alla = set(all_names()) | har
    saknas = sorted(alla - har)

    single = [n for n in saknas if name in reach_names(har | {n}, medals)]
    if single:
        return {"nabar": False, "single": single, "combo": []}

    if name not in reach_names(alla, medals):
        return {"nabar": False, "single": [], "combo": [], "omojlig": True}

    cur = set(alla)
    for n in saknas:                    # never touch what is already held
        if name in reach_names(cur - {n}, medals):
            cur.discard(n)
    return {"nabar": False, "single": [], "combo": sorted(cur - har)}



class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"ok": True, "platser": len(MINE),
                             "ap_platser": len(LOCS), "cache": len(_cache),
                             "karta_fran": _anno_src[0],
                             "karta_alder_s": int(time.time() - _anno_at[0])})
        elif self.path == "/reload":
            # For deploy scripts: force fresh markers without a restart.
            n = load_annotations(force=True)
            self._send(200, {"ok": True, "platser": n,
                             "karta_fran": _anno_src[0]})
        else:
            self._send(404, {"error": "no such path"})

    @staticmethod
    def _medals(body):
        """[Misery Mire, Turtle Rock]. Okant faller tillbaka pa AP:s default."""
        m = body.get("medals") or []
        out = list(("Ether", "Quake"))
        for i in (0, 1):
            if i < len(m) and str(m[i]).capitalize() in MEDALS:
                out[i] = str(m[i]).capitalize()
        return tuple(out)

    def _reachlocs(self, body):
        """Reachability for explicitly named AP locations.

                The map dots go through /reach, but dungeon interiors are not among
                them - they are needed to colour a dungeon by how much of it is
                reachable.
        """
        items = body.get("items") or {}
        extra = [x for x in (body.get("extra") or [])
                 if x in PRIZES or x in BIG_KEYS]
        names = set(to_ap_items(items)) | set(extra)
        medals = self._medals(body)
        state = _state_for(names, medals)
        by = get_world(medals)["by"]
        out = {}
        for n in (body.get("locations") or []):
            loc = by.get(n)
            out[n] = bool(loc.can_reach(state)) if loc else None
        return {"reach": out}

    @staticmethod
    def _smz3(body):
        """SMZ3 reachability via the randomizer's own logic.

                Imported in here and not at the top on purpose: if the TotalSMZ3
                import breaks it must not be able to take down the ALTTP half, which
                is the one actually in service. The first call pays for the build
                (~1 s), the rest are answered from the cache.
        """
        import smz3_logic
        return smz3_logic.reach(body.get("items") or [],
                                body.get("rewards") or None,
                                tuple(body.get("medals") or
                                      ("Ether", "Quake")),
                                klara=body.get("klara"))

    @staticmethod
    def _smz3missing(body):
        import smz3_logic
        return smz3_logic.missing(body.get("location") or "",
                                  body.get("items") or [],
                                  body.get("rewards") or None,
                                  tuple(body.get("medals") or
                                        ("Ether", "Quake")),
                                  klara=body.get("klara"))

    def do_POST(self):
        if self.path == "/smz3missing":
            try:
                n = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(n) or b"{}")
                return self._send(200, self._smz3missing(body))
            except Exception as e:                             # noqa: BLE001
                return self._send(400, {"error": str(e)})
        if self.path == "/smz3reach":
            try:
                n = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(n) or b"{}")
                return self._send(200, self._smz3(body))
            except Exception as e:                             # noqa: BLE001
                return self._send(400, {"error": str(e)})
        if self.path == "/reachlocs":
            try:
                n = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(n) or b"{}")
                return self._send(200, self._reachlocs(body))
            except Exception as e:                             # noqa: BLE001
                return self._send(400, {"error": str(e)})
        if self.path not in ("/reach", "/missing"):
            return self._send(404, {"error": "no such path"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(n) or b"{}")
            items = body.get("items") or {}
            # "extra" is dungeon rewards from the player's progress.json - they
            # are not in SRAM and have to be sent along.
            extra = [x for x in (body.get("extra") or [])
                     if x in PRIZES or x in BIG_KEYS]
            medals = self._medals(body)
            if self.path == "/reach":
                return self._send(200, reachable(items, extra, medals))
            self._send(200, missing_for(items, body.get("location") or "",
                                        extra, medals))
        except Exception as e:                                  # noqa: BLE001
            self._send(400, {"error": str(e)})


if __name__ == "__main__":
    load_annotations(force=True)
    print("varld byggd: %d platser" % len(LOCS))
    print("kartprickar: %d (fran %s)" % (len(MINE), _anno_src[0]))
    # ⚠️ Without an address nothing BREAKS - the fallback file next to this one
    # is used - and that is exactly why the line is needed. A silent fallback
    # looks like a healthy service right up until somebody wonders why new markers
    # aldrig dyker upp.
    if not MISTER_URL:
        print("VARNING: MISTER_URL ar inte satt. Kartmarkeringarna lases ur"
              " reservfilen bredvid, inte fran MiSTern.")
        print("         I HA-tillagget: fyll i mister_ip. Utanfor det:"
              " satt MISTER_URL=http://<mister>:8182/api/locations")
    print("lyssnar pa :%d" % PORT)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
