# Resolve, Wits, Gnosis and A-Life roadmap addendum

Planning update: November 3, 2026. Documentation only; no feature is implemented or live-tested by this change.

November 7 addition: the author specified auspice starting skill levels for
the future three-skill milestone below. This addition is planning only;
it does not grant levels or change the current Resolve candidate.

Read alongside [Wits backlog](WITS_BACKLOG.md) and [Umbral glyph library](UMBRAL_GLYPH_LIBRARY.md). Existing silver-ammunition, migration and multiplayer gates remain in force. Where acquisition differs, the spirit-flier prototype below supersedes the older mandatory crafted-not-awarded loop for the initial implementation. The historical thirty-glyph catalog remains optional inspiration, not a release requirement.

## Scope and order

1. Implement custom Resolve progression and bounded shifting/Rage modifiers first.
2. Build one reusable spirit-flier quest and gift framework: one flier, one destination, one communion action and one silver-purging gift. Validate hosted multiplayer before expanding.
3. Add Wits/Infamy using A-Life human witnesses, independently of the spirit prototype. Preserve existing ammunition priorities.
4. Expand gifts and later NPC Garou integration only after small, tested slices work. No calendar, credit estimate or commitment to dozens of gifts.

Resolve, Wits and Gnosis are intended as custom skills. Verify registration, UI, XP persistence and server synchronization on the pinned game build. Auspices provide the starting levels below; they do not restrict which skills a character may train. XP curves and gift ranks are separate tuning decisions.

## Auspice starting Garou skills

Author decision, November 7: apply these starting levels when all three
Garou skills, Resolve, Wits and Gnosis, are implemented. Do not introduce
the Resolve portion early into the current Resolve-only candidate.

| Auspice | Resolve | Wits | Gnosis |
|---|---:|---:|---:|
| Ragabash | 0 | 2 | 1 |
| Theurge | 0 | 1 | 2 |
| Philodox | 1 | 1 | 1 |
| Galliard | 2 | 1 | 0 |
| Ahroun | 2 | 0 | 1 |

Each auspice starts with three total Garou skill levels. These are initial
levels, not level caps, recurring XP awards or restrictions on progression.
They follow the permanent Startup auspice selection, not the current moon
phase, exposure or moon-adjusted Rage baseline.

Before implementation, decide how existing characters receive the starting
allocation without losing earned levels or receiving repeat grants. That
migration and the behavior of identity reset remain open; this roadmap
entry does not authorize resetting trained skills. Verify a one-time,
server-owned grant, correct XP/level bookkeeping, persistence and reconnect
behavior when the three-skill milestone is implemented.

## Resolve: shifting and Rage management

- Train primarily by successfully resisting forced Crinos, once per resolved episode; grant smaller rewards for completed shifts. No XP per frame, cancelled attempt or unbounded shift-spamming.
- Govern pull toward the existing chosen baseline, forced-Crinos countdown resilience, shift time and Rage costs, and Crinos Rage drain. Preserve baseline identity; compute modifiers from base values rather than compounding changes each tick.
- Retain minimum costs, positive drain and meaningful risk. Verify zero-level behavior before tuning mastery.
- Unlock or improve roar stagger, zombie charge and door charge. Later levels may improve roar knockdown likelihood and the number of zombies a charge penetrates.
- Consider tougher-door charging at increased Rage/endurance cost, or greater zombie penetration if stronger-door support is impractical. Respect protected objects, safehouses and PvP policy. Preserve existing tested abilities unless a migration is explicitly approved.

## Wits and Infamy: witnesses

Reputation concerns relationships; Infamy concerns escaped supernatural evidence. Retain the difference between anonymous monster rumors and clues linking forms to an identity.

### Creating evidence

- Only eligible neutral/hostile human NPCs count; exclude zombies and supernatural NPCs. Evaluate stance before a supernatural reaction changes it.
- Require actual sight and a short observation duration. Hearing a shift, roar or supernatural form never creates a witness by itself. Audit A-Life vision, facing and occlusion rather than using proximity alone.
- Form witnesses: sufficiently clear observation of Glabro, Hispo or Crinos. Glabro/Hispo should be harder to recognize than Crinos. Homid/Lupus alone never create form witnesses.
- Shift witnesses: observed transformation, including forced reversion and raging/forced Crinos. Homid or Lupus endpoints do not exempt the transformation. Define sight continuity around brief transitions; arriving afterward is not witnessing the shift.
- Keep one pending report per NPC/player/encounter; upgrade form evidence to shift evidence rather than double-counting. Define encounter boundaries and repeat-report cooldowns.

### Escape and reporting

Persist pending evidence against stable NPC and player IDs. A genuine in-world unload into off-screen simulation starts an escape delay. After enough in-world time, consume the witness state and increment Infamy exactly once. A client cull, disconnect or server shutdown alone is not proof of escape.

Recommended first behavior: reloading the NPC before reporting resets the escape delay; a known death cancels the pending report. Distinguish death, off-screen existence and unknown/permanent removal. Do not infer survival or death solely from absence of a loaded body. Persist state through save/restart and prevent duplicate reports on retries; offline wall-clock time should not silently advance the initial implementation.

Form reports add a little Infamy; shift reports add significantly more and help hunters deduce identity faster. Delirium is represented as confused, monstrous testimony that a knowledgeable hunter can interpret, not automatic perfect identity/location knowledge for every NPC. These are mod design semantics, not a universal tabletop Delirium rule.

### Wits feedback and scaling

- Level 0: overhead messages such as "Someone saw you shift" or "Someone saw your Crinos form", using the style of the silver warning. Notify once on creation/upgrade and throttle crowds.
- Level 1: mark loaded witnesses with a symbol for pursuit. Visibility rules need testing; do not silently introduce wall-penetrating or off-map tracking.
- Each level should help avoid witnesses. Recommended first model: increase required observation duration, with finite positive thresholds. Alternative: roll reduced witness probability once per NPC/player encounter and retain that result until the next encounter, never reroll each scan. Do not combine both before playtesting.
- Improve silver sniffing by multiplying each form's existing range, preserving form-specific proportions.
- Wits training sources remain open; scanning/marking an NPC repeatedly must not farm XP.

## Gnosis: spirit fliers and communion

1. Find and read a spirit flier/brochure with resumable page progress. Reading represents deciphering its instructions.
2. Finishing reveals a random destination selected from a curated pool of suitable reachable sites. Persist quest ID, reward, coordinates/floor and stage; no save/reload rerolls. Provide a clear location hint and optionally a map annotation.
3. Reach the location and make the immediate ritual space safe. Use understandable local threat checks, not an unexplained demand to kill every zombie across a large region. Handle unavailable sites and map changes safely.
4. Read the completed flier again within the destination area to start a separate meditation action. Movement, damage or nearby threats can interrupt it with a clear explanation. Retain the quest item on interruption.
5. Successful communion transforms the flier into the gift and awards bounded Gnosis XP once. Validate eligibility and grant the reward without item loss or duplication.

Decide reading ownership, transfer, shared credit, duplicate gifts, permanent learning versus physical gift items, death persistence and interrupted-meditation progress before multiplayer implementation. The first prototype uses item conversion; permanent unlock/recrafting systems remain open. Gnosis starts as a skill, not a promised extra spendable resource pool. Re-reading completed content cannot generate free XP.

## Reusable gifts

Use shared consumable, wearable and active-implement categories. Centralize costs, cooldowns, allowed forms, scaling, stacking and network authority; do not build a separate quest engine for each gift.

- Silver purification, first prototype: remove all silver-burn conditions for significant Rage cost, re-enabling normal supernatural healing. Do not instantly heal underlying wounds or remove lodged silver. Continuing exposure can inflict fresh burns. Test low-Rage/Crinos-exit interactions.
- Baseline restoration: owner proposed instantly setting Rage to baseline. Recommended first version only lowers excess Rage; whether it also replenishes low Rage is an explicit balance decision. Require cooldown/anti-loop limits.
- Rumor suppression: reduce some Infamy without erasing an informed hunter's personal knowledge or cancelling an attack already underway. Specify how rumor and identity evidence are affected.
- Strength/speed blessings: temporary bounded boosts with explicit stacking and expiry; no permanent mutation of base values.
- Squirrel wearable: improve climbing/vaulting reliability and reduce exertion, including while fatigued. Audit actual stumble/failure hooks; no unlimited endurance or guaranteed obstacle safety. Check form wear/strip behavior.
- Lightning implement: equip a spirit gift as a weapon and call lightning on a valid ranged hit. Desired invisible traveling projectile remains a technical investigation. Recommended prototype uses an instantaneous validated hit plus impact visuals. A thrown arc is not equivalent to a traveling bolt.

Lightning needs authoritative range, obstruction, target, cost, cooldown and PvP/friendly-fire validation. Separate visuals from damage; default to no global weather changes or uncontrolled fire spread. Verify pinned-build APIs rather than treating historical feasibility notes as implementation proof.

## A-Life first and NPC Garou

A-Life is the primary NPC integration. Bandits/Week One is not a dependency and troubleshooting it is outside this milestone. The owner's hosted Week One failure is reported, not diagnosed; do not conclude every variant lacks multiplayer. Do not assume simultaneous NPC engines are compatible.

First prove one A-Life NPC can shift, fight, revert and retain identity, faction, inventory and relationships. Then add AI shift decisions and tribe definitions such as Bone Gnawers, Black Spiral Dancers and Shadow Lords. Later diplomacy/conflict opportunities should be bounded and configurable, not perpetual random global war. Audit actual lifecycle hooks before promising APIs.

Optional later atmosphere: original A-Life-backed parties, street preachers, gatherings, travelers and faction meetings. Start with one small persistent scene, prevent duplicate spawns on reload and apply normal witness rules to eligible humans. These are wishes, not claimed upstream capabilities or permission to copy Week One code, assets, dialogue or audio.

## Acceptance gates and deferred work

- Skills and pending witnesses survive save, reconnect and server restart without cross-player state leaks or repeated XP/reports.
- Test sight-only exclusions, every forced-shift path, form-to-shift upgrades, unload/reload, off-screen deaths and crowd notifications.
- Test one flier through partial reading, revelation, travel, interrupted communion, completion and gift use. No rerolls, lost items or duplicate rewards.
- Validate quest/item ownership and authoritative effects with two clients in a hosted game. Dedicated-server support is a separate gate.
- Preserve ordinary targets, wounds, inventory and existing Resolve behavior. Use targeted regression checks; documentation review is not a live-game test.
- Explicitly deferred: truncated Wyrm Infection purge text, shortened body-part-list viewport/scrollbar, and raw-meat sickness in hosted games. No fix is installed or validated by these notes.
