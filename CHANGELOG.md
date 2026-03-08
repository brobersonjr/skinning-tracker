# Changelog

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
