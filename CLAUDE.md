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
`SOUNDKIT` table may be sparse/nil in Midnight for some constants.
Use direct numeric sound IDs when needed.

Current confirmed working Majestic loot alert:
- `891` (sell/coin cue), played via `PlaySound(891, "Master")`

## Sound Logic (SkinningTracker.lua)
- `PlayChaChing()` — positive-only sound (`891`), called when a Majestic item is looted
- `AutoSkinBeast(beastId)` — called on confirmed skinning; marks beast and prints chat only
- No negative/no-drop sound logic
- Slash testing helpers:
  - `/skt testsound` plays configured Majestic sound ID
  - `/skt testsound <soundId>` tests any candidate ID in-game

## Known Issues / Open Questions
<!-- Agents: append findings below with a date and source label -->
- No known open sound issues after confirming ID `891` in-game.

---

## Agent Review Notes
<!-- Example format:
### [YYYY-MM-DD] Agent Name
- Finding 1
- Finding 2
-->

### [2026-03-08] GPT-5 Codex
- Reviewed `SkinningTracker.lua` sound flow and identified overlap risk from shared no-drop timer token.
- Simplified to positive-only Majestic loot sound per user requirement.
- Added `/skt testsound` and `/skt testsound <soundId>` to validate audio quickly in-game.
- Confirmed user-selected alert sound ID `891`; removed fallback chain and negative-sound logic.

### [2026-03-10] Claude Sonnet 4.6
- Fixed ElvUI data text tooltip not showing on hover (`SkinningTrackerElvUI.lua`).
- Root cause: `DT.tooltip:ClearLines()` was called without a nil check; if `DT.tooltip` is absent in this ElvUI build, it silently errors and nothing shows.
- Fix: use `DT.tooltip` (with `SmartAnchorTo`) when available; fall back to `GameTooltip` (with `SetOwner`) otherwise.
- Removed `SetMinimumWidth` call — ElvUI-only extension, would error on the GameTooltip fallback path.
