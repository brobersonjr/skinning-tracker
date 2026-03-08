# SkinningTracker - Agent Notes

This file is read automatically by Claude Code at the start of every conversation.
Other AI agents should append their review notes here so Claude Code picks them up.

---

## Project Summary
WoW Midnight addon that tracks daily Renowned Beast skinning across profession skinner characters.
- Slash command: `/skt`
- GitHub: https://github.com/brobersonjr/skinning-tracker
- Users install via WowUp-CF using the GitHub link

## Coding Conventions
- Lua only — no external dependencies beyond the WoW API and optional ElvUI
- Keep all color constants local to each file (C_GREEN, C_YELLOW, etc.)
- Use server time (`C_DateAndTime.GetServerTime()`) with a fallback to `time()`
- Widget reuse pattern: create once, show/hide on refresh — never create frames inside Refresh()
- Print all user-facing messages with the `|cff00ff96[SkinningTracker]|r` prefix

## Known Issues / Open Questions
<!-- Agents: append findings below with a date and source label -->

---

## Agent Review Notes
<!-- Example format:
### [2026-03-07] Codex Review
- Finding 1
- Finding 2
-->
