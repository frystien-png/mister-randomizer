"""Reachability logic for SMZ3, built on the randomizer's own code (TotalSMZ3).

The same idea as the ALTTP half in reachd.py: run the game's real logic
instead of hand-written rules. The reason is the same as it was then - the
hand-written rules were wrong, and the errors only showed up when two seeds
were compared.

  reach(items, rewards, medallions) -> {"reachable": [...], "locked": [...]}

`items` are ItemType names ("Morph", "ProgressiveSword"), `rewards` a dict of
region name -> RewardType name, `medallions` [Misery Mire, Turtle Rock].

⚠️ Do NOT put ~/ap/worlds/smz3 on sys.path. That folder has an Options.py of
   its own which shadows Archipelago's, and the import becomes circular with
   an error message pointing in entirely the wrong direction. Go via the
   package path.
"""
import os
import sys
import random
import time

# Se kommentaren i reachd.py - AP_PATH later HA-tillagget peka pa /opt/ap
# without the file having to look different there than here.
sys.path.insert(0, os.environ.get("AP_PATH") or os.path.expanduser("~/ap"))

import ModuleUpdate                                                  # noqa: E402
ModuleUpdate.update = lambda *a, **k: None
ModuleUpdate.update_ran = True

from worlds.smz3.TotalSMZ3.Config import Config, GameMode            # noqa: E402
from worlds.smz3.TotalSMZ3.Item import Item, ItemType, Progression   # noqa: E402
from worlds.smz3.TotalSMZ3.Region import IReward, RewardType         # noqa: E402
from worlds.smz3.TotalSMZ3.World import World                        # noqa: E402
from worlds.smz3.TotalSMZ3.WorldState import Medallion, WorldState   # noqa: E402

# Randomizerns egna platsnamn -> namnen MiSTerns /api/smz3 anvander.
# 97 of 100 are already identical; only these three differ in spelling.
LOC_ALIAS = {
    "Bombs": "Bomb",
    "Grappling Beam": "Grapple Beam",
    "Missile (Grappling Beam)": "Missile (Grapple Beam)",
}

# Priserna i seedens .txt-fil star per dungeon; logiken hanger dem pa
# the region. The Metroid bosses sit in the region the boss stands in.
PRIZE_REGIONS = {
    "Prize - Eastern Palace": "Eastern Palace",
    "Prize - Desert Palace": "Desert Palace",
    "Prize - Tower of Hera": "Tower of Hera",
    "Prize - Dark Palace": "Palace of Darkness",
    "Prize - Swamp Palace": "Swamp Palace",
    "Prize - Skull Woods": "Skull Woods",
    "Prize - Thieves' Town": "Thieves' Town",
    "Prize - Ice Palace": "Ice Palace",
    "Prize - Misery Mire": "Misery Mire",
    "Prize - Turtle Rock": "Turtle Rock",
    "Prize - Brinstar": "Brinstar Kraid",
    "Prize - Wrecked Ship": "Wrecked Ship",
    "Prize - Maridia": "Maridia Inner",
    "Prize - Norfair Lower": "Norfair Lower East",
}

REWARD_NAMES = {
    "Green Pendant": RewardType.PendantGreen,
    "Blue/Red Pendant": RewardType.PendantNonGreen,
    "Blue Crystal": RewardType.CrystalBlue,
    "Red Crystal": RewardType.CrystalRed,
    "Kraid Boss Token": RewardType.BossTokenKraid,
    "Phantoon Boss Token": RewardType.BossTokenPhantoon,
    "Draygon Boss Token": RewardType.BossTokenDraygon,
    "Ridley Boss Token": RewardType.BossTokenRidley,
}

# The randomizer's readable item names -> ItemType. Needed in order to read
# seedens .txt; sjalva API:et tar ItemType-namn direkt.
ITEM_NAMES = {
    "Progressive Sword": "ProgressiveSword",
    "Progressive Shield": "ProgressiveShield",
    "Progressive Mail": "ProgressiveTunic",
    "Progressive Glove": "ProgressiveGlove",
    "Bow": "Bow",
    "Silver Arrows": "SilverArrows",
    "Blue Boomerang": "BlueBoomerang",
    "Red Boomerang": "RedBoomerang",
    "Hookshot": "Hookshot",
    "Mushroom": "Mushroom",
    "Magic Powder": "Powder",
    "Fire Rod": "Firerod",
    "Ice Rod": "Icerod",
    "Bombos": "Bombos",
    "Ether": "Ether",
    "Quake": "Quake",
    "Lamp": "Lamp",
    "Hammer": "Hammer",
    "Shovel": "Shovel",
    "Flute": "Flute",
    "Bug Catching Net": "Bugnet",
    "Book of Mudora": "Book",
    "Bottle": "Bottle",
    "Cane of Somaria": "Somaria",
    "Cane of Byrna": "Byrna",
    "Magic Cape": "Cape",
    "Magic Mirror": "Mirror",
    "Pegasus Boots": "Boots",
    "Zora's Flippers": "Flippers",
    "Moon Pearl": "MoonPearl",
    "Half Magic": "HalfMagic",
    "Heart Piece": "HeartPiece",
    "Heart Container": "HeartContainer",
    # Metroid-halvan
    "Missile": "Missile",
    "Super Missile": "Super",
    "Power Bomb": "PowerBomb",
    "Grapple Beam": "Grapple",
    "Grappling Beam": "Grapple",
    "X-Ray Scope": "XRay",
    "Energy Tank": "ETank",
    "Reserve Tank": "ReserveTank",
    "Charge Beam": "Charge",
    "Ice Beam": "Ice",
    "Wave Beam": "Wave",
    "Spazer": "Spazer",
    "Plasma Beam": "Plasma",
    "Varia Suit": "Varia",
    "Gravity Suit": "Gravity",
    "Morphing Ball": "Morph",
    "Morph Ball Bombs": "Bombs",
    "Morph Bombs": "Bombs",
    "Bombs": "Bombs",
    "Spring Ball": "SpringBall",
    "Screw Attack": "ScrewAttack",
    "Hi-Jump Boots": "HiJump",
    "Space Jump": "SpaceJump",
    "Speed Booster": "SpeedBooster",
}

MEDALLION_NAMES = {m.name: m for m in Medallion}


class _NoAPLocation:
    """TotalSMZ3's key rules ask what is ON a location.

        `Location.ItemIs` goes via `APLocation`, a field Archipelago only sets
        once the world has been filled with items. We fill no world - we only ask
        about reachability - so the field is missing and the rules crash with
        AttributeError as soon as enough items make them evaluate at all. With
        item=None, ItemIs answers False, which is the rule's cautious branch: the
        key is assumed not to be there.
    """
    item = None

_worlds = {}


def _reward_key(rewards):
    return tuple(sorted((k, v) for k, v in (rewards or {}).items()))


# Zelda dungeons that carry a prize. Their boss flag can be read from SRAM,
# so for those we can say whether the reward is COLLECTED - not just collectable.
ZELDA_PRIS = ["Castle Tower", "Eastern Palace", "Desert Palace",
              "Tower of Hera", "Palace of Darkness", "Swamp Palace",
              "Skull Woods", "Thieves' Town", "Ice Palace", "Misery Mire",
              "Turtle Rock"]


def build_world(rewards=None, medallions=("Ether", "Quake"), klara=None):
    """An SMZ3 world with the seed's prizes and medallions substituted in.

        WorldState.Generate randomises prizes, medallions and drop tables. We
        overwrite prizes and medallions with the seed's real ones - they can be
        read from the .txt file next to the ROM. The drop table touches no logic.
    """
    cfg = Config()
    cfg.GameMode = GameMode.Normal
    w = World(cfg, "player", 1, "guid")
    w.Setup(WorldState.Generate(cfg, random.Random(0)))

    # Set the prizes per region name rather than via SetRewards, which hands
    # them out in region order. Names are self-checking.
    if rewards:
        by_name = {r.Name: r for r in w.Regions if isinstance(r, IReward)}
        for region_name, reward in rewards.items():
            region = by_name.get(region_name)
            if region is None:
                raise KeyError("okand beloningsregion: %r" % region_name)
            region.Reward = (reward if isinstance(reward, RewardType)
                             else REWARD_NAMES[reward])

    med = [MEDALLION_NAMES.get(str(m).capitalize(), Medallion.Ether)
           for m in (list(medallions) + ["Ether", "Quake"])[:2]]
    w.SetMedallions(med)
    # The lookup is built from the regions' prizes, so it has to be redone
    # after we swap them. Without that CanAcquireAll answers about the wrong world.
    w.SetRewardLookup()

    # ⚠️ TotalSMZ3 asks "CAN the dungeon be cleared", not "have you cleared
    # it". That makes the big bomb, for one - which requires both red
    # crystals - look purchasable as soon as the two dungeons are possible.
    # It was noticed immediately. When the boss flags are known we instead let
    # the reward count only once it has actually been collected, which is the
    # same meaning the ALTTP half already has.
    #
    # The Metroid areas' bosses cannot be read from the save file yet, so they
    # are left as they are - otherwise their boss tokens would lock for good.
    if klara is not None:
        klar = set(klara)
        for r in w.Regions:
            if isinstance(r, IReward) and r.Name in ZELDA_PRIS:
                r.CanComplete = (lambda taget: (lambda items: taget))(
                    r.Name in klar)

    stub = _NoAPLocation()
    for loc in w.Locations:
        loc.APLocation = stub
    return w


def _handout(w):
    """Items the player always has, whatever the save file says.

        Without keysanity, Archipelago does two things we have to imitate: SM's
        key cards are handed out from the start (push_precollected), and the
        dungeon keys are pre-filled inside their own dungeon. Small keys are also
        consumed when a door is opened, so the count in a save file says nothing
        about which doors already stand open - the same conclusion as in the
        ALTTP half, and for the same reason.
    """
    # ⚠️ BIG keys are NOT handed out. They are never consumed and can be read
    # exactly from SRAM, so anyone missing one should not get it for free. Hand
    # them out and a Big Chest looks openable without its key - found in
    # Eastern Palace, where the key sits behind a door that requires the lamp.
    # Exactly the same mistake the ALTTP half once had, for the same reason.
    ut = [i for i in Item.CreateDungeonPool(w)
          if not i.Type.name.startswith("BigKey")]
    if not w.Config.Keysanity:
        ut += list(Item.CreateKeycards(w))
    return ut


def get_world(rewards=None, medallions=("Ether", "Quake"), klara=None):
    key = (_reward_key(rewards), tuple(medallions),
           None if klara is None else tuple(sorted(klara)))
    if key not in _worlds:
        w = build_world(rewards, medallions, klara)
        _worlds[key] = {
            "w": w,
            "handout": _handout(w),
            "sm": {LOC_ALIAS.get(l.Name, l.Name) for l in w.Locations
                   if ".SuperMetroid." in type(l.Region).__module__},
        }
    return _worlds[key]


def to_items(names, extra=()):
    """ItemType-namn -> Progression. Okanda namn ignoreras tyst."""
    items = list(extra)
    for n in names or []:
        t = getattr(ItemType, n, None)
        if t is not None:
            items.append(Item(t))
    return Progression(items)


def reach(names, rewards=None, medallions=("Ether", "Quake"), keys=True,
          klara=None):
    """Which locations are reachable with this inventory."""
    t0 = time.time()
    entry = get_world(rewards, medallions, klara)
    items = to_items(names, entry["handout"] if keys else ())
    ok, no = [], []
    for loc in entry["w"].Locations:
        (ok if loc.Available(items) else no).append(
            LOC_ALIAS.get(loc.Name, loc.Name))
    return {"reachable": ok, "locked": no,
            "sm_reachable": [n for n in ok if n in entry["sm"]],
            "ms": int((time.time() - t0) * 1000)}


# The Metroid half's item types. Used to steer the minimisation towards
# the world the location actually sits in.
SM_TYPES = {
    "Missile", "Super", "PowerBomb", "Grapple", "XRay", "ETank",
    "ReserveTank", "Charge", "Ice", "Wave", "Spazer", "Plasma", "Varia",
    "Gravity", "Morph", "Bombs", "SpringBall", "ScrewAttack", "HiJump",
    "SpaceJump", "SpeedBooster",
}

# ItemType-namn -> lasbart namn. Forsta traffen i ITEM_NAMES vinner, sa
# "Bombs" becomes "Morph Ball Bombs" and not one of the synonyms.
TYPE_NAMES = {}
for _lasbart, _typ in ITEM_NAMES.items():
    TYPE_NAMES.setdefault(_typ, _lasbart)

# Big keys can appear in an answer ("you are missing the big key for Ice
# Palace"), so they need readable names. The abbreviations are SMZ3's own.
for _kort, _dungeon in [
        ("EP", "Eastern Palace"), ("DP", "Desert Palace"),
        ("TH", "Tower of Hera"), ("PD", "Palace of Darkness"),
        ("SP", "Swamp Palace"), ("SW", "Skull Woods"),
        ("TT", "Thieves' Town"), ("IP", "Ice Palace"),
        ("MM", "Misery Mire"), ("TR", "Turtle Rock"),
        ("GT", "Ganon's Tower")]:
    TYPE_NAMES["BigKey" + _kort] = "Stor nyckel (%s)" % _dungeon


def missing(name, names, rewards=None, medallions=("Ether", "Quake"),
            klara=None):
    """What is missing to reach a location?

        "single" = items that are enough on their own (OR between them).
        "combo"  = a set that together is enough.

        The method is minimisation, not construction - the same as the ALTTP
        half, and for the same reason: greedy construction towards "most
        reachable locations" does not steer towards the goal but towards
        whatever stirs up the most in the world.

        The universe is the randomizer's own progression pool. Maps, compasses
        and keys stay outside: they are handed out anyway and would only be
        noise.
    """
    entry = get_world(rewards, medallions, klara)
    w = entry["w"]
    bak = {v: k for k, v in LOC_ALIAS.items()}
    loc = next((l for l in w.Locations
                if l.Name == bak.get(name, name) or l.Name == name), None)
    if loc is None:
        return {"okand": True}

    har = [getattr(ItemType, n) for n in (names or [])
           if getattr(ItemType, n, None) is not None]

    def nabar(extra):
        return loc.Available(Progression(
            [Item(t) for t in list(har) + list(extra)] + entry["handout"]))

    if nabar([]):
        return {"nabar": True, "single": [], "combo": []}

    # ⚠️ Big keys have to be in the universe even though they are not HANDED
    # OUT. They sit in the dungeon pool, not the progression pool, so without
    # them every Big Chest became "impossible" instead of the answer saying
    # which key is missing. Small keys and cards are handed out and do not belong here.
    stora = [it.Type for it in Item.CreateDungeonPool(w)
             if it.Type.name.startswith("BigKey")]
    kvar = [it.Type for it in Item.CreateProgressionPool(w)] + stora
    for t in har:                       # never touch what is already held
        if t in kvar:
            kvar.remove(t)

    def las(typer):
        """Alternatives - a set, where duplicates mean nothing."""
        return sorted({TYPE_NAMES.get(t.name, t.name) for t in typer})

    def las_kombo(typer):
        """A set that is required TOGETHER - that is, a multiset.

                ⚠️ Must NOT be deduplicated. Progressive items count: two
                "Progressive Sword" is the Master Sword, two "Progressive Glove" is
                Titan's Mitts. Turn it into a set and the answer understates the
                requirement, and the list could not even be reached with what it
                itself stated.
        """
        antal = {}
        for t in typer:
            n = TYPE_NAMES.get(t.name, t.name)
            antal[n] = antal.get(n, 0) + 1
        return [n if k == 1 else "%s ×%d" % (n, k)
                for n, k in sorted(antal.items())]

    single = [t for t in set(kvar) if nabar([t])]
    if single:
        return {"nabar": False, "single": las(single), "combo": []}
    if not nabar(kvar):
        # With rewards collected, a location can be locked by a CRYSTAL or PENDANT
        # you have not taken yet, and then no items help. Test whether it would
        # have been reachable if the rewards counted as collectable - we then know
        # it is the dungeons standing in the way, not the equipment.
        if klara is not None:
            fritt = missing(name, names, rewards, medallions, klara=None)
            if not fritt.get("omojlig"):
                fritt["belong"] = True
                return fritt
        return {"nabar": False, "single": [], "combo": [], "omojlig": True}

    # ⚠️ The minimisation is ORDER-SENSITIVE, and that matters in SMZ3.
    # The games are cross-linked: a Zelda location can often be reached either
    # the Zelda way or through the Metroid portals. If the loop removes the
    # Zelda route first it locks onto the Metroid route, and the answer becomes
    # a local minimum where every item is indeed necessary GIVEN the others -
    # but the set as a whole is wrong.
    #
    # Measured 2026-08-10: Misery Mire was claimed to require Varia, Space Jump
    # and Power Bombs, when Zelda items alone are enough.
    #
    # The cure: try several orders and keep the smallest set. The first attempt
    # removes THE OTHER game's items first, which gives the answer in the same
    # world as the location sits in.
    sm_plats = ".SuperMetroid." in type(loc.Region).__module__

    def andra_spelet_forst(typer):
        a = [t for t in typer if (t.name in SM_TYPES) != sm_plats]
        b = [t for t in typer if (t.name in SM_TYPES) == sm_plats]
        return a + b

    def minimera(ordning, start=None):
        cur = list(kvar if start is None else start)
        for t in ordning:
            if t not in cur:
                continue
            prov = list(cur)
            prov.remove(t)
            if nabar(prov):
                cur = prov
        return cur

    ordningar = [andra_spelet_forst(kvar), list(kvar)]
    rnd = random.Random(0)          # fast fro: samma fraga, samma svar
    for _ in range(2):
        o = list(kvar)
        rnd.shuffle(o)
        ordningar.append(o)
    forsta = min((minimera(o) for o in ordningar), key=len)

    # ⚠️ Random orders do NOT find alternative routes - they converge on
    # mot samma minimala mangd. Uppmatt: tolv extra ordningar gav noll nya
    # solutions in five locations. The question you actually want answered is
    # directed: "does it work AT ALL without item X?" One minimisation per item
    # in the answer is then enough, and the answer is a route avoiding that item.
    kandidater = [forsta]
    for t in sorted(set(forsta), key=lambda x: x.name):
        utan = [x for x in kvar if x != t]
        if not nabar(utan):
            continue                    # t ar verkligen nodvandigt
        kandidater.append(minimera(andra_spelet_forst(utan), utan))

    # ⚠️ The exclusion can find a SHORTER route than the first one - Screw
    # Attack gav 6 foremal rakt fram men 4 nar Gravity Suit uteslots. Da
    # the short one should be the main answer, or the box shows a detour.
    sedda, unika = set(), []
    for m in kandidater:
        nyckel = tuple(sorted(t.name for t in m))
        if nyckel in sedda:
            continue                    # samma vag hittas en gang per utesluten pryl
        sedda.add(nyckel)
        unika.append(m)
    unika.sort(key=len)
    bast = unika[0]

    # Only routes that are equally short or one item longer - a route with four
    # extra items is no help. Two at most, or the box becomes a
    # uppslagsbok.
    andra_vagar = [m for m in unika[1:] if len(m) <= len(bast) + 1][:2]

    # ⚠️ The minimisation gives ONE valid set, not all of them. "Morphing Ball
    # + Space Jump" may in reality be "Morphing Ball + (Space Jump OR Morph
    # Bombs)" - and then you can go hunting for the wrong item. The same kind
    # of trap as the order sensitivity above, one level down.
    #
    # For each item in the combination: remove ONE occurrence and test what else
    # could have stood there. The candidates must not already be in the
    # combination - they would then not be an alternative but a second requirement.
    def kombo_med_alternativ(typer):
        antal = {}
        for t in typer:
            antal[t] = antal.get(t, 0) + 1
        kandidater = [u for u in set(kvar) if u not in antal]
        combo, alt = [], {}
        for t, k in sorted(antal.items(),
                           key=lambda p: TYPE_NAMES.get(p[0].name, p[0].name)):
            n = TYPE_NAMES.get(t.name, t.name)
            etikett = n if k == 1 else "%s ×%d" % (n, k)
            combo.append(etikett)
            rest = list(typer)
            rest.remove(t)              # EN forekomst - progressiva raknas
            byten = sorted({TYPE_NAMES.get(u.name, u.name)
                            for u in kandidater if nabar(rest + [u])})
            if byten:
                alt[etikett] = byten
        return combo, alt

    combo, alt = kombo_med_alternativ(bast)
    # ⚠️ Remove routes that are only best by a one-for-one swap - they are
    # already covered by "alternatives" and would just repeat in the box.
    basnamn = set(t.name for t in bast)
    vagar = []
    for m in andra_vagar:
        if len(basnamn ^ set(t.name for t in m)) > 2:
            vagar.append(kombo_med_alternativ(m)[0])
    return {"nabar": False, "single": [], "combo": combo, "alternativ": alt,
            "vagar": vagar}


def read_seed_file(path):
    """Reads the seed's .txt: the spheres and the last block's prizes/medallions.

        The file is a playthrough, not a full placement - only the items that
        drive progression. It is therefore good enough to verify the logic
        against, but not to derive the inventory from.
    """
    import json
    with open(path) as f:
        data = json.load(f)
    prizes, medals, spheres = {}, ["Ether", "Quake"], []
    for block in data:
        if not isinstance(block, dict) or not block:
            continue
        if any(k.startswith("Prize - ") for k in block):
            for k, v in block.items():
                if k in PRIZE_REGIONS:
                    prizes[PRIZE_REGIONS[k]] = v
                elif k == "Medallion Required - Misery Mire":
                    medals[0] = v
                elif k == "Medallion Required - Turtle Rock":
                    medals[1] = v
            continue
        spheres.append(block)
    return {"prizes": prizes, "medallions": medals, "spheres": spheres}
