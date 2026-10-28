# Mechanics reference: Legacy of Goku II and Legacy of Oto

What Legacy of Goku II (Webfoot/Atari, GBA, 2003) does system by system, what Oto does today,
and what is still missing. Read this before building or tuning a gameplay system, then take
the next item from the backlog at the end.

**Note:** the "Oto now" lines describe the game before the 2026-10-28 build pass, which
built the whole backlog. For what the game does now, see the build status under Backlog
and `docs/STATUS.md`.

## Ground rules

- **Borrow the style, not the game.** Use LoG II for feel, pacing and structure. Don't port its
  maps, quest lists, dialogue, sprites or exact numbers. Oto's world, story and systems are
  her own (story bible: the user's Oto Story and Oto Design Document).
- **No ROM-derived code or assets.** That includes the GBA recompilation projects. Every
  figure below comes from public FAQs and wikis (see Sources).
- **Confidence tags:** an untagged line comes from a contemporary FAQ or wiki. **[verify]**
  means the sources were thin or disagreed, so ask the user (they have played it) before
  relying on it. **[BF]** means the mechanic comes from the sequel, Buu's Fury (2004), not
  LoG II. Several of Oto's current systems come from Buu's Fury.
- **Story rules win.** Where a LoG II mechanic clashes with the memory ladder (Oto re-earns
  her forms) or with canon outcomes, the design document decides. The user's decisions and
  the questions still open are listed at the end. Don't settle an open one silently.

## Core loop

Walk a top-down overworld. Fight enemies in real time on the map itself, with no separate
battle screen. Earn EXP, level up and get stronger. Numbered level gates and story flags open
new areas. Between story beats, NPC side quests and collectible sets fill the map. Bosses
are story set pieces with one gimmick each. Flight points link the areas.

## Controls

| Action | LoG II (GBA) | Oto now (`scripts/controls.gd`) |
| --- | --- | --- |
| Move | D-pad, double-tap to run | Arrows/WASD; double-tap runs (uses stamina) |
| Melee | A; hold A for a charged melee special | Z/J: 3-hit combo, third hit launches |
| Ki | B fires the selected blast; hold for a rapid stream | X/K: hold to charge 3 levels, release to fire |
| Switch ki attack | L | Q (`cycle`) is bound but **unused** |
| Transform | A gauge fills; when full, press a button (which one doesn't matter: we pick our own) | F up a form, G down |
| Guard / barrier | none **[verify]**; R guard and B+R energy block **[BF]** | C/L guard; guard + special toggles barrier |
| Charge ki | Stand still and hold to charge slowly up to max (per the user) | V, standing still (see Ki charging) |
| Scouter | Select (needs the scouter item) | none |
| Map | R | Tab on the world map |
| Menu | Start | Enter/Esc |
| Talk / examine | A | E |

## Combat

### Melee
- **LoG II:** tapping A punches. Holding A charges a character-specific melee special
  (sword cross-slash, flying kick, spinning punch, two-handed smash, punch flurry). Buu's
  Fury dropped the charged melee.
- **Oto:** 3-hit combo with a 0.4 s window. Damage is `(4 + STR*0.8 + 2 on hit 3) * form`,
  hitting 1.3 m around a point 1 m ahead. Hit 3 launches the enemy. The held melee is a
  punch flurry: hold attack 0.75 s and release for four punches (the quad punch animation),
  the last one launching. Animations: docs/RIGGING.md.

### Ki attacks
- **LoG II:** every character has a weak basic blast (hold for a stream of small shots) plus
  a signature special, cycled with L. The specials cover these archetypes, a useful menu
  for designing Oto's own:
  - **Wave** that travels forward and pierces.
  - **Flash stun** around the player (a brief blinding stun).
  - **Lobbed ball** that explodes on landing; holding sets the range.
  - **Channelled beam**: charge, then fire while ki drains continuously.
  - **Spread**: 3 shots in a fan.
  - **Charge-and-release orb** that grows stronger the longer it is held.
  - **Ki-infused melee**: each punch costs ki.
  - **Big slow stun bomb** that both stuns and damages.
  - **Screen-wide stun** (the joke character's pose).
- **Oto:** one shot type with 3 charge levels (0.45 s and 1.1 s thresholds; 8/20/40 ki).
  Damage is `(6 + POW*1.2 + level*8) * form`. Level-2 shots pierce, and levels 1-2 launch.
  `KiShot` already supports `hostile` shots for enemies.

### Defence
- **LoG II:** none found in the sources **[verify]**. You dodge and kill fast.
- **Oto [BF-style]:** guard takes 80% off a hit. The barrier blocks everything and drains
  10 ki/s. Endurance reduces damage by 1.5% per point (capped at 70%). Hits give 0.5 s of
  i-frames and 0.2 s of hitstun. The Void form ignores 25% of hits.

### Feedback
- **LoG II:** damage numbers float above whatever is hit, and they are a big part of how
  levelling feels. Oto has **none** (gap).

### Calibration
- **LoG II:** a mid-game boss had about 2,900 HP. The FAQ says it took 10-20 strong hits to
  knock off the half that mattered. Regular enemies die in a handful of hits.
- **Oto now:** the default enemy (40 HP) takes 5 combo hits at level 1, STR 5.
- **Suggested target:** regular enemies die in 3-6 hits at their region's level, and bosses
  take 15-40 hits spread over phases.

## Resources: HP, ki and transforming

| | LoG II | Oto now |
| --- | --- | --- |
| HP | Red bar. Meat dropped by enemies refills it; cookies give 5 HP; a senzu bean restores HP and ki | `100 + 10/level`. No drops. Death respawns at the arena centre with full HP and ki |
| Ki | Green bar. Each blast costs ki; yellow ki orbs from enemies refill it, and so does standing still to charge, slowly | `60 + 4/level`. Regenerates 1.5/s in base form (more with gear), 15/s while charging (V) |
| Transform | A yellow gauge fills slowly; when full you can transform. While transformed, all stats rise and energy drains | Forms 1-3 unlocked by `GameState.max_form`. Each costs ki per second (2/5/9) and reverts at 0 |
| Run | Double-tap | Double-tap; stamina drains 25/s and refills 30/s |

**Decided:** no transform gauge. Forms keep draining ki per second. The memory ladder
already limits which forms Oto has, and the drain limits how long she can hold one.

### Ki charging

**Decided (the user, 2026-10-28):** standing still and holding charge refills ki up to max.
Charging gets better in tiers, from **Basic Charge** up to **Perfect Charge**. Each tier
shortens the delay before ki starts to rise and raises the rate it rises at.

**Oto now:** `Player._update_charge` adds a flat 15 ki/s, with no delay, while `charge` (V)
is held and she stands still. That doesn't scale: max ki at level 100 is 456, which would
take 30 s to fill.

**Tiers** (approved by the user on 2026-10-28; tune the numbers in play).
The rate is a share of max ki, so a full charge takes the same time at any level.

| Tier | Delay before ki rises | Rate | Empty to full |
| --- | --- | --- | --- |
| Basic Charge | 1.0 s | 8% of max per second | about 13.5 s |
| Steady Charge | 0.7 s | 12% | about 9 s |
| Focused Charge | 0.45 s | 18% | about 6 s |
| Deep Charge | 0.25 s | 25% | about 4.3 s |
| Perfect Charge | 0.1 s | 35% | about 3 s |

**Proposed rules:**
- Moving, attacking, guarding or taking a hit stops the charge, and the delay starts over.
  Charging is a risk you take when there's space, never something you do mid-brawl for free.
- Charging works in Shadow forms too, but has to beat the form's drain (2, 5 or 9 ki/s).
- **Decided:** tiers are earned through training, meaning spars and lessons, one teacher
  per tier.

**Teachers** (approved by the user on 2026-10-28). Each one is tied to a training beat
already in the Oto Story or the design document, and they follow her arc toward a calmer,
quieter ki:

| Tier | Earned from | When | Why it fits |
| --- | --- | --- | --- |
| Basic Charge | Body memory; she has it on waking | Start | The prologue gives her Perfect Charge, and the throw strips it along with her forms |
| Steady Charge | Goku, the first spar at Mt. Paozu | Opening of the Saiyan Saga (the scene exists: `paozu.gd`, `--spar`) | Goku "watches every move", and her body remembers more than she does |
| Focused Charge | Master Roshi's side lesson at Kame House (optional, early), or the gravity machine on the ship to Namek | Any time before Namek; the ship is the fallback | "Six days is a long time to sit still." She dials it to the top |
| Deep Charge | The white room, with Kami and Mr. Popo | Android Saga | A year spent "learning to be silent on purpose" |
| Perfect Charge | Lessons with Whis, paid for in Chi-Chi's cooking | Super Saga | "The god's ki is calm. Your ki is calm." |

**Notes for the agent who builds this:**
- **Roshi's side lesson (approved).** The design document gives Master Roshi no beat with
  Oto, so this is an optional side quest at Kame House. It teaches Focused Charge early.
  Players who skip it still learn it on the ship. If she already has it, the gravity
  machine scene still plays but teaches nothing new, and one line can nod to Roshi.
  Keep the scene in the design document's tone: the comedy is about food, never about
  pain.
- A lesson must never reveal a memory early. Tiers sit outside the memory ladder.

**Oto's form multipliers** (`GameState.FORM_*`):

| Form | Damage | Speed |
| --- | --- | --- |
| Base | x1.0 | x1.0 |
| Shadow Saiyan | x1.8 | x1.2 |
| SS2: the Void | x2.6 | x1.35 |
| SS3: Cohesion | x3.4 | x1.15 |

## Stats and progression

- **LoG II:**
  - Three stats: Strength (melee), Power (ki) and Endurance (defence).
  - Each character levels separately. The level cap is 50 and each stat caps at 100.
  - Stats grow on their own as you level (confirmed by the user). Choosing points
    yourself arrived with Buu's Fury.
  - Stat capsules give a permanent +1, +3 or +5 to one stat.
- **Buu's Fury [BF]:**
  - 3 points per level to place yourself.
  - Equipment slots.
  - Weighted "Ton" armbands and boots trade speed for more EXP.
- **Oto now:**
  - **Stats:** STR, POW and END, with 3 points per level placed in the pause menu.
  - **Capsules:** red, blue and green, +1 only (`scripts/pickup.gd`).
  - **Gear:** 6 slots (hand, body, feet, 3 accessories) in `scripts/items.gd`, including
    weighted gear (EXP x1.25 to x2 for lower stats and speed).
  - **Level cap:** none in code yet.
  - **EXP curve:** `20 + 4*lv^2` per level, so about 163k EXP from level 1 to 50, 282k
    from 1 to 60 and 1.3M from 1 to 100.
- **Decided for Oto:**
  - Keep placing 3 points per level yourself, rather than LoG II's automatic growth.
  - Cap levels at 100, which leaves room past her prologue peak of 60.
  - Cap each stat at 255. The cap covers what points and capsules add; gear and forms
    apply on top of it. A stat at the cap takes no more points, and a capsule for it says
    so instead of being wasted silently.

**LoG II reference points** (playable characters on joining, each a different character):

| Level | LoG II HP / energy | Oto at the same level (HP / ki) |
| --- | --- | --- |
| 1 | 85 / 20 | 100 / 60 |
| 10 | 164 / 50 | 190 / 96 |
| 18 | 286 / 69 | 270 / 128 |
| 35 | 805 / 117 | 440 / 196 |

**What this shows:** HP in LoG II grows faster than Oto's (about 20 per level against 10).
Energy grows more slowly but starts lower. These are calibration notes, not targets; what
matters is how enemy damage scales against them.

**EXP economy in LoG II:**
- Boss EXP climbs roughly geometrically: 275, 1.5k, 3.4k, 5k, 8.9k, 15k, 30k, 40k, 50k,
  500k, and 600k for the optional final boss.
- Areas behind high gates hold regular enemies worth 35k+ each. Grinding spots are a
  deliberate reward for opening a gate.
- Players saved the biggest boss EXP for just under the cap.
- **For Oto:** decide "kills per level" for each region rather than copying the numbers.

## Enemies

**LoG II's patterns:**
- **Families reused in tiers:** one species appears in several regions with scaled stats
  (wolves 65 to 1,000 HP, scorpions 110 to 2,000, a T-Rex 1,750 to 6,700). This is cheap
  content: same model, new tint, new numbers.
- **Behaviours:**
  - Pack animals that surround you.
  - Chargers that run across the field; you dodge them by stepping into gaps or holes.
  - Flyers with ranged or whip attacks, best shot down with ki.
  - Fast bandits.
  - Armed soldiers, ninjas and mechs.
- **Drops:** meat (HP), ki orbs and sometimes capsules.
- **Respawn:** enemies come back when you re-enter an area (confirmed by the user), which
  supports grinding.

**Oto now** (`scripts/enemy.gd`):
- One behaviour: walk at the player, hit for `damage` every 1 s when within 1.3 m.
- Per-enemy `hp`, `damage`, `speed`, `xp`, an optional capsule `drop`, and `model`/`outfit`
  set in the level JSON.
- Spar mode stops at 45% HP.
- No drops besides capsules, no behaviour types and no tiers.
- Enemies already come back on re-entry, because `GameState.travel()` rebuilds the location
  from its JSON. Bosses and story enemies will need a flag so they stay beaten.

## Bosses

LoG II gives each boss one rule that forces a change of tactics. Reuse the *patterns*:

| Pattern | What it forces |
| --- | --- |
| Absorbs ki blasts to heal | Melee |
| Drains your HP to heal on contact | Stay at range |
| Wind-up charge, interrupted by a hit | Timing; punish the tell |
| Hit-and-run, with projectiles you can shoot down | Shoot the shots, chase the gaps |
| Wave that passes through cover | No hiding; guard or out-damage |
| Phases with a heal between, or the fight ends at an HP threshold | Pacing; story beats mid-fight |
| Scripted ending (ring-out, flight sequence, ally takes over) | Story over mechanics |
| Rage state: stats maxed, no ki cost | A power-fantasy finale |

Boss HP ran from about 400 (first) to about 10,200 (optional superboss). Optional bosses
behind gates pay out the most EXP.

**Oto now:** `scripts/life_saiyan.gd` (his health is his power) and the Goku spar
(`spar = true`, which stops at 45%). Both already fit the pattern style. There is no shared
boss kit for phases or thresholds.

## World structure

- **LoG II:**
  - **Hubs:** a city hub plus wilderness regions (mountains, jungle, desert islands,
    towns, a lab, a lookout, a time chamber), all walked top-down.
  - **Flight circles** link regions. **Save circles** save the game and switch the party
    member.
  - **Level gates** are numbered barriers (level 2 up to 50), each tied to one character.
    Some are on the story path; others guard optional areas, grinding spots and trophies.
  - **Obstacles:** breakable rocks, bridges opened by switches, keycard doors.
- **Oto now:**
  - The world map (fly, land at pillars of light, Tab for the overview) does the job of
    flight circles.
  - 10 tile-map locations are linked by exits (`docs/LEVEL_FORMAT.md`).
  - There are no gates, saving, breakable obstacles or switches.

## Quests and collectibles

- **LoG II:**
  - **Journal:** active and completed quests.
  - **Quest types:**
    - Fetch: bring an item, such as 3 fish.
    - Deliver: carry a part or a note.
    - Rescue or escort: lost children, a kidnapped man.
    - Investigate: a spy, a lab.
    - Clear: destroy 3 generators to drop a force field.
  - **Collectible sets:**
    - 25 hidden golden capsules, handed in for a reward.
    - 7 scattered survivors who unlock a destination.
    - 7 story orbs found with a radar item.
    - Trophies behind the top-level gates, which unlock a secret character and ending.
  - **Puzzles** are light: switch combinations, pumps and statues that drain a pond,
    pushing a robot aside, a maze where you follow the herd between hiding holes.
- **Oto now:**
  - NPCs speak lines from the level JSON.
  - `GameState.flags` exists, but there is no quest model, journal, key items or
    collectibles.

## Items

- **LoG II:**
  - Stat capsules (+1, +3, +5).
  - Healing food: meat, plus cookies from a friendly NPC.
  - A full-restore bean that NPCs give out.
  - Key items (cards, keys, the radar, the scouter and its repair part).
  - Quest items.
- **Buu's Fury [BF]:** shops and equipment.
- **Oto now:** gear (`Items.DB`) and +1 capsules. No consumables, key items or shops.

**Consumables (approved by the user on 2026-10-28).** The design document says "comedy is
food", and her appetite is a running thread, so the healing items are meals. The
percentages are starting points for tuning.

| LoG II | Oto | Effect | Where from |
| --- | --- | --- | --- |
| Meat (enemy drop) | Haunch | 25% HP | Dropped by beasts |
| | Rice ball | 15% HP | Dropped by people and soldiers; sold in towns |
| Ki orb | Ki mote | 20% ki | Any defeated enemy may drop one |
| Cookies (unlimited small heal) | Chi-Chi's leftovers | 10% HP, unlimited | The pot in Goku's house |
| Fish (quest item) | Fresh fish | 30% HP | Fishing spots, once Gohan has taught her (a story beat) |
| Senzu bean | Senzu bean (kept: canon, and Korin is in the game) | Full HP and ki | Korin and Yajirobe, rare |
| 25 golden capsules | The Menu: every dish on the planet | Logs signature dishes, one or more per town; milestones raise max HP or give stat points | Restaurants and cooks, with Krillin and Bulma as guides |

## Scouter and information

- **LoG II:** a quest item. Scan anyone to see HP, STR, POW and END plus a short bio. Bosses
  scanned once stay in the database.
- **Buu's Fury [BF]:** the scouter screen also shows the area map and nearby characters.
- **Oto now:** nothing.
- **Decided: ki-sense first, a scouter later.**
  - Early on, Oto's ki-sense gives a rough read: a power band (weaker, even, stronger,
    overwhelming) plus the enemy's HP bar.
  - A scouter arrives later in the story and adds exact numbers. Where and from whom is for
    the design document to decide.
  - Fitting detail: scouters read nothing on Oto herself (the design document's "reversed
    reveal"), so her own power could show as blank once she has one.

## Party

- **LoG II:**
  - Five playable characters (plus one secret) join through the story.
  - Each has their own level, stats, specials and gates.
  - You switch at save circles. One character is only playable briefly before the finale.
- **Oto:** one protagonist by design.
- **Decided: level gates and memory gates.**
  - Numbered level gates work as in LoG II.
  - Memory gates need a recovered Shadow form (`GameState.max_form`) or a memory flag.
  - The ladder rule applies: a memory gate must never open before its rung in the story,
    so play never runs ahead of what Oto remembers.

## Backlog for agents

Ordered by impact on feel per hour of work. Each item names its files and what "done" means.
Check every visual change with `python tools/run.py shot ...` as `CLAUDE.md` says.

### Build status (2026-10-28)

Every item below is built, and `python tools/run.py test` checks its rules.

| # | Item | Left open |
| --- | --- | --- |
| 1 | Damage numbers | Nothing |
| 2 | Food and ki mote drops | Done. Beasts in the four wild areas drop haunches. Senzu beans are carried (Yajirobe), and fresh fish come from fishing jetties |
| 3 | Ki charge tiers | Goku's spar teaches Steady. Focused (ship or Roshi), Deep and Perfect wait for their story scenes |
| 4 | Capsule tiers and caps | Placed capsules use the level `pickups` key |
| 5 | Level and memory gates | One level 5 gate in the Wasteland (a rock pocket with two +3 capsules). No memory gates in real locations yet |
| 6 | Save and load | Save lanterns in every outdoor location. A fall reloads the last save |
| 7 | Enemy behaviours | The Wasteland Saibamen now hunt as a pack. Other behaviours appear only in the test arena |
| 8 | Ki attack list | Charged Orb and Ki Blast. No story techniques yet |
| 9 | Held charged melee | Nothing |
| 10 | Quests and journal | "A Place to Eat" (Paozu) and Roshi's lesson |
| 11 | The Menu | 8 dishes from 7 cooks, enough for every milestone up to 8 dishes. More towns, more dishes |
| 12 | Boss kit | The prologue boss runs on it. The level JSON `boss` key makes simple bosses |
| 13 | Scan | T toggles it. The Scouter key item exists, but nothing gives it yet. No gamepad button |
| 14 | World obstacles | Built as fixtures. So far they appear only in `levels/dev_fixtures.json` |

**Next, in rough order:**
- **Content:** done for the wild areas, dishes, fishing and senzu (see `docs/STATUS.md`).
  Next would be enemy variety per saga, and memory gates and obstacles in real locations.
- **Story:** the scenes that teach the later charge tiers.
- **Controls:** a gamepad button for scan.
- **Systems:** teleport pads, fusion, audio.

The original plan follows.

1. **Floating damage numbers.** A billboard `Label3D` that rises and fades, spawned from
   `Enemy.hurt` and `Player.hurt`. Done when hits in `test_arena` show numbers and screenshots
   are legible from the game camera.
2. **Enemy drops for HP and ki.** Extend `Pickup.KINDS` with `haunch` and `rice_ball`
   (heal) and `ki_mote` (restores ki), using the approved table under Items. Add a drop
   chance to `Enemy`. Done when kills sometimes drop them and the magnet gear still pulls
   them in.
3. **Ki charge tiers.** Replace the flat 15 ki/s in `Player._update_charge` with the tier
   table under Ki charging:
   - A `GameState.charge_tier` (0 = Basic Charge), saved with the game.
   - A delay timer that restarts when Oto moves, attacks, guards or is hit.
   - A rate given as a share of max ki.
   - The tier name in the pause menu, and a toast when a tier is learned.
   - Wiring: `start_power_fantasy()` sets Perfect Charge, `amnesia_reset()` drops her back
     to Basic, and the end of Goku's spar in `paozu.gd` teaches Steady. The later tiers
     arrive with their story scenes. Roshi's optional lesson at Kame House
     (`levels/kame_house.json`) needs the quest system (item 10), so it comes later.
   - Done when a `test_arena` run shows the delay and a faster fill at a higher tier.
4. **Capsule tiers and caps.** Kinds like `red3`/`red5` (+3, +5), a bigger mesh for higher
   tiers, and level JSON `drop` accepting them. Update the `LEVEL_FORMAT.md` enemies row.
   Stop `GameState.add_xp` at level 100, and stop `spend_point` and `add_capsule` at 255
   per stat.
5. **Level and memory gates.**
   - A `level_gate` prop (number on its face, `_block()` while locked) in `Props.DOCS` and
     `Props.make`. It opens when `GameState.level` reaches its number.
   - A `memory_gate` variant that checks `GameState.max_form` or a memory flag. Give it a
     look of its own, in the Shadow forms' language (void, hush, stillness).
   - A gate entry in the level JSON, and a check in the gallery.
   - Done when a gate in one location blocks below its level and opens at it.
6. **Save and load.**
   - Serialize `GameState` (level, xp, stats, capsules, max_form, flags, inventory,
     equipment, current level id and spawn) to `user://save.json`.
   - Save points as an interactable prop, plus Continue on the title screen.
   - When Oto falls, reload the last save (decided). Keep the current respawn wherever
     `no_death` is set, and in scenes without saving.
7. **Enemy behaviours.** A `behavior` key in the level JSON and `Enemy`: `chase` (current),
   `charger` (telegraph, dash, stun on a wall), `shooter` (keeps distance and fires hostile
   `KiShot`s), `pack` (circles before closing in). Add a `tier` tint so one model serves
   several regions.
8. **Ki attack list.**
   - Make the `cycle` action pick from a list of unlocked ki techniques shown on the HUD.
   - Turn the current shot into the "charged orb". Add a basic rapid blast.
   - Draw later techniques from the archetypes above, unlocked by the memory ladder
     (design doc decides which).
9. **Held charged melee.** Holding `attack` past a threshold releases a heavy strike
   (knockback, guard break). LoG II had it; Buu's Fury cut it.
10. **Quests and journal.** A small quest registry (id, title, steps keyed to
    `GameState.flags`) and a Journal page in `scripts/pause_menu.gd`. Add key items to
    the inventory.
11. **The Menu.** The collectible log of dishes from Items.
    - A `menu` list in `GameState`, saved with the game.
    - NPC cooks who serve a dish once, logging it.
    - A Menu page in the pause menu, with milestone rewards.
    - Done when one West City restaurant serves a dish that shows up in the log.
12. **Boss kit.** Shared helpers for HP-threshold phase events, heal-between-phases,
    absorb-ki, drain-on-contact and an interruptible wind-up. Refactor `life_saiyan.gd` onto
    it.
13. **Scan.** An info panel for the enemy nearest to Oto. Ki-sense first: name, power band
    and HP bar. Once she has a scouter, add level and exact HP, STR, POW and END.
14. **World obstacles.** Breakable rocks (melee or ki to clear), floor switches, bridges
    that extend, keycard doors. Each is a prop with state saved in `GameState.flags`.

## Decisions

Answered by the user on 2026-10-28.

| Question | Decision |
| --- | --- |
| Transform gauge | None. Forms drain ki per second, as now |
| Stat growth | 3 points per level, placed by the player, as now |
| Gates | Level gates plus memory gates (a form or memory flag), never ahead of the story |
| Scan | Ki-sense first; a scouter later adds exact numbers |
| Level cap | 100 |
| Death | Reload the last save once saving exists; keep the current respawn until then |
| Consumables | Approved as listed under Items |
| Stat cap | 255 per stat, on what points and capsules add; gear and forms apply on top |
| Ki charging | Stand still to charge up to max; tiers from Basic Charge to Perfect Charge, each with a shorter delay and a faster rate |
| Buttons | Ours to choose. LoG II's button layout doesn't matter |
| Earning charge tiers | Through training: one teacher per tier, as listed under Ki charging. Tier names and numbers approved |
| Master Roshi | An optional side lesson at Kame House that teaches Focused Charge early |

## Still open

- **LoG II fact, low priority:** whether there was any guard.

## Sources

- Cheat Happens mirror of a contemporary LoG II FAQ (controls, HUD, gates, enemy and boss
  stats, items, quests): https://www.cheathappens.com/text/dbzgoku2.zip.txt
- Wikipedia: https://en.wikipedia.org/wiki/Dragon_Ball_Z:_The_Legacy_of_Goku_II and
  https://en.wikipedia.org/wiki/Dragon_Ball_Z:_Buu%27s_Fury
- Kanzenshuu wiki (roster, transformations): https://www.kanzenshuu.com/wiki/Dragon_Ball_Z:_The_Legacy_of_Goku_II
- Almar's Guides (collectibles, trophies): https://almarsguides.com/retro/walkthroughs/GBA/games/DragonBallZTheLegacyofGoku2/
