# ElevenLabs prompts for the blast sounds

> **Status (2026-11-08): generated and integrated.** The 24 recordings (one per bomb + the megaton
> rumble bed, the bunker window rattle, the rocket ignition and the rocket flight roar) were generated
> by the project owner with these prompts and put in `Звуки взрывов/` (local, not in git).
> `tools/process_samples.py` turns them into `assets/audio/samples/`: every blast starts at its main
> hit (the generator put 0.3-9 s of silence or pre-rumble before it), extra explosions appended by the
> generator are cut (Mk 84 after 21.3 s, Trinity after 26.9 s), Trinity starts at its first of two
> dull thuds, RDS-37 and Ivy Mike start at their first report (their louder later blow stays, as a
> focused / multipath arrival), the Ivy Mike take is peak-limited by 6 dB, Castle Bravo loses an explosion appended after 26.5 s. The game adapts
> each recording to the distance, time of day, humidity and bearing (`scripts/audio/blast_samples.gd`,
> `docs/DECISIONS.md` D039-D041).

One sound per bomb, heard outdoors at the bomb's recommended distance (`rec_km`), starting at the moment the blast arrives. The game adds the delay after the flash, the ground tremor, the fall whistle, the rocket, the bunker ambience and the debris/glass layers itself, so the prompts leave those out.

## Settings (Sound Effects, model v3)

| Setting | Value |
|---|---|
| Loop | **Off** (one-shot sounds; the long rumble extra is looped in the game with a crossfade) |
| Duration | **Fixed**, the value given for each bomb (not Auto) |
| Prompt influence | **45 %** or **55 %** as given for each bomb; 35 % if the 4 takes are stiff and identical, 60 % if they drift (whoosh, riser, music, wrong order). Avoid 80 % and above |
| Magic-wand toggle | **Off**. Not documented by ElevenLabs; if it rewrites prompts it would undo the wording |
| Download | **WAV 48 kHz** from History (MP3 smears the sharp front and shifts the onset) |
| Takes | Bombs 1-8: 2 generations each (8 takes); bombs 9-20: 1 generation; regenerate only if none of the 4 takes is usable |

**Order:** generate Mk 82 first and listen; then neighbours back to back (1/2, 3/4, 5/7, 9/10, 17/18, 19/20) so they stay clearly different.

**Picking a take:** the hit within the first ~50 ms with nothing before it (no whoosh, riser, whistle, music, voices); one explosion plus only the reports/echoes the prompt describes; no breaking glass, close debris clatter or dominating wind hiss; for bombs 1-8 also check on laptop/phone speakers and keep the take that stays audible there; bombs 1-13 end quiet, 14-20 may still be rumbling at 30 s.

**Files:** put the kept take of each sound into the project folder `Звуки взрывов/` (ignored by Godot and git), named as `tools/process_samples.py` expects: the bomb's English name (`Mk 82.wav` ... `Tsar Bomba.wav`) and, for the extras, `Длинный раскат для мегатонных бомб.wav`, `Треск окна бункера.wav`, `Зажигание и отрыв от стола.wav`, `Рёв в полёте, для петли.wav`. Do not normalise or compress them: levels are set in the game from the physics targets. Then run `python tools/process_samples.py` and re-import (open the editor or `Godot --headless --path . --import`).

## Prompts

### 01 Mk 82 (`mk82`) — 8 s, influence 45 %

```text
Real outdoor field recording of a single 500-pound bomb set off on the ground at a military range, heard 2 km away. Starts instantly with one loud, sharp, hard crack-boom like a big cannon shot heard across a valley, with a short, thick, solid boom body. Then a few sharp echo claps slap back from the hills one after another, each one darker, fading into a short low rumble and silence. Clean, natural, full-bodied sound.
```
*Basis:* A hard crack-boom (positive phase about 20 ms) followed by separate hill echoes that get darker and are gone by about 8 s, as the Oldebroek witnesses (KNMI 102-31) and the DoD blast-noise bulletin describe, with no hiss.

### 02 Mk 84 (`mk84`) — 10 s, influence 45 %

```text
Real outdoor field recording of a single 2000-pound bomb set off on the ground at a military range, heard 3 km away. Starts instantly with a sharp crack that opens into a heavier, deeper, longer boom with a thick, solid body, and a fainter second thump right behind it. Then rolling echoes return from the surrounding hills and darken into a low rumble that slowly fades to silence. Clean, natural, full-bodied sound.
```
*Basis:* The same sharp onset with a heavier, longer boom, a weaker second impulse (+61 ms, -9.5 dB) and 2-5 s of rolling local echoes (merged.json target, RESEARCH_NOTES 2.2).

### 03 Tallboy (`tallboy`) — 10 s, influence 45 %

```text
Real outdoor field recording of a single huge bomb exploding deep underground, heard 4 km away. Starts instantly with a dull, rounded, heavy whump like a big quarry blast, soft-edged but thick and solid, then a moment later a second, weaker thud as the crater vents. Then a few seconds of low, soft rumble as earth and rock fall back, with low rolling echoes, fading to silence. Clean, natural, full-bodied sound.
```
*Basis:* A muffled buried whump at 133 dB, a separate weaker crater-vent pulse about 0.5 s later (Vortman), and a short low fall-back rumble (col_fall 2.6 s for 4.5 s). The ground jolt about 9.5 s earlier is the game's tremor layer.

### 04 Grand Slam (`grand_slam`) — 12 s, influence 45 %

```text
Real outdoor field recording of a single enormous 10-ton bomb exploding deep underground, heard 5 km away. Starts instantly with a massive, slow, muffled THUD like a giant demolition charge going off inside a hill, heavier and lower than a quarry blast, then a second, weaker and slightly sharper whump as the crater vents. Then several seconds of low rumble as tons of earth fall back, slow echoes dying away. Clean, natural, full-bodied sound.
```
*Basis:* Like Tallboy but heavier and later: a lower whump, a weaker and slightly sharper vent pulse (about -7 dB), and a low fall-back rumble (col_fall 3.0 s for 5.0 s).

### 05 MOAB (`moab`) — 16 s, influence 55 %

```text
Real outdoor field recording of a single massive air-blast bomb exploding just above the ground, heard 8 km away across flat country. Starts instantly with a deep, powerful double boom, two heavy reports almost on top of each other, like a sonic boom with a much deeper, fuller tone. Then a long, deep rolling rumble like distant thunder, swelling once and slowly fading to silence. Clean, natural, full-bodied sound.
```
*Basis:* The 2003 Eglin witnesses on CNN compared it to a much deeper sonic boom that lasted 10-15 s. The target has a second report at +0.23 s and one swell, over flat country with no mountains.

### 06 Davy Crockett (`davy_crockett`) — 14 s, influence 45 %

```text
Real outdoor field recording of a single powerful explosion at a test range in a wide valley ringed by mountains, heard 8 km away. Starts instantly with one clean, deep, heavy boom with a crisp edge and a short, tight low thump, fuller and longer than a cannon shot. Then a smooth, dark rumble rolls back off the surrounding mountains and slowly dies away to silence. Clean, natural, full-bodied sound.
```
*Basis:* Little Feller-type shot: one clean hard boom with only a 0.15 s push and almost no infrasonic shove, then 6-12 s of dark rumble off the Nevada mountains (research A13/R8).

### 07 FOAB (`foab`) — 18 s, influence 55 %

```text
Real outdoor field recording of a single giant thermobaric bomb exploding, heard 10 km away. Starts instantly with a long, heavy, pushing whump-boom with a hard edge and a thick, rounded body, a second heavy boom right behind it, then a sustained low rumbling shudder. Then a long, deep rolling rumble like distant thunder, swelling and fading in two slow waves until silence. Clean, natural, full-bodied sound.
```
*Basis:* Thermobaric whump-boom with a long positive phase (about 0.33 s), a second boom at +0.38 s and 12-18 s of rumble with two swells. Based on physics only; no FOAB eyewitness account exists (low confidence).

### 08 B61-12 (`b61_12`) — 22 s, influence 45 %

```text
Real outdoor field recording of a single very large explosion high in the air, heard 12 km away. Starts instantly with a sharp, loud crack riding on a huge, deep, heavy thump that fills the whole valley, then a softer, duller echo boom about a second later. Then deep thunder-like rumble rolls and swells across the landscape, slowly fading to silence. Clean, natural, full-bodied sound.
```
*Basis:* The heaviest of bombs 1-8 (148 dB, 0.43 s push), with one duller re-arrival 0.5-1.2 s later and a long rumble. No gust: the blast wind is about 1.2 m/s, and the old B61 wind loop was measured as the hiss source.

### 09 Grable (`grable`) — 30 s, influence 45 %

```text
Real outdoor field recording of a single immense explosion in the air above a flat desert basin ringed by bare mountains, heard 20 km away. Starts instantly with a very loud, sharp bang like a thunderclap overhead, then a deep, heavy shudder lasting over a second. Then a long thundering growl echoes back and forth between the bare mountain ranges, slowly fading. Clean, natural, full-bodied sound.
```
*Basis:* Annie observers at News Nob described a sharp bang followed by a long thundering growl (Wellerstein), and at Grable everything shook continuously. Frenchman Flat ringed by ranges; t+ 1.46 s shudder.

### 10 Little Boy (`little_boy`) — 30 s, influence 45 %

```text
Real outdoor field recording of a single immense explosion high in the air, heard 20 km away among green wooded hills near a wide bay. Starts instantly with one tremendous, crisp boom like a giant thunderclap overhead, then a heavy shudder lasting over a second. Then a deep, soft rumble rolls away over the wooded hills and out across the bay, slowly fading. Clean, natural, full-bodied sound.
```
*Basis:* Distant witnesses reported a single tremendous boom (pika-don), crisper in humid air (rise time shortens with humidity in blast_synth.gd), with a softer roll over wooded hills and the bay. History separates it from Grable, its physical twin.

### 11 Trinity (`trinity`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single immense explosion at a test range, heard 25 km away in a wide valley between mountain ranges, in still, cool air. Starts instantly with two deep, dull, soft-edged thuds in quick succession, then a few seconds later one more muffled thud. Then long rolling thunder rumbles back and forth between the ranges, swelling and fading again and again. Clean, natural, full-bodied sound.
```
*Basis:* Morrison at 16 km heard two deep, dull thuds, Greisen heard no sharp crack, and thunder rolled between the ranges. The pre-dawn inversion adds an extra arrival 1.5-6 s later. Deliberately duller than Grable and Little Boy.

### 12 Baker (`baker`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single enormous underwater explosion in a lagoon, heard 8 km away across open water. Starts instantly with a heavy, deep, rounded concussion like a big naval gun fired nearby, then a low rumble. After several seconds a vast, deep, thundering roar builds as an immense mass of water crashes back into the lagoon, rumbling on and slowly easing away. Clean, natural, full-bodied sound.
```
*Basis:* Time (1946) compared the air shock at 16 km to a battleship gun fired close by. The collapsing water column, from about 12 s (Glasstone 1950 4.64), gives a roar lasting tens of seconds. Flat atoll, no terrain echoes; the wave arrives too late to be in the sample.

### 13 Sedan (`sedan`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single gigantic explosion buried deep under a desert basin, heard 12 km away. Starts instantly with a deep, muffled, colossal thud, dull and soft-edged but thick and heavy; a few seconds later a second deep, rolling whump as the ground bursts open. Then a long, low, landslide-like rumble as millions of tons of rock and soil fall back, echoing off far mountains. Clean, natural, full-bodied sound.
```
*Basis:* A muffled buried thud, a separate venting whump when the dome bursts at 3-4 s (col_delay 3.4 s), then a low fall-back rumble of about 11 Mt of earth (RESEARCH_NOTES 2.13). The earlier P wave is the tremor layer.

### 14 Ivy King (`ivy_king`) — 30 s, influence 45 %

```text
Real outdoor field recording of a single immense explosion high in the air, heard 50 km away across open sea. Starts instantly with a sharp, loud, crisp thunderclap like a big gun fired close by, then a long, low, heavy pressure surge of several seconds and a soft, low rush of moving air. Then a long, smooth, deep rumble rolls in from far out at sea, darker and darker, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* Observers at 18 km compared it to a nearby 90 mm gun (DNA 6036F). The 4.6 s push with u about 4.3 m/s is a soft gust, and the roll is a smooth multipath roll over open water.

### 15 B83 (`b83`) — 30 s, influence 45 %

```text
Real outdoor field recording of a single colossal explosion at ground level in a desert basin, heard 55 km away. Starts instantly with one sharp, heavy thunderclap, then a deep, slow pressure surge lasting about five seconds, a heavy low throb. Then long, deep rolling thunder with a few heavy echo thumps returning from distant mountain ranges, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* Never tested, so this is a model. A contact surface burst gives one merged front (Glasstone 3.26-3.29), with a t+ 5.1 s push and no audible wind (u 2.7 m/s), and echo thumps from the game's mountain ranges.

### 16 RDS-37 (`rds37`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single colossal explosion high in the air over a flat, open plain, heard 60 km away. Starts instantly with two sharp thunderclaps close together, a few seconds later another heavy blow as strong as the first, and a long pressure surge with a low, buffeting rush of air. Then a long, many-layered deep rumble rolls across the plain in broken waves, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* A double sharp thunderclap was heard at 35 km, and Goncharov described a second blow focused by the inversion a few seconds later. About 3 min of multiple rumble was heard at about 70 km (VNIIEF 1997). u 5.4 m/s.

### 17 Ivy Mike (`ivy_mike`) — 30 s, influence 45 %

```text
Real outdoor field recording of a single colossal explosion on a distant island, heard 90 km away across open sea. Starts instantly with one sharp, loud report, then an enormous, slow pressure surge lasting about ten seconds, a deep, heavy low throb. Then a long, broken, very deep rumble rolls in over the water, with several separate distant bangs arriving within it, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* Fleet observers reported a sharp report, then a long broken rumble (DNA 6036F). The dawn inversion and megaton multipath give several separate bangs. 10.2 s push with u 3.4 m/s, so no wind words.

### 18 Castle Bravo (`castle_bravo`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single gigantic explosion on a distant reef, heard 100 km away across open sea. Starts instantly with a heavy crack swallowed by a deep, tumbling roar like overlapping avalanches, then a run of heavy bangs, bang, bang, bang, bang. A huge, slow pressure surge throbs on for over ten seconds beneath a very deep rolling rumble, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* The Daigo Fukuryu Maru crew described an avalanche-like roar followed by a run of four bangs. This separates it from Ivy Mike, which has the same 157 dB at a similar range. 11.5 s push.

### 19 Test 219 (`test219`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single gigantic explosion high over snow-covered mountains, heard 120 km away in still, cold air. Starts instantly with a sharp, crisp thunderclap that breaks into a rapid series of further sharp bangs over a few seconds, then a long, deep pressure surge with a low, buffeting rush of air. Then an immense, very low rumble rolls on and on, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* No eyewitness account exists, so this rests on physics: 164 dB, a 15.8 s push, and a night inversion plus multipath beyond 80 km giving a crisp clap that breaks into a run of bangs. Same snowy range as Tsar; u 7.7 m/s gust.

### 20 Tsar Bomba (`tsar`) — 30 s, influence 55 %

```text
Real outdoor field recording of a single gigantic explosion high over snow-covered mountains, heard 150 km away. Starts instantly with one immense, deep, heavy blow, a second heavy blow a moment later, then distant thuds rolling in. An enormous, slow pressure surge with a strong, low, buffeting rush of air goes on for many seconds, beneath the deepest, longest rumble, still rolling at the end. Clean, natural, full-bodied sound.
```
*Basis:* The only distance account describes a remote, indistinct, heavy blow (nuclearweaponarchive). A second high-air blow follows about 1.35 s later (sound_manager crack2). It has the longest push (t+ 20.1 s), and u 7.7 m/s is a real gust, not a hurricane.

## Optional extras

### rumble_tail_mega

*Settings:* 30 s fixed, loop OFF (I crossfade-loop it in the game), prompt influence 50%, WAV 48 kHz, 1 generation; keep the take that is the most even in level with no single loud hit.

```text
Real outdoor field recording of a steady, endless, very deep rolling rumble, like thunder from a gigantic explosion more than 100 km away still rolling in long after the blast: continuous, dark and low, with slow surging waves and soft, faint distant rolls, even in level from start to end. Clean, natural, full-bodied sound.
```
*Use:* Extends bombs 14-20 past the 30 s limit (the real megaton rumble lasted minutes; RDS-37: about 3 min at 70 km). In the game (`scripts/audio/blast_samples.gd`) the 16 s seamless loop cut from this take fades in over 6 s starting 9 s before the recording ends, lasts 30-75 s depending on the yield, is pitched 0.85-1.04 by yield and sits about 9 dB under the recording's rumble.

### bunker_rattle

*Settings:* 3 s fixed, loop OFF, prompt influence 55%, WAV 48 kHz, 1 generation; keep 2 takes that have no breaking or cracking glass.

```text
Close-up recording inside a quiet concrete room: a large window of thick panes in a heavy steel frame and metal ceiling lamps suddenly buzz and rattle in their fittings for about a second, a short, dense, dry rattling chatter that dies away into a few last small rattles, then silence.
```
*Use:* Played on the Bunker bus at blast arrival for bombs below the game's debris threshold of 0.15 psi (1-8, 11, 13), with gain from psi. Real rattle starts at about 125 dB, and these bombs reach 133-153 dB. It is lower for buried shots, whose rattle comes mostly with the tremor (OSMRE). This keeps window and glass words out of the main prompts, so all 20 share one outdoor perspective. Bombs 9, 10, 12 and 14-20 already get the debris layer's window and fitting rattle.

## Rocket launch

The launch pad is about 420 m from the bunker window (`launcher.gd` PAD_POS), and the booster flies for about 10 s. The game plays two sounds on a 3D player that follows the rocket: a one-shot ignition, and a sustained roar that the engine moves, attenuates and fades out at burnout. Neither sample should recede into the distance by itself; the game does that.

### rocket_ignite — 6 s, influence 45 %, loop off

```text
Real outdoor field recording of a large solid-fuel rocket igniting and lifting off from a launch pad 400 m away. Starts instantly with a hard, deep ignition thump, then within a second a fierce roar builds into a violent, crackling, tearing rumble full of sharp pops and snaps over a heavy, ground-shaking low end, holding steady and strong to the end. Clean, natural, full-bodied sound.
```
*Basis:* a solid motor starts with an ignition overpressure thump (about 60 ms positive, 120 ms negative), and its noise is a low-frequency roar with crackle (skewed shocklets) (RESEARCH_NOTES 7, DECISIONS D035). The sample ends at full roar so that it hands over to the loop.

### rocket_loop — 10 s, influence 45 %, loop off (made seamless in the game with a crossfade)

```text
Real outdoor field recording of the sustained roar of a large solid-fuel rocket in powered flight a few hundred metres away: a continuous, violent, crackling, ripping rumble with irregular sharp pops and snaps over a deep, heavy low end, even and unchanging in level and character from start to end. Clean, natural, full-bodied sound.
```
*Basis:* the same roar with no start and no end, so that it can loop for the whole flight.

**Picking a take:** no music, voices, countdown, sirens or jet-airliner whine. The ignition take should start with the thump and keep the roar steady to the end, with no fade-out and no fly-away. The loop take should keep an even level, with no swells or bangs. Files: `Зажигание и отрыв от стола.wav` and `Рёв в полёте, для петли.wav` in `Звуки взрывов/` (see Files above).

## If a result is refused or wrong

- If a prompt is refused, replace the weapon noun ('500-pound bomb', '2000-pound bomb', '10-ton bomb', 'air-blast bomb', 'thermobaric bomb') with 'explosive charge' of the same size, and 'military range' with 'test range'. Keep everything else. The main prompts already avoid 'nuclear', yields and place names.
- If bombs 9-20 sound too small (like a firework or a quarry blast): A/B test on Grable by changing 'a single immense explosion' to 'a single immense nuclear test explosion'. If that sounds bigger without becoming cinematic, make the same swap in 9-20 (check that the text stays within 450 characters).
- Cinematic or designed result (riser, whoosh, sub-drop, trailer hit, music): pick another take, raise prompt influence to 60% and regenerate. If it persists, replace 'immense/colossal/gigantic' with 'very large'.
- Hiss or wind noise dominating 14, 16, 19 or 20: delete the rush-of-air phrase (for example ', and a soft, low rush of moving air' or ' with a low, buffeting rush of air'). The game's infra layer carries the push.
- Bombs 1-8 still weak on laptop or phone speakers: replace 'deep' with 'full' and add 'with a strong mid-range body'. Keep the take that loses the least loudness between headphones and the laptop.
- Literal gunshots, gun mechanics or a battle barrage (1, 6, 12, 14): replace the cannon or gun simile with 'like a heavy thunderclap'.
- MOAB with a jet engine or flyby: replace 'like a sonic boom with a much deeper, fuller tone' with 'like a very deep, close thunderclap'.
- Castle Bravo with a literal snow slide or a hissing roar: replace 'like overlapping avalanches' with 'like many thunderclaps overlapping'.
- Ambience baked in (surf or waves in 12, 14, 17, 18; birds or insects in 10; wind or ice in 19, 20): change 'across open sea' or 'across open water' to 'across flat open country', 'among green wooded hills near a wide bay' to 'among low hills', and drop 'snow-covered'.
- Events missing or in the wrong order (second report in 2, 3, 4, 5, 7, 8, 13, 20; late thud in 11; water roar in 12; extra bangs in 16-19): raise influence to 60% and generate again. If it still fails, send the best take and I will layer the missing report from another take.
- Sounds too faint or far away: add 'still very loud despite the distance' after the distance phrase (check the 450-character limit).
- Seismic rumble or a falling whistle before the hit, or a take that starts late: reject it. The game plays those layers itself, and pre-roll silence I trim anyway.
- Extra boom at the end or an abrupt cut: I fade the last 1-3 s. If it happens in all takes, regenerate with the duration 2 s shorter.
- Clipping or distortion in a take: reject it. Do not normalise or compress before sending; I set the levels from the physics targets.

