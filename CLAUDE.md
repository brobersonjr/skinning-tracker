# SkinningTracker - Agent Notes

This file is read automatically by Claude Code at the start of every conversation.
Other AI agents should append their review notes here so Claude Code picks them up.

---

## Project Summary
WoW Midnight addon that tracks daily Renowned Beast skinning across profession skinner characters.
- Slash command: `/skt`
- GitHub: https://github.com/brobersonjr/skinning-tracker
- Users install via WowUp-CF using the GitHub link
- **Audience: English-only clients for now. No localization work needed.**

## Coding Conventions
- Lua only — no external dependencies beyond the WoW API and optional ElvUI
- Keep all color constants local to each file (C_GREEN, C_YELLOW, etc.)
- Use server time (`C_DateAndTime.GetServerTime()`) with a fallback to `time()`
- Widget reuse pattern: create once, show/hide on refresh — never create frames inside Refresh()
- Print all user-facing messages with the `|cff00ff96[SkinningTracker]|r` prefix

## Build/Development
- No build system — standard Lua addon
- Test in-game with `/reload` after changes
- Debug mode: `/skt debug`

## Reviewed Findings (2026-03-07)
A third-party agent flagged 6 issues. Assessment below — do not act on dismissed items.

| # | Finding | Decision | Reason |
|---|---------|----------|--------|
| 1 | Global namespace (`SkinningTracker` global) | **Dismiss** | Collision risk is negligible for this addon name |
| 2 | Hardcoded reset time (UTC 15) fails for EU servers | **Defer** | English/US-only audience for now; revisit if EU players adopt the addon |
| 3 | Multiple event frames | **Dismiss** | Standard WoW addon pattern, no real overhead |
| 4 | GUID parsing via `strsplit` | **Dismiss** | Format has been stable for years, works correctly |
| 5 | Hardcoded font `FRIZQT__.TTF` | **Dismiss** | This is the standard WoW font, always present |
| 6 | Loot localization | **Already fixed** | 1.3.3 uses `LOOT_ITEM_SELF` / `LOOT_ITEM_SELF_MULTIPLE` with proper escaping |

## Sound System Notes
`PlaySoundFile` with file paths does NOT work in Midnight — all audio is in CASC storage with no path access.
`PlaySound(soundKitId, channel)` is the correct API.
`SOUNDKIT` table exists but many constants are nil. Confirmed present:
- `SOUNDKIT.IG_BACKPACK_OPEN = 862`
- `SOUNDKIT.IG_MAINMENU_OPEN = 850`
- `SOUNDKIT.IG_QUEST_LIST_OPEN = 875`

Currently using 862 as positive (Majestic drop) and 850 as negative (no drop) — **placeholders only**.
Need to find better-sounding IDs. Test by looting a Majestic item in-game.

## Sound Logic (SkinningTracker.lua)
- `PlayChaChing()` — positive sound, called when a Majestic item is looted
- `PlayNoMajestic()` — negative sound, called 3s after auto-skinning if no Majestic item looted
- `AutoSkinBeast(beastId)` — called on confirmed skinning; marks beast, prints chat, starts 3s timer
- `majesticExpectedToken` — token system to cancel the negative sound timer when Majestic drops
- When Majestic loot detected: sets `majesticExpectedToken = nil` to cancel pending negative sound

## Known Issues / Open Questions
<!-- Agents: append findings below with a date and source label -->
- Sound placeholder IDs (862/850) need replacing with better reward/negative sounds once confirmed working in-game.

---

## Agent Review Notes
<!-- Example format:
### [YYYY-MM-DD] Agent Name
- Finding 1
- Finding 2
-->
