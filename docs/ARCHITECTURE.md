# Source map

- game/missions.json: 60 explicit campaign missions and twelve region palettes; missions.gd: campaign/date/endless selection.
- game/simulation.gd: deterministic20Hz combat, legal purchases, waves, projectiles, counters and result accounting.
- game/progress.gd:25 typed save groups; bounded numbers/date validation; monotonic saved day; atomic temp validation, previous-valid backup and corrupt-primary recovery.
- game/session.gd: run identity, actual terminal banking, pending/fullscreen pause boundary and one earned callback entitlement. A callback never implies ad dismissal. Safe explicit Resume consumes a dismissal edge.
- game/main.gd: portrait pages, build controls, costs/counters, native reserve, pause/result affordances, sound/preferences.
- game/board.gd: original board/tower overlays using unchanged licensed Tiny Town/Tiny Dungeon atlases.
- platform/services.gd: supplied native Play Games/AdMob integration and previously reviewed fullscreen lifecycle code. It is reused byte-for-byte; native acceptance is separate from code reuse.
- platform/config.json: official Google test ads, disabled empty production Play Games placeholders.
- tests/strategy_check.gd and tests/test_core.gd: genuine legal-budget feasibility and independent action replay plus combat/save/day/callback invariants. tests/test_ui.gd: real scene with synthetic pointer input, isolated save and clearly fake native adapter.

Banked local progress survives restarts; unfinished battles intentionally do not. A save is written to a temporary file, flushed, parsed and normalized before commit. A valid previous primary rotates to backup; an invalid primary is quarantined while the known-good backup stays intact. Failed promotion copies a known-good backup back without consuming it. Local files and clocks are not anti-cheat security.
