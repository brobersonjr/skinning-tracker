# Changelog

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

