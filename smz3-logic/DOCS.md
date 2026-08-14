# SMZ3 and ALTTPR logic

This add-on answers one single question, but it is the hard one:

> With this inventory — which locations in the seed can I actually reach,
> and what am I missing to reach the rest?

The answer is computed with **Archipelago's own logic**, the same rule set
the randomizer itself uses. The tracker on the MiSTer then draws the map
from the answer: green is reachable, red is not.

Without the add-on the map still works — it shows where you have been —
but the dots have no colour. The logic is what gives them an opinion.

## Options

| Option | Meaning |
|---|---|
| `mister_ip` | The MiSTer's IP address, e.g. `192.168.1.50` |

The address is used to fetch the map markers from the MiSTer. Left empty,
the service falls back to a bundled copy: the map works, but markers you
added yourself will not show.

**Give the MiSTer a static address** in your router. If it changes IP the
add-on stops finding it, and that shows up as a map that does not update —
not as an error message.

## How you know it works

The add-on log should end with:

```
varld byggd: 268 platser
kartprickar: 216 (fran MiSTern)
lyssnar pa :8183
```

If it says `(fran lokal fil (MiSTern svarade ej))` the add-on cannot reach
the MiSTer — check `mister_ip`.

You can also ask the service directly from any machine on the network:

```
curl http://<home-assistant>:8183/health
```

## What is inside

- **Archipelago**, pinned to an exact commit. The logic is sensitive to
  changes in Archipelago, and a floating `main` could change the answers
  under your feet in the middle of a run.
- Only the `alttp`, `smz3`, `sm` and `generic` worlds. The other 76 are
  stripped: the image gets smaller and the import twice as fast. The
  answers are verified *byte for byte* identical to an untrimmed copy.
- Python 3.12. Archipelago refuses to start outside the 3.11–3.13 range.

## Response times

A call takes on the order of **30–140 ms** on an x86 machine. On a
Raspberry Pi 4 an estimated 0.4–0.6 s, on a Pi 5 0.2–0.3 s — *estimated,
not measured on real Pi hardware.*

That only applies when you tap a dot. The rest of the map is instant.

Memory use is around 200 MB with both worlds loaded, so 2 GB of RAM is
plenty alongside Home Assistant.

## Pitfalls

**The save file is only written when you open the OSD menu.** The MiSTer
flushes SRAM to the SD card at that moment — not continuously. The tracker
therefore cannot know anything about what you have done since you last
opened the menu. Habit worth forming: open and close the OSD after you
save.

**The port must be reachable from the MiSTer.** The add-on publishes 8183
on the Home Assistant server's own IP. If you change the port mapping, the
MiSTer's `randomizer.conf` has to change with it.

## Language

This add-on has no user interface of its own; it answers over HTTP. The
pages you actually read are served by the MiSTer, and their language is
set there — `MISTER_LANG` in `.mistergames/randomizer.conf`. English is the default.
See the repository README for the list of languages and how to add your
own.
