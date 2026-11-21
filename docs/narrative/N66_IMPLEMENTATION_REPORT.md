# N6.6 Implementation Report — First Camp Active Defense & Player Response

**Status:** IMPLEMENTED (`feature/n66-first-camp-active-defense`)
**Engine Baseline:** `Godot 4.7.2.stable.official.ed1daf0bf`
**Base Commit:** `40ca990dcf989d6f966e8fa5db5ee5ecb52b9a41` (N6.5 merge)

---

## 1. Selected Mechanic & Architecture Fit

- **Mechanic:** **First Camp Ward Pulse** — a player-triggered protective hearth pulse activated via the existing `kindle_flare` (`[Space]`) input action and `PlayerController.kindle_flare_requested` signal.
- **Why It Fits:** Reuses existing `PlayerController` input plumbing without modifying `project.godot` or `Player.gd`, keeps `[E]` First Camp rest semantics 100% intact for N6.3/N6.4/N6.5 regressions, and connects directly to `EconomyLedger` (`1 Wood` cost, renewable via Eldergrove Timber) and the authoritative `EldergroveNightSurvival` simulation.

## 2. Eligibility Rules & Gameplay Consequences

- **Eligibility:** Requires an active Eldergrove session, constructed First Camp, active night encounter (`is_encounter_active()`), player inside First Camp defense range (`<= 84.0px` of `CAMP_SITE_X`), cooldown expired (`8.0s`), and `1 Wood` in `EconomyLedger`. Invalid activations fail safely with explicit HUD feedback and spend zero resources.
- **Ordinary Threats (`ThreatClass.ORDINARY`):** Pushed back `140.0px` away from First Camp and staggered for `3.0s`.
- **Breach-Capable Threats (`ThreatClass.BREACH_CAPABLE`):** Pushed back `96.0px` and staggered for `1.5s`; if forced back outside `[-4.0, 164.0]`, clears `camp_breached` until the Brute advances back inside.
- **Lifecycle Safety:** Never auto-resolves the encounter or skips Night. When the player does nothing, N6.4/N6.5 behavior is unchanged.

## 3. Integration with N6.4 & N6.5

- `EldergroveNightSurvival.apply_camp_defense_pulse()` owns all pushback, stagger, cooldown, and breach-repel state.
- `EldergroveThreatPresenter` strictly reflects `is_threat_staggered()` and `defense_pulse_visual_remaining` with a restrained pixel-art hearth pulse bar (`WardPulseBar`), ward-post highlight, and `"Staggered"` label.
- **SaveManager Schema v2:** Unchanged (`SCHEMA_VERSION == 2`). Wood spent persists via existing `EconomyLedger`; transient cooldown/stagger reset cleanly on sunrise or Continue.

## 4. Tests & Known Limitations

- `tests/test_n66_first_camp_active_defense.gd` (registered in `tests/run_all.sh`) verifies unbuilt/daylight/out-of-range/cooldown/insufficient-Wood rejections, `PlayerController.kindle_flare_requested` activation, Ordinary pushback & stagger, Breach repel, presentation sync, HUD feedback, and SaveManager v2 Continue persistence.
- **Known Limitations:** Single defensive pulse type (no multi-tier camp upgrades, ranged projectiles, or enemy health/defeat system — intentionally deferred beyond N6.6).
