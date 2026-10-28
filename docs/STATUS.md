# Legacy of Oto: build status

Open the folder in Godot 4.7.2 and press F5. Title screen: Begin: Prologue, Explore: World Map,
Test Arena, Prop and Outfit Gallery.

## Story content

- **Prologue:** Oto at level 60 with every Shadow form against the life-energy Saiyan (whose
  health is his power), the "burning yourself down" exchange, then the wordless Yamoshi light,
  the throw, forms stripped one by one, and the wake-up card.
- **Mt. Paozu (story scene):** the crater, Goku with Gohan on his shoulders, Chi-Chi's stray
  speech and blanket, fishing with Gohan, chopsticks with Chi-Chi, first spar with Goku.

## World

- **World map:** a 3 km continent generated from `levels/world.json` (seeded noise, biomes,
  9,000 low-detail trees, clouds, city silhouettes). Fly with the arrow keys, hold X to boost,
  press E near a pillar of light to land, Tab for the map overlay.
- **Locations** (tile maps in `levels/`): West City with the Capsule Corp campus, shops and
  hover cars; Capsule Corp laboratory (gravity machine, Bulma, Dr. Brief); Hercule City with
  Champion Plaza, the gold statue, the mansion and a dojo stage; Hercule's mansion hall;
  Mt. Paozu with Goku's house; Goku's house interior; Kame House island; the Wasteland
  (Saiyan pods, six Saibamen); Korin's Holy Land; Kami's Lookout. Doors and road ends link
  them to each other and to the world map.

## Art kit

- **Props:** 69 procedural props (nature, village, city, landmarks, interiors) with generated
  textures (windows, bricks, planks, tiles, roof tiles, rock strata). See the gallery.
- **Characters:** 22 outfit presets with hair, clothes and accessories fitted to measured body
  landmarks: Oto, Chi-Chi, Gohan, Bulma, Krillin, Yamcha, Tien, Piccolo, Kami, Vegeta, Raditz,
  Nappa, Hercule, Master Roshi, the life-energy Saiyan, Saiyan soldier, scientist,
  shopkeeper and four civilians. Oto's hair turns black in Shadow forms and grows past her
  knees in Shadow Saiyan 3.
- **Skies:** day, dusk, starry night, dark side, wasteland, Namek, high sky, interior.

## Systems

- **Combat:** 3-hit combo plus a held heavy strike, guard, barrier, and two ki techniques
  (Charged Orb, Ki Blast; Q switches). Floating damage numbers.
- **Ki:** standing ki charge in five tiers, from Basic to Perfect Charge (taught by Goku's
  spar now; Roshi's side lesson; later story teachers). Shadow forms 1-3 drain ki.
- **Growth:** EXP and levels (capped at 100), 3 stat points a level (each stat capped at
  255), capsules worth +1, +3 and +5, gear including weighted training items.
- **Enemies:** chase, charger, shooter and pack behaviours, tiers 1-4, and food, ki mote and
  capsule drops. Enemies collide with walls. A `BossKit` provides phases, ki absorption and
  drain; the prologue boss runs on it.
- **World:** level gates, memory gates, key doors, switches, bridges, breakable rocks, placed
  capsules, save lanterns in every outdoor location, and Chi-Chi's leftovers pot.
- **Wildlife:**
  - Mt. Paozu: wolves, boars and raptors.
  - Korin's Holy Land: tier-2 wolves, boars and raptors.
  - The Wasteland: scorpions and pterodactyls, plus tier-2 scorpions behind the level gate.
  - Kame House: crabs on the beaches.
  - All six are procedural models (`scripts/characters/beast.gd`, gallery page "beasts").
    They wander until Oto comes near, and most drop haunches.
- **Food:** 8 dishes from 7 cooks (West City noodles and bakery, Chi-Chi, Krillin, Bulma's
  cookies, a Hercule City hot dog stand, Hercule's buffet, Yajirobe's rice). There are
  fishing jetties at Mt. Paozu (two), Kame House and Korin's. Gohan teaches fishing in the
  Mt. Paozu location if the story has not. Yajirobe hands out one senzu bean at a time,
  eaten from the Journal page.
- **Saving:** save at lanterns, Continue on the title, and a fall reloads the last save.
- **Menus:** the pause menu has Stats, Equipment, Journal (quests and key items) and Menu
  (dishes eaten) tabs. T opens the scan panel: ki sense, or the scouter with exact numbers.
- **Other:** dialogue, wall collision in locations.

## Gaps to fill

- **Rigging and animation (biggest gap):** models are static T/A-poses. Send the Mixamo FBX
  files (`mixamo_upload/` zips) and real animations replace the procedural bob and lean.
  Clothing then needs re-parenting to bones.
- **Clothing is primitive-based:** low-poly shells and cones. It reads well from the game
  camera; up close it is blocky.
- **Credits:** licences for the two base meshes and the Goku page link (`CREDITS.md`).
- **Audio:** none yet.
- **Story beyond the prologue:** the locations are explorable sandboxes; the Saiyan Saga
  story scripting is next.
- **Content still thin:** Focused, Deep and Perfect Charge wait for their story scenes
  (Roshi's lesson teaches Focused early). There are no memory gates in real locations, and
  the switches, bridges and key doors appear only in the dev room. Scan has no gamepad
  button.
- **Not built yet:** teleport pads, fusion, multi-lock specials.

## For agents

Read `HANDOFF.txt` and `CLAUDE.md` first. `docs/LEVEL_FORMAT.md` documents the level files.
The game is on GitHub (tokentrevor-gitouttahere/Legacy-Of-Oto) and plays in a browser at
https://tokentrevor-gitouttahere.github.io/Legacy-Of-Oto/ (deploy with `python tools/publish_web.py`).
`docs/MECHANICS_REFERENCE.md` compares our systems with Legacy of Goku II and holds the
ordered gameplay backlog. `python tools/run.py test` runs the headless rule checks
(`scripts/tools/dev_tests.gd`); keep them passing and add one for each new rule.
