# WTAGarou: Wits backlog and private multiplayer test gates

Planning baseline: September 30, 2026, Resolve 0.4.32. This is a proposed
implementation order, not a release schedule or a claim of multiplayer readiness.
This document changes no gameplay.

Status note (October 13, 2026, 0.4.58): a first slice of W1-W4 shipped
statically verified in [WITS_SILVER_0458.md](WITS_SILVER_0458.md): silver
variants for the eight vanilla calibres, strip/tip/forge recipes, homogeneous
loading with mixed loads refused, per-shot flag and the located burn through
the Java hit recorder. Multiplayer conservation (W6), mixed magazines (W7) and
the Hunter trait (W5) remain open; nothing below is live-confirmed yet.

## Now, next, later

- **Now: Resolve:** stabilize transformation, Rage and existing cosmetics; prepare
  a small private multiplayer test. Preserve confirmed behavior and author assets.
- **Next: 2.0 Wits:** silver ammunition, its in-game crafting, and the Hunter trait
  with counterplay-focused skill bonuses. Ship a reliable single-type loading
  system before considering mixed ammunition.
- **Later: Gnosis:** werewolf magic, spirits and auspices with skill boosts.
  No spell list, progression system or delivery date is committed.

Project-owner approval governs balance and release decisions. Implementation
ownership is unassigned until each milestone is scheduled. Dependencies below
are the required completion gates; there are no calendar or credit estimates.

## Wits milestones

| ID | Priority and scope | Depends on | Acceptance gate |
|---|---|---|---|
| W0 | Must: ammunition and hit-path investigation | None | Document magazine, chamber, internal magazine/revolver, firing and actual struck-body-part paths on the pinned game build; identify client/server authority and save format before implementation. |
| W1 | Must: silver ammunition catalog | W0 | Each supported vanilla firearm ammo type has an explicit silver variant/tag, correct caliber compatibility and unchanged ordinary damage/range/accuracy. Publish coverage and exclusions; do not promise automatic support for every mod. |
| W2 | Must: in-game salvage and crafting | W1 | Jewelry yields silver pieces; matching ordinary ammo plus pieces produces silver ammo using reusable file/pliers tools. Cancellation cannot duplicate ingredients or output. Quantities, skill thresholds and time remain balance decisions. |
| W3 | Must: single-type loading and persistence | W0, W1 | Magazine/tube/cylinder contains ordinary OR silver ammo; mixed loading is clearly refused. Chamber type is tracked independently. Load, top-up, unload, rack/eject, swap, transfer and save/reconnect conserve both types without conversion or duplication. |
| W4 | Must: shot-specific, located Silver Burn | W0, W3 | Each actually fired silver round consumes once, including misses. Only Garou hits add burn to the actual struck body part; ordinary rounds do not. Last-round, multi-hit and network-replay cases cannot leak silver status to another shot. |
| W5 | Must for Hunter release: trait and progression | W2, W4 | Specify Hunter/Garou coexistence rules, costs, recipe access and skill bonuses; validate permissions on the server and migration on existing saves. No permanent gun-level silver toggle in the production mechanic. |
| W6 | Must before Wits private build: balance and regression | W2–W5 | Ammo conservation, correct hit locations, ordinary-target parity and two-client firing/reload/reconnect tests pass. No regression to Resolve form/Rage/gear behavior. |
| W7 | Later enhancement: mixed magazines | W3, W4, W6 | Persist ordered ordinary/silver rounds, not just a silver count; keep chamber separate. Partial reload/unload, magazine transfer, jams/ejection where supported, save/load and multiplayer all preserve ordering and ownership. |

Build and test one representative magazine-fed weapon plus one internal-load
weapon first, then expand to the supported vanilla catalog before W6. W7 is
explicitly **not a blocker for the first Wits release**.

## Behavior contracts and decisions

- **Not an enchanted firearm:** determine silver status from the projectile's
  consumed round, not the gun's name or whether it ever held silver ammunition.
  A silver chambered round can remain after inserting an ordinary magazine.
- **No hidden ballistic bonus:** normal bullet damage may still kill. Add only
  the requested silver condition; the nonlethal guard concerns ongoing silver
  burn damage, not bullet impacts or unrelated wounds.
- **Correct location:** replace the existing random-body-part hit shortcut.
  If the true impact part cannot be obtained reliably, W4 is blocked rather than
  silently marking a random limb.
- **Treatment semantics:** preserve affected-part regeneration blocking and
  washing/bandaging. Decide separately whether an embedded silver projectile
  causes continuing exposure until removed; jewelry-contact escalation must not
  accidentally become indefinite exposure from every bullet hit.
- **Migration:** existing ordinary loads stay ordinary. Define how old debug
  silver flags are cleared or explicitly migrated; do not retroactively turn
  ammunition silver because a testing flag was left on a gun.
- **Authority:** the authoritative side validates crafting, consumption and hits.
  Packet retries must not duplicate ammo or burns. Client UI is not proof of a hit.
- **Open balance choices:** scrap yields, recipe access, tools/skills, initial
  projectile-burn severity, Hunter skill bonuses, trait exclusivity and silver
  buckshot handling. Approve these before their implementation milestone.

The current [silver handler](https://github.com/SeeGeeArtist/Zomboid-Garou/blob/feature/cosmetic-model-swap/WTAGarou/42/media/lua/server/WTAGarouSilver.lua)
contains testing shortcuts, not a completed ammo lifecycle. The engine exposes
ammo count/type and chamber state through
[InventoryItem](https://projectzomboid.com/modding/zombie/inventory/InventoryItem.html)
and [HandWeapon](https://projectzomboid.com/modding/zombie/inventory/types/HandWeapon.html);
W0 must still verify the relevant paths against the installed build.

## Private multiplayer: Resolve can go first

Use this checklist for a controlled alpha, not a public launch. Wits and Gnosis
are not prerequisites. Gameplay correctness and save safety take precedence over
perfect item placement, seated head movement or finished Crinos artwork.

### Before inviting the first small group

- [ ] **MP0: freeze a candidate.** Pin the game build, mod commit, Java JAR and
  compatible ZombieBuddy build; write host/client installation instructions.
  Select hosted or dedicated mode explicitly and do not infer support for the
  other from one successful test.
- [ ] **MP1: protect saves.** Back up server/player data and test restore. Start
  with a disposable world and characters, not a valued ongoing campaign.
- [ ] **MP2: validate packaging.** Host and clients have matching assets and
  versions; identify which Java components are client-only. Do not bundle the
  proprietary game JAR or assume a local loader patch is safe to redistribute.
- [ ] **MP3: restrict debug powers.** Verify non-admin clients cannot grant traits,
  force forms, set Rage, spawn items or invoke testing commands without permission.
  Prefer server-disabled debug tools except for the designated tester.
- [ ] **MP4: two-client smoke test.** One Garou and one observer, then swap roles.
  Verify remote form/scale/coat/Crinos gear, shift cancellation, Rage costs,
  zero-Rage true-form return and a single Crinos burst per completed shift.
- [ ] **MP5: persistence and safety.** Late join, reconnect, server restart,
  death/corpse/reanimation/respawn and two different coats/true forms do not
  overwrite another player's identity, inventory or state.
- [ ] **MP6: failure handling.** Test a lost connection during a shift and during
  equipment changes; no stuck reservations, duplicate items or permanent
  movement locks. Record recurring exceptions and sustained performance problems.

### During the private alpha

- [ ] **Alpha-1: everyday interactions.** Ground/chair get-up, fences/windows,
  held/back/belt/holster transitions, saddlebags, silver contact/treatment and
  raw-versus-rotten food. Resolve 0.4.32 ground get-up and ammo-kit fixes still
  need an in-game check; fence/window recovery was not tested in the last run.
- [ ] **Alpha-2: test intended combat settings.** Verify the chosen PvP/friendly
  fire configuration, observer agreement and zombie ownership changes; solo
  evidence is not sufficient for multiplayer combat.
- [ ] **Alpha-3: keep useful reports.** Record game/mod/loader versions, hosted
  versus dedicated mode, actor/observer roles, steps, expected/actual result,
  timestamp and relevant host/client console excerpts. Share privately and
  redact credentials or server access details.

**Stop the session and retain logs/backups** for save corruption, inventory
duplication/loss, unauthorized debug actions, repeated crashes, persistent state
desynchronization or unrecoverable movement locks. Cosmetic clipping can remain
a documented known issue if it does not block play.

Do not open a server, publish the mod or send invitations based on this document
alone. Those actions require the project owner's explicit release decision.

## Parking lot, not hidden release blockers

- **Art and fit:** author-made Crinos head/neck and male/female UV skins, wolf
  head-angle edits, optional per-item attachment overrides.
- **Animation polish:** seated neck/head looking and further authored transitions.
- **Reanimated wolf:** separate IsoZombie visuals, not an extension that the
  existing wolf corpse snapshot automatically supplies.
- **Modded ammunition:** compatibility adapters after the vanilla catalog is
  reliable; preserve special mod behavior rather than blindly cloning items.

For the tested baseline and unresolved visual checks, see
[Resolve 0.4.32 handoff](PLAYTEST_FIXES_0432.md) and the
[regression contract](REGRESSION_CONTRACT.md).
