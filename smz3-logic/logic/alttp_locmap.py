"""Maps the tracker names in annotations.json to Archipelago's location names.

Two kinds of mapping:

  ALIAS    one of our locations = one AP location, but spelled differently.
  DUNGEON  one of our map dots = the whole dungeon, so many AP locations.
           A dungeon dot counts as reachable as soon as ANY location in it
           can be reached - "can I get in and fetch something".

A few AP locations are deliberately left unmapped: Agahnim 1/2, Ganon, Frog,
Floodgate, Missing Smith and Flute Activation Spot are events in the logic,
not chests. Capacity Upgrade is the bottle shop.

The remaining 107 already match exactly on the name part after "|".
"""

ALIAS = {
    "Bumper Cave":            "Bumper Cave Ledge",
    "Graveyard Ledge":        "Graveyard Cave",
    "Hammer Pegs":            "Peg Cave",
    "Pegasus Rocks":          "Bonk Rock Cave",
    "Hype Cave - NPC":        "Hype Cave - Generous Guy",
    "Mini Moldorm Cave - NPC": "Mini Moldorm Cave - Generous Guy",
}

# Our dungeon names -> AP's prefixes. Note the apostrophe in Thieves' Town
# and the lowercase "of" in "Tower of Hera"; both differ from our names.
DUNGEON = {
    "Castle Tower":   "Castle Tower - ",
    "Dark Palace":    "Palace of Darkness - ",
    "Desert Palace":  "Desert Palace - ",
    "Eastern Palace": "Eastern Palace - ",
    "Ganons Tower":   "Ganons Tower - ",
    # The sewer chests are called "Sewers - ..." without the castle name,
    # but sit under Hyrule Castle and belong to the same map dot.
    "Hyrule Castle":  ("Hyrule Castle - ", "Sewers - "),
    "Ice Palace":     "Ice Palace - ",
    "Misery Mire":    "Misery Mire - ",
    "Skull Woods":    "Skull Woods - ",
    "Swamp Palace":   "Swamp Palace - ",
    "Thieves Town":   "Thieves' Town - ",
    "Tower Of Hera":  "Tower of Hera - ",
    "Turtle Rock":    "Turtle Rock - ",
}


def ap_names_for(mine, all_ap):
    """Our location name -> list of AP names. Empty list = no mapping."""
    if mine in DUNGEON:
        pre = DUNGEON[mine]
        if isinstance(pre, str):
            pre = (pre,)
        return [n for n in all_ap if n.startswith(pre)]
    target = ALIAS.get(mine, mine)
    return [target] if target in all_ap else []
