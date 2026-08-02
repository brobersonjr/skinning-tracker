# Changelog

## 1.5.0 - 2026-08-02
- Show what your Majestic materials are worth, using the auction prices Auctionator has scanned on your realm. The tracker window's bottom bar now reads `Session: ... · Lifetime: ...`, and the item counts table gains a per-character lifetime `Value` column.
- Session value clears on logout or `/reload`, exactly like the session item counts it is built from. Nothing about it is saved.
- Hover the gold readout for a breakdown: unit price per material, how long ago each was scanned, and exact totals. Hover an item name for that material's price on its own.
- Add `/skt gold` (alias `/skt value`) to print the same breakdown in chat.
- Materials with no scanned price are marked with `*` and named in the tooltip, so an unpriced total is never mistaken for a low one.
- Totals refresh the moment an auction house scan finishes, so a session priced before you scanned corrects itself.
- Auctionator is entirely optional. Without it the value readout simply says so and nothing else changes.

## 1.4.9 - 2026-07-31
- Set the addon author to `brobersonjr` instead of the placeholder `You`.
- Rewrite the README: what the addon does, install instructions, and the full command list.
- Add the MIT `LICENSE`, and ship it inside the release ZIP alongside the addon files.

## 1.4.8 - 2026-07-31
- Add a Manual Edit button to the tracker window. It unlocks the current character's checkboxes so a kill the addon missed can be recorded, or a wrong mark cleared. Off by default and re-locks when the window closes.
- Show hand-entered marks in green instead of the usual yellow, with a tooltip saying whether each check was auto-detected or set manually. A manual mark reverts to a normal auto mark if detection later catches the same beast.
- Restore `/skt mark <beast>` and add `/skt unmark <beast>` as the keyboard equivalent of the button.
- Checkmarks no longer render with the greyed-out disabled texture.
- Add a committed test harness under `tests/` so these paths can be re-run from the repository.

## 1.4.7 - 2026-07-31
- Make Renowned Beast checkmarks read-only now that automatic skinning detection is reliable.
- Remove manual beast toggling and disable `/skt mark`; legacy uses now explain that progress is tracked automatically.

## 1.4.6 - 2026-07-29
- Detect skinning through soft-target interact, so skinning with an interact keybind without hard-targeting the corpse is still tracked.
- Harden the skinning spell check against a future client removing the `IsSpellKnown` global; behaviour on current clients is unchanged.
- `/skt debug` now also reports loot messages that were ignored, making it possible to tell "no item was received" apart from "the message was not recognised".
- Refresh every ElvUI datatext panel, not just the most recently updated one, for users who place the datatext on more than one panel. Panels reassigned to a different datatext are released, so the tracker never overwrites a slot it no longer owns.
- Internal cleanup: shared `ST:GetCharKey()` instead of rebuilding the character key inline, and removed an unused button helper.

## 1.4.5 - 2026-07-29
- Read the daily reset from the client (`C_DateAndTime.GetSecondsUntilDailyReset`) instead of a hardcoded 15:00 UTC. The tracker is now correct on EU and other non-US realms, and no longer depends on a fixed UTC offset. The old fixed-hour math is kept as a fallback if the API is unavailable.
- Remember the tracker window position between sessions, and allow Escape to close the window.
- Initialise once at `PLAYER_LOGIN` instead of also at `ADDON_LOADED`, where the character name and realm are not guaranteed to be available yet.

## 1.4.4 - 2026-07-29
- Fix the loot message pattern builder not escaping `%`, which left the `%d` in `LOOT_ITEM_SELF_MULTIPLE` as a "single digit" character class so the multiple-item pattern could not match stacks of 10 or more. Stack size now comes from that pattern's capture instead of a loose scan of the whole message.
- Compile the loot patterns once at load instead of rebuilding both of them, plus a closure, on every `CHAT_MSG_LOOT` event.
- `/skt debug` loot output now includes the parsed quantity.

## 1.4.3 - 2026-07-29
- Fix ElvUI data text showing stale progress after the daily reset; it now refreshes on the shared 30s ticker even while the tracker window is closed.
- Fix login auto-detection wiping the manual `/skt toggle` state. An explicit toggle now persists, detection only ever enables tracking, and `SPELLS_CHANGED` retries detection in case the spellbook is not populated at login.
- Fix `/skt reset` removing the character from the tracker table until the next login; skinner flags are now preserved across a progress reset.

## 1.4.2 - 2026-06-19
- Update Interface version to 120007 for World of Warcraft patch 12.0.7.
- Fix ElvUI data text tooltip not showing on mouseover; replaced unreliable DT.tooltip with GameTooltip directly.
- Add Majestic Items section to the hover tooltip showing lifetime looted counts per item.

## 1.4.1 - 2026-03-14
- Fix second secret string taint path in delves: UnitName("target") can also be a protected string; name lookup now uses pcall-guarded strlower instead of name:lower().

## 1.4.0 - 2026-03-14
- Fix "secret string" taint error when skinning in delves; GUID string operations are now protected with pcall and gracefully return nil instead of erroring.

## 1.3.9 - 2026-03-10
- Fix ElvUI data text tooltip not showing on hover; fall back to GameTooltip when DT.tooltip is unavailable.

## 1.3.8 - 2026-03-09
- Fix Majestic item counter so stacked loot messages correctly increment by the full quantity.

## 1.3.7 - 2026-03-08
- Simplify Majestic loot audio to positive-only behavior (no negative "no drop" sound).
- Add `/skt testsound` and `/skt testsound <soundId>` for in-game sound verification.
- Set Majestic loot alert to single confirmed working sound ID `891` (sell/coin cue).

## 1.3.6 - 2026-03-08
- Add negative sound when a skinned beast yields no Majestic item (3-second window after skinning).
- Sound placeholders in use pending in-game confirmation of working sound IDs.

## 1.3.5 - 2026-03-08
- Fix loot sound: SOUNDKIT.IG_TREASURE_OPEN does not exist in Midnight; switched to PlaySoundFile with the classic MoneyFrameOpen.wav.

## 1.3.4 - 2026-03-07
- Fix loot sound: use `PlaySound()` global instead of non-existent `C_Sound.PlaySound()`.

## 1.3.3 - 2026-03-08
- Fix loot line matching to ensure Majestic item sounds trigger reliably.

## 1.3.2 - 2026-03-07
- Fix CHANNEL_STOP false positive: defer marking by one frame so an interrupted channel cast does not incorrectly record a beast as skinned.

## 1.3.1 - 2026-03-08
- Fix UI refresh to reuse widgets and avoid frame/region leaks.
- Make /skt reset reinitialize item totals to prevent loot tracking errors.
- Use shared reset-time logic across UI and core.
- Make loot detection locale-safe.
- Clarify skinning spell ID comment.

