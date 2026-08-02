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
- Lua only — no external dependencies beyond the WoW API and optional ElvUI/Auctionator
- Keep all color constants local to each file (C_GREEN, C_YELLOW, etc.)
- Use server time (`C_DateAndTime.GetServerTime()`) with a fallback to `time()`
- Widget reuse pattern: create once, show/hide on refresh — never create frames inside Refresh()
- Print all user-facing messages with the `|cff00ff96[SkinningTracker]|r` prefix

## Build/Development
- No build system — standard Lua addon
- Test in-game with `/reload` after changes
- Debug mode: `/skt debug`
- Automated tests: `npm install --no-save fengari && node tests/run.js`.
  Pure-logic only — frames, timers and tooltips are stubbed to no-ops, so a
  green run never substitutes for an in-game `/reload`.

## Reviewed Findings (2026-03-07)
A third-party agent flagged 6 issues. Assessment below — do not act on dismissed items.

| # | Finding | Decision | Reason |
|---|---------|----------|--------|
| 1 | Global namespace (`SkinningTracker` global) | **Dismiss** | Collision risk is negligible for this addon name |
| 2 | Hardcoded reset time (UTC 15) fails for EU servers | **Fixed in 1.4.5** | Now reads `C_DateAndTime.GetSecondsUntilDailyReset()`; the fixed 15:00 UTC math survives only as a fallback. No longer region-specific |
| 3 | Multiple event frames | **Dismiss** | Standard WoW addon pattern, no real overhead |
| 4 | GUID parsing via `strsplit` | **Dismiss** | Format has been stable for years, works correctly |
| 5 | Hardcoded font `FRIZQT__.TTF` | **Dismiss** | This is the standard WoW font, always present |
| 6 | Loot localization | **Already fixed** | 1.3.3 uses `LOOT_ITEM_SELF` / `LOOT_ITEM_SELF_MULTIPLE` with proper escaping |

## In-Game Verification Status (as of 2026-07-29, owner-confirmed)
Earlier entries below were written before anything had been run in the client. Current state:

| Behaviour | Status |
|-----------|--------|
| Addon loads, no Lua errors | ✅ confirmed |
| Auto-track on skinning a Renowned Beast | ✅ confirmed |
| Skinner auto-detection / character list populated | ✅ confirmed |
| SavedVariables survive `PLAYER_LOGIN`-only init (1.4.5) | ✅ confirmed — 7 alts intact |
| Window position persists across sessions (1.4.5) | ✅ confirmed |
| Escape closes the window (1.4.5) | ✅ confirmed |
| Reset countdown | ✅ plausible — showed 12h02m against a 15:00 UTC boundary. Note US realms cannot distinguish the API path from the old fixed-hour fallback, since both agree |
| Majestic loot counter increments (1.4.4) | ⏳ **unverified** — needs a drop |
| ElvUI datatext (all of it) | ⏳ unverified — owner does not use ElvUI, guildie to test |
| Datatext refresh across daily reset (1.4.3) | ⏳ unverified — needs to be logged in at reset |
| Soft-target skinning (1.4.6) | ⏳ unverified |
| Checkboxes locked while Manual Edit is off (1.4.8) | ✅ confirmed — owner reports the check does not respond until the button is clicked. This is the `RegisterForClicks()` assumption the harness cannot test; the `SetDisabledCheckedTexture` fallback is not needed |
| Manual Edit button unlocks and marks (1.4.8) | ✅ confirmed |
| Green tint on a manual mark persists across `/reload` (1.4.8) | ✅ confirmed |
| Auto-detection drops the tint on a hand-marked beast (1.4.8) | ✅ confirmed — hand-marked Gloomclaw then skinned it; check went green → yellow |
| Manual Edit re-locks when the window is closed (1.4.8) | ✅ confirmed |
| Addon loads with `SkinningTrackerPrices.lua`, no Lua errors (1.5.0) | ✅ confirmed |
| Auctionator price lookup returns real prices (1.5.0) | ✅ confirmed — Claw 180g, Hide 2498g99s, Fin 910g35s |
| Scan age reported per material (1.5.0) | ✅ confirmed — "scanned 0d ago" and "1d ago" both seen |
| Session value increments as loot arrives (1.5.0) | ✅ confirmed — 0 → 540g → 5,537g across three skins |
| Valuation arithmetic (1.5.0) | ✅ confirmed to the copper — 3×180 + 2×2498.99 = 5537g98s on screen |
| Money formatting (1.5.0) | ✅ confirmed — `GetMoneyString` renders coin icons; short form truncates and separates thousands (`16,295g`) |
| `/skt gold` output (1.5.0) | ✅ confirmed |
| Session value with Auctionator absent — says so, no errors (1.5.0) | ✅ confirmed — disabled in game, `/skt` showed "Auctionator not found", re-enabled cleanly |
| Session value clears on `/reload` (1.5.0) | ✅ confirmed — session counts and value both back to zero |
| Lifetime column and figure gone; header back to `(session / total)` (1.5.0) | ✅ confirmed |
| Refreshed scan prices are picked up (1.5.0) | ✅ confirmed — Majestic Claw valued at 180g in one session and 191g in a later one |
| Total refreshes the instant an AH scan completes (1.5.0) | ⏳ unverified — **low risk**, see below |

The scan-completion callback (`RegisterForDBUpdate`) is a latency optimisation,
not a correctness requirement. The 30-second ticker, opening the window, and
every Majestic loot all refresh the readout independently, so the worst case if
the callback never fires is a number up to 30 seconds behind — never a wrong
one. Shipped in 1.5.0 on that basis. To check it cheaply: Auctionator is
registered for `IncrementalScan.PricesProcessed` as well as
`FullScan.ScanComplete`, and the incremental event fires from ordinary auction
house browsing, so a search for one Majestic material is enough — no full scan
needed.

The pricing-engine rows were confirmed against the build that still had the
lifetime column; that code is byte-identical in the shipped build. The rows
above were confirmed against the shipped build itself.

Note when checking the "Auctionator absent" path from disk: `AddOns.txt` records
the enable state at the time it was last written, so toggling an addon off,
testing, and toggling it back on leaves the file reading `enabled`. It cannot be
used after the fact to tell a passing negative test from a load-order bug.

Owner plays on Proudmoore (US). Reset boundary is 15:00 UTC.

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

### [2026-08-02] Claude Opus 5 — Session gold via Auctionator (1.5.0)

Values this session's Majestic materials from Auctionator's scanned prices. New
file `SkinningTrackerPrices.lua` holds every Auctionator touchpoint, the way
`SkinningTrackerElvUI.lua` holds every ElvUI one.

**A lifetime gold figure was built and then deliberately removed. Do not add it
back.** It was nearly free — the per-character `items` counts are already in
SavedVariables — which is exactly the trap. Those counts **only ever
increment**: nothing decrements them when materials are sold, mailed, vendored
or crafted with. So `stored count × today's price` is neither the gold the
player earned nor the worth of what is in their bags, and it drifts with the
market for materials sold months ago. A number that means nothing precise is
worse than no number, and no wording fixes it. Reporting real earnings needs
prices banked at loot time, with its own state and its own decision about items
looted while unpriced — a separate feature, not a column. A test asserts
`ST.GetLifetimeValue` does not exist and that stored counts never leak into the
session figure.

**API facts, read from Auctionator's own source (v333), not from memory:**
- `Auctionator.API.v1.GetAuctionPriceByItemID(callerID, itemID)` returns
  `db[key].m` — the **minimum buyout** from the last scan. Not a mean, not a
  market value. The v1 API exposes no average; `GetMeanPrice` is internal. Do
  not describe these totals as an appraisal.
- `GetAuctionAgeByItemID` returns days since last seen, and **nil past 21 days
  or if never seen**. So "price present, age nil" means *very stale*, not fresh.
  The UI says "last scan over 21 days ago" for that case rather than hiding it.
- **Every v1 entry point raises via `error()`** — `InternalVerifyID` on a bad
  caller ID, and the price/age calls again on a wrong argument type. Our callers
  sit on the 30s UI ticker, so an uncaught raise would spam chat forever.
  **`CallAuctionator` wraps every call in `pcall`. Do not remove it** — a
  mutation test asserts a throwing API does not escape.
- `RegisterForDBUpdate` registers a permanent listener with **no unregister**,
  so it runs exactly once, at PLAYER_LOGIN deferred one frame (same pattern as
  `InitElvUI`).

**Design decisions to preserve:**
- **Value is computed at display time, never banked at loot time.** A player who
  skins for an hour and only then scans gets the whole session priced
  retroactively; a loot-time snapshot would have recorded zeroes that could
  never be repaired. The cost — the number moves when prices move — is the
  honest reading of "what this haul is worth". **Do not "optimise" this into a
  running total accumulated in the loot handler.**
- **Nothing is written to SavedVariables.** Session value derives from
  `ST.sessionItems`, already cleared at PLAYER_LOGIN, so "clears on logout or
  /reload" needs no new state and no new schema field. A test asserts no
  `sessionValue` key appears on the character row.
- **`unpricedCount` is load-bearing, not cosmetic.** Without it a missing scan
  silently understates the total and the player cannot tell a cheap session from
  an unpriced one. It drives the `*` marker everywhere. Only items with a
  **nonzero count** can be unpriced — a material that never dropped is not a gap
  in the data, and a mutation dropping that guard fails four tests.
- **A price of `0` is rejected as "no price", not treated as free.**
- **Money formatting uses `%.0f` for the gold component, `%d` for silver and
  copper.** Gold is the only unbounded part; a capped character holds ~10^11
  copper, which is exact as a double but has no guaranteed integer
  representation. `tostring` on a whole-number float also renders "1234567.0" in
  some builds, which the separator loop would turn into "1,234,567.0".
- `GetMoneyString` is preferred but pcall-guarded with an arithmetic fallback,
  which is also what makes the formatter testable outside the client.
- The loot section keeps its original 145px item columns. An earlier draft
  narrowed them to 118 to fit a value column; that column is gone, so the
  narrowing was reverted rather than left as unexplained dead layout.

**Harness note for future passes:** fengari's integers wrap at **32 bits**, so
`1234567 * 10000` overflows inside the VM. WoW's Lua 5.1 has no integer subtype
at all — every number is a double — so a float literal is the *faithful* stand-in
for what the client passes, not a workaround. The large-money test is written
that way deliberately.

**Verification:** all four source files and all three test files parse clean as
Lua 5.1. 66 pricing tests pass alongside the 41 Manual Edit ones (107 total),
covering Auctionator absent, present-but-no-database, a throwing API, full and
partial pricing, zero prices, empty input, scan-age selection, untracked items,
the real `CHAT_MSG_LOOT` path feeding the session figure, the AH-purchase
rejection still holding, session clearing at login while stored counts survive,
stored counts never leaking into the value, the scan callback, money formatting
boundaries, and `/skt gold`. Mutation-checked: removing the `pcall`, dropping
the `qty > 0` guard, and accepting a zero price each fail named tests. Frames,
tooltips and the bottom-bar label are stubbed no-ops and still need the client.

### [2026-07-31] Claude Opus 5 — Manual Edit mode (1.4.8)
1.4.7 made the checkmarks read-only. That removed the only recourse for a detection error in either direction: a miss could not be recorded, and a false positive could only be cleared with `/skt reset`, which wipes all five beasts. Since 1.4.4–1.4.6 were each detection-correctness fixes, treating detection as complete was premature. 1.4.8 restores a repair path without giving up the read-only default.

- **`manualBeasts[beastId]` stores a timestamp, not a boolean.** Same shape as `beasts` on purpose, so "marked today" is the identical `ts >= lastReset` test. A flag from a previous day goes inert with no cleanup pass and no special handling at the reset boundary. **Do not "simplify" this to a boolean** — that would need an explicit sweep at every rollover.
- **`ST:MarkSkinned` clears the manual flag.** Auto-detection outranks a hand-entered mark, so the green tint keeps meaning "the addon never detected this" rather than "you once clicked this". That is the signal worth having: a beast that stays green day after day is a real detection gap.
- **`WasManuallyMarked` also requires the beast row to be current.** A fresh flag beside a stale `beasts` entry must not read as marked. It takes an optional `charData` because the UI calls it per row, and other characters' rows may predate `manualBeasts` entirely — the nil path is covered by a test.
- **Checkboxes stay `SetEnabled(true)` in both states; `RegisterForClicks` is the gate.** A `CheckButton` flips its own checked state on click *before* `OnClick` runs, so clearing the script alone does not lock it. Keeping the button enabled is also what stops the greyed `UI-CheckBox-Check-Disabled` texture from being used, which is what makes tinting possible.
- **The check tint is set on every refresh, in both branches.** These checkbox frames are pooled and reused across rows; setting the colour only on the manual branch would let one row's tint bleed onto another character.
- **The manual tint renders GREEN, not the blue its constant suggests.** `SetVertexColor` multiplies against the texture, and `UI-CheckBox-Check` is gold (~1, 0.82, 0) with essentially no blue channel, so `(0.45, 0.7, 1)` comes out olive-green. **No vertex colour can make this check blue.** A true hue would need `SetDesaturated(true)` first, which is deliberately not done — green against the normal yellow-gold is already clearly distinguishable and is the combination confirmed in-game. Tooltip text is *not* multiplied by a texture, so its colours are set to match how the check actually renders rather than reusing the vertex constants.
- **This is not the skinner-status button declined in the 1.4.6 pass.** That one would have written `manualOverride` and pinned the character against auto-detection. Manual Edit never touches `manualOverride` and never changes detection.
- Manual Edit is session-only and re-locks on `OnHide`, which covers the X button, Escape and `/skt` alike. It is a repair mode, not a preference.

**Verification:** all three files parse clean as Lua 5.1. 41/41 in a real Lua VM covering the mark/unmark round trip, the auto-promotion rule, the reset boundary, the stale-flag guard, legacy rows without `manualBeasts`, `/skt reset`, per-character isolation, and slash parity including double-mark and `unmark`-not-parsed-as-`mark`. Mutation-checked: breaking auto-promotion, the staleness guard, or the reset each fail a named test. **The harness is committed this time** (`tests/`), closing the gap noted in AGENTS.md that earlier harnesses could not be re-run. Frames, tooltips and the `RegisterForClicks` lock are stubbed to no-ops and still need the client.

### [2026-03-08] GPT-5 Codex
- Reviewed `SkinningTracker.lua` sound flow and identified overlap risk from shared no-drop timer token.
- Simplified to positive-only Majestic loot sound per user requirement.
- Added `/skt testsound` and `/skt testsound <soundId>` to validate audio quickly in-game.
- Confirmed user-selected alert sound ID `891`; removed fallback chain and negative-sound logic.

### [2026-03-14] Claude Sonnet 4.6
- Fixed "secret string" taint error (`attempt to perform string conversion on a secret string value`) when skinning in delves.
- Root cause: `UnitGUID("target")` returns a protected secret string in delves; passing it to `strsplit` is blocked by WoW's security model.
- Fix: wrapped `strsplit` call in `pcall` inside `GetNPCIDFromGUID` and the debug block. Both return `nil` on failure, allowing the name-based fallback to proceed silently.
- Released as 1.4.0.

### [2026-03-14] GPT-5 Codex
- Fixed a second secret-string taint path in `SkinningTracker.lua` after the GUID guard landed.
- Root cause: `UnitName("target")` can also be a protected secret string in delves; calling `name:lower()` triggered `attempt to index local 'name' (a secret string value tainted by 'SkinningTracker')`.
- Fix: added taint-safe helpers for lowercasing and debug formatting. `GetTargetBeastId()` now lowercases target names via `pcall` and skips the fallback when the name is protected; debug logging now formats protected `guid`/`name` values safely.
- Impact: delve skinning no longer errors on either the GUID parse path or the target-name fallback path. Detection still prefers NPC ID and only uses name fallback when WoW returns a normal string.

### [2026-03-10] Claude Sonnet 4.6
- Fixed ElvUI data text tooltip not showing on hover (`SkinningTrackerElvUI.lua`).
- Root cause: `DT.tooltip:ClearLines()` was called without a nil check; if `DT.tooltip` is absent in this ElvUI build, it silently errors and nothing shows.
- Fix: use `DT.tooltip` (with `SmartAnchorTo`) when available; fall back to `GameTooltip` (with `SetOwner`) otherwise.
- Removed `SetMinimumWidth` call — ElvUI-only extension, would error on the GameTooltip fallback path.

### [2026-07-29] Claude Opus 5 (fourth pass, 1.4.6) — external review triage

Triaged a Gemini review of the repo. Accepted five items, **rejected one**, skipped one. Detail on the rejection matters most:

#### ❌ REJECTED: "Add LOOT_ITEM_PUSHED_SELF so satchel/container loot is counted"
**Do not implement this.** Majestic items can be bought on the auction house, and AH commodity purchases are delivered with a "You receive item:" message — which is exactly `LOOT_ITEM_PUSHED_SELF`. Widening the gate would start counting **bought** mats as skinning yield, which defeats the purpose of the counter. The same gate also keeps out mail, crafting and quest rewards. The handler accepting only "You receive loot:" is deliberate and is now commented as such in `SkinningTracker.lua`. Test coverage asserts pushed-item messages, including stacked AH purchases, stay rejected.

#### Accepted
- **Soft-target detection.** `GetTargetBeastId()` now checks `target` then `softinteract`. All NPC-ID checks run across both units before any name fallback, so a name match on one unit can never beat an ID match on the other. Added `SafeUnitGUID`/`SafeUnitName` pcall wrappers, matching the file's existing delve-taint defensiveness — `softinteract` is also not guaranteed valid on every client.
- **`IsSpellKnown` hardening.** Wrapped in `IsSkinningKnown()`. **`IsSpellKnown` stays first on purpose** — it is the path verified in-game. The review suggested putting `C_Spell.IsSpellKnown`/`IsPlayerSpell` ahead of it; that would swap a confirmed check for an unverified one, and they are not exact synonyms for profession spells. Written as explicit branches, not a candidate table: a nil first entry would leave a hole and `ipairs` would stop before reaching any fallback.
- **Debug visibility for rejected loot.** The gate returned before the debug print, so `/skt debug` was silent about messages it ignored — which made "no drop" and "message not recognised" indistinguishable, the exact question being investigated. Single rejection point now logs.
- **ElvUI multi-panel.** `dtFrame` single reference replaced with `dtFrames`, mapping each panel to **the exact string we last wrote there**. `RefreshDataText` iterates and updates only panels that still show that string, dropping any that do not.

  **Do not "simplify" this back to a plain set.** ElvUI reuses panel frames: assign a slot to a different datatext and the same frame object goes to that datatext. Holding the reference forever would let the 30s ticker overwrite whatever now owns the slot — caught in PR #5 review. The stored-string comparison is what lets us release a panel without reaching into ElvUI internals (which vary by build) to detect reassignment. Clearing keys mid-`pairs` is well-defined in Lua; only adding new ones would not be, and `UpdateText` only rewrites keys already present.
- **`ST:GetCharKey()`** exposed; the two inline rebuilds in the UI now use it.

#### Skipped
- Migrating `.items` for all characters in `InitDB()`. The review conceded it is harmless (the UI guards with `charData.items and ...`), and `manualOverride`/`autoDetected` are lazily populated by the same design. Touching every character's saved data for no behavioural gain is not worth it.
- The bottom-bar toggle button. Owner does not want it, so the stale comment and the unused `MakeButton` helper were removed instead. Note a UI toggle would write `manualOverride`, permanently pinning that character against auto-detection — not obviously what a button-clicker would expect.

**Verification:** 9/9 new tests on `IsSkinningKnown` (including the `ipairs`-hole trap and a throwing primary), 9/9 loot-gate tests re-run with added AH-purchase cases, 13/13 on the ElvUI datatext including the panel-reassignment case, 26/26 reset tests as regression. The ElvUI prefix is load-time clean too, so the datatext logic runs in the VM against a fake panel. Soft-target still needs the client.

### [2026-07-29] Claude Opus 5 (third pass, 1.4.5)
Cleared the last three findings from the review. **The review backlog is now empty.**
- **Daily reset now comes from the client.** `C_DateAndTime.GetSecondsUntilDailyReset()` gives the boundary directly, so `lastReset = serverTime + secs - 86400`. This closes deferred item #2 in the table above: the addon is no longer US-specific and needs no DST reasoning. The old fixed-hour math is kept as a fallback behind a guard that rejects nil, non-numbers, `<= 0`, `> 86400`, and a throwing API. `RESET_HOUR_UTC = 15` stays **only** as that fallback — do not treat it as the primary path.
- **Window position persists; Escape closes the window.** Added a second SavedVariable, `SkinningTrackerUIDB` (account-wide), and registered `SkinningTrackerFrame` in `UISpecialFrames`. Position is stored as anchor values only — `GetPoint()`'s second return is a frame object and cannot be serialised, so the window always re-anchors to `UIParent`. **The TOC must list `SkinningTrackerUIDB` or nothing persists.**
- **Init happens once, at `PLAYER_LOGIN`.** Dropped the `ADDON_LOADED` registration entirely: SavedVariables are already loaded by `PLAYER_LOGIN`, and `GetCharKey()` needs `UnitName("player")`/`GetRealmName()`, which are not guaranteed that early. `SkinningTrackerDB` now stays nil until login, which the `SPELLS_CHANGED` guard already handles.
- Collapsed the four copies of the `C_DateAndTime.GetServerTime() or time()` idiom into `ST:GetServerNow()`, so the convention in "Coding Conventions" above lives in one place.

**Verification:** the top ~197 lines of `SkinningTracker.lua` are load-time clean (pure Lua, no `CreateFrame`/`SlashCmdList`), so the real reset functions were extracted and executed in a Lua VM against a stubbed `C_DateAndTime`. 26/26 pass: the API path, all six bad-API shapes falling back correctly, a 48-hour hour-by-hour walk confirming the fallback boundary sits at 15:00:00 UTC and steps exactly once per day, and countdown formatting. Note the harness must shim `date = os.date` / `time = os.time`, since those are WoW globals. UI position/Escape behaviour is **not** covered — that needs the client.

### [2026-07-29] Claude Opus 5 (second pass, 1.4.4)
Fixed the two loot-handler items left over from the review pass below.
- **`BuildLootPattern` did not escape `%`.** The escape class omitted `%`, so the `%d` in `LOOT_ITEM_SELF_MULTIPLE` survived into the compiled pattern as the class "exactly one digit". Verified in a real Lua VM: the old multiple-item pattern matched `x2`/`x9` but **not** `x10`/`x100`. It never caused a visible bug because the single-item pattern's greedy `(.+)` matched those messages anyway, so the accept gate always passed and the loose `x(%d+)` scan still read the right number — it was dead code that looked load-bearing. Now escapes `%` first, then converts the escaped `%s`/`%d` specifiers into `(.+)` and `(%d+)` captures.
- **Quantity now comes from the pattern capture**, not from scanning the whole message for `x(%d+)` (which included the item link in its search space).
- **Both patterns compile once at load** instead of being rebuilt, along with a closure, on every `CHAT_MSG_LOOT` — a hot event in groups.
- Order matters in the new handler: the multiple form is tested **first**, because the single-item pattern also matches `...x10.` messages and testing it first would swallow the count and always report 1. Do not reorder these.
- Capture order assumes `%s` precedes `%d`, as it does in enUS. Fine per the English-only scope; revisit if localization is ever taken on.

**Verification:** ran the real extracted `BuildLootPattern` in a Lua 5.3 VM (`fengari` under Node — see the tooling note below) against single/x2/x9/x10/x100 messages plus another player's loot and a `You receive item:` push. All 7 cases pass; quantities parse correctly and non-self messages are rejected. Still not exercised in-game.

### [2026-07-29] Claude Opus 5
Full review of all three Lua files. Fixed the three state-correctness bugs; released as 1.4.3.
- **ElvUI datatext stale after daily reset.** The datatext registers only `{"PLAYER_LOGIN"}` and passes `nil` for ElvUI's `updateFunc`, so `ST:RefreshDataText()` only ran from progress changes or loot. Crossing the reset while logged in left it reading `Skins: Done!` until a skin or `/reload`. Fixed by calling `ST:RefreshDataText()` from the existing 30s ticker in `SkinningTrackerUI.lua`, outside the `IsShown()` guard — the datatext must update while the window is closed.
- **Login detection clobbered the manual toggle.** `data.isMidnightSkinner = IsSpellKnown(...)` overwrote the flag unconditionally, making `/skt toggle` last only until the next login. Worse, any login where `IsSpellKnown` returned false wiped the flag and dropped the character from `GetAllCharacters()`, which reads as data loss. Introduced tri-state `manualOverride` (nil = follow detection) plus `autoDetected`, centralised in `ApplySkinnerDetection()`. Detection now only ever sets the flag true; an explicit toggle always wins. Also registered `SPELLS_CHANGED` to retry.
- **`/skt reset` blanked the character row.** The fresh table hardcoded `isMidnightSkinner = false`, hiding the character until relog. Skinner flags are now carried across the reset. Note `manualOverride` is assigned separately rather than via `or` so an explicit `false` is not silently dropped.

Also reported but **not** fixed (deliberately left for the user to schedule):
- `BuildLootPattern` does not escape `%`, so the `%d` in `LOOT_ITEM_SELF_MULTIPLE` survives as a pattern class and `selfMulti` never matches quantities >= 10. Currently harmless — greedy `(.+)` in the single pattern matches anyway — but it is dead code that looks load-bearing.
- Both loot patterns are recompiled inside the handler on every `CHAT_MSG_LOOT`; should be hoisted to file scope.
- `RESET_HOUR_UTC` appears correct (Blizzard anchors US resets to a fixed UTC time) but the "7:00 AM PST / accounts for UTC-8" comment only describes winter. `C_DateAndTime.GetSecondsUntilDailyReset()` would delete the whole function and close deferred item #2 (EU realms).
- Frame position is not persisted and `SkinningTrackerFrame` is not in `UISpecialFrames` (Escape does not close it).
- `InitDB()` at `ADDON_LOADED` is redundant with the `PLAYER_LOGIN` call and relies on `UnitName`/`GetRealmName` being ready earlier than guaranteed.

**Tooling note (useful for future passes):** there is no Lua interpreter, compiler, pip, venv, or passwordless sudo on this machine (Windows or WSL), but Node is present, so two npm packages cover Lua work without any install friction:
- `luaparse` — pure-JS parser, for syntax checking. All files parse clean as Lua 5.1.
- `fengari` — a real Lua 5.3 VM in JS. Good enough to **execute** any logic that does not touch the WoW API (string/pattern code especially). Used to test the loot patterns above against real message strings.

Neither replaces an in-game `/reload`: anything calling `CreateFrame`, `C_Timer`, `UnitGUID`, `IsSpellKnown`, etc. can only be verified in the client.

### [2026-06-19] Antigravity
- Updated interface TOC version to 120007 to support World of Warcraft patch 12.0.7.
- Bumped version from 1.4.1 to 1.4.2 in TOC files and changelog.
- Packaged and committed the v1.4.0, v1.4.1, and v1.4.2 release ZIP files.

