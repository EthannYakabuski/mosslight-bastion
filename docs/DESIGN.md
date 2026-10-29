# Design and balance

The campaign contains 100 explicit mission definitions across twenty regions. The first sixty IDs/names/routes/pads remain compatible. Forty new missions use eight authored route plans with rotated/mirrored variants across eight additional regions; all missions now have five to ten waves and a final-wave boss. The UTC date selects an authored mission for Daily defense; only Endless wave composition grows procedurally.

The production simulator advances at20Hz. Route occupancy never changes: towers live only on shown non-route pads. The four roles trade price, cadence, range, splash and armor/slow behavior. Towers upgrade through level3; selling refunds floor70% of actual supply spend. Free Rally lasts4 combat seconds, with an18 combat-second cooldown. Neither UI time nor an ad callback advances combat.

Ordinary campaign victories unlock the next mission and improve local stars. Keeper levels grant40 coins per level. Power costs100*1.65^owned (rounded), adds4% damage/level up to5; masonry adds one heart/level up to5. Both preparations are disabled in daily mode. Amber/moon lanterns cost150/250 coins and visibly recolor the keep lamp; no combat statistic changes.

The first victory on each campaign mission pays90+5*mission coins and45+5*mission XP, plus2 coins/XP per kill and4XP per wave. Replays pay30 coins/20XP plus performance amounts. A completed daily's first saved-day clear adds75 coins/35XP. A terminal defeat keeps its actual performance rewards; abandoned/unfinished rounds have no result credit.

One optional earned native repair per run grants up to8 hearts and40 supplies. The internal assisted flag limits repair to once per run. Earned-assisted results qualify for the same stars, daily score and endless best as all other runs. Legacy unassisted_* identifiers are retained only for save/backend compatibility. Free Rally and retries remain available without ads.

Round Five keeps the four tower statistics from the prior package. The existing
runner moves 15% faster; other original enemy roles have 20% more health. Six
additional roles provide animated moth, ooze, bulwark and three boss behaviors.
Wave deadlines include the last spawn plus 150% of ordinary route travel and
four seconds; an early full clear shortens the empty interval to six seconds.
Opening, intermission and overlapping waves share the paused production clock.

Initial source feasibility found six newly authored dual-route openings too
dense for the tested legal strategies. New missions now introduce both routes
with a lighter opening before armored/splitting packs; original enemy buffs,
wave counts and final bosses are retained. See `docs/ROUND_FIVE_UPDATE.md` for
the current revalidation status. Zero-preparation strategy witnesses prove only
model feasibility, not human balance or native/device acceptance.
