# Skinning Tracker — Renowned Beasts

A World of Warcraft addon that tracks daily Renowned Beast skinning across all of your Midnight profession skinner characters, in one window.

Five Renowned Beasts reset daily. This addon records which ones each of your characters has already skinned, so you can see at a glance who still has beasts left without logging into each one.

## Features

- **Automatic tracking.** Skinning a Renowned Beast records it. No need to tick anything off by hand. Works with hard-targeting and with soft-target interact keybinds.
- **All characters in one view.** Every skinner character you have logged into is listed with its own row.
- **Daily reset countdown**, read from the game client so it is correct in every region.
- **Majestic loot counters** for Majestic Claw, Hide and Fin, per session and lifetime, with an audio cue on a drop.
- **Manual Edit mode** for the rare case where detection gets it wrong — record a kill that was missed, or clear one that was recorded by mistake. Hand-entered marks show in green so you can tell them apart from detected ones.
- **Gold value**, session and lifetime, priced from your own Auctionator scans. Requires [Auctionator](https://www.curseforge.com/wow/addons/auctionator); without it the rest of the addon works exactly as before.
- **Optional ElvUI datatext** showing remaining beasts on any panel.

## Installation

### WowUp / CurseForge client

Add this repository as a custom addon using the GitHub URL:

```
https://github.com/brobersonjr/skinning-tracker
```

### Manual

1. Download `SkinningTracker-vX.Y.Z.zip` from the [latest release](https://github.com/brobersonjr/skinning-tracker/releases/latest).
2. Extract it into your AddOns folder, so the layout is:
   ```
   World of Warcraft\_retail_\Interface\AddOns\SkinningTracker\
   ```
   The folder must be named exactly `SkinningTracker`.
3. Restart the game, or `/reload` if you are already logged in.

## Commands

| Command | What it does |
|---|---|
| `/skt` | Open or close the tracker window |
| `/skt toggle` | Manually flag this character as a Midnight skinner, if auto-detection missed it |
| `/skt mark <beast>` | Record a beast as skinned today |
| `/skt unmark <beast>` | Clear a beast that was recorded by mistake |
| `/skt gold` | Print what your Majestic materials are worth, session and lifetime |
| `/skt reset` | Clear today's progress for this character |
| `/skt debug` | Print event details while skinning, for troubleshooting |

Beast names: `Gloomclaw`, `Silverscale`, `Lumenfin`, `Umbrafang`, `Netherscythe`.

## Gold value

If [Auctionator](https://www.curseforge.com/wow/addons/auctionator) is installed, the tracker prices your Majestic materials from whatever Auctionator last scanned on your realm, and shows a session and a lifetime total.

- **Scan the auction house** with Auctionator for prices to exist at all. Materials with no scanned price are marked `*` and named in the tooltip, so an incomplete total is never mistaken for a low one.
- **Prices are the lowest current buyout**, which is what Auctionator's API exposes. Treat the totals as "what this would fetch undercutting the cheapest listing", not as an appraisal.
- **Session value clears on logout or `/reload`**, like the session item counts. Lifetime value is your stored per-character totals priced at today's numbers, so it moves as the market moves.
- Totals update as soon as a scan finishes — no need to reopen the window.

## Notes

- Progress is stored per character and resets on the daily boundary along with the beasts themselves.
- Characters are detected as skinners automatically from the Midnight Skinning spell. `/skt toggle` overrides that if needed and the choice sticks across logins.
- English clients only for now. Loot detection uses the client's own message formats, but the addon has not been tested against other locales.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT — see [LICENSE](LICENSE). The license is included in the release ZIP as well.
