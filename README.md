# Ember Drift — Game Design Document

**Engine:** SpriteKit (Swift, iOS)
**Target session length:** 5 minutes
**Genre:** Auto-battler / Vampire Survivors-style
**Platform:** iOS (mobile)

---

## 1. Game Concept

You play as a lone ember spirit drifting through a collapsing void. Enemies stream in from all sides in continuous waves. Your character attacks automatically — the only real-time input is movement. Each run lasts exactly 5 minutes, ending with a boss encounter. Between runs, you spend **Ash** (persistent currency) to unlock passive upgrades from the **Ember Tree**.

---

## 2. Core Gameplay Loop

```
Spawn → Enemies approach → Kill enemies → Collect XP orbs
→ Level up → Pick a power-up card → Repeat
→ At 5:00: void surge clears screen → Boss appears
→ Defeat boss → Run ends → Earn Ash → Ember Tree upgrades
→ Start next run
```

---

## 3. Player Actions

| Action | Input |
|---|---|
| Move | Joystick / swipe |
| Pick a power-up | Tap a card (level-up screen) |
| Confirm run end | Tap button on summary screen |

No manual attacking, no aiming, no active abilities.

---

## 4. Difficulty Curve

Spawn rate scales continuously over the 5-minute run. There are no discrete waves — enemy density is driven by elapsed time. Enemies always spawn just outside the camera's visible area relative to the player's current world position.

| Time window | Approx. spawn rate | Enemy types active | Notes |
|---|---|---|---|
| 0:00 – 1:00 | ~2 enemies/sec | Scuttlers only | Slow intro, learning movement |
| 1:00 – 2:00 | ~4 enemies/sec | Scuttlers + Brutes | Brutes introduced |
| 2:00 – 3:00 | ~7 enemies/sec | Both | Small horde bursts begin |
| 3:00 – 4:00 | ~11 enemies/sec | Both | Faster overall movement |
| 4:00 – 4:45 | ~16 enemies/sec | Both | Near-constant screen pressure |
| 4:45 – 5:00 | Spawn stops | — | Void surge clears screen, boss drops in |

**Void surge (at 5:00):** A screen-flash plays, then all active enemy nodes are removed without dropping XP. The boss spawns immediately at the edge of the camera's visible area relative to the player.

---

## 5. Map

There is one map for MVP. It is an endless, tileable surface with no walls or boundaries — the player can walk in any direction indefinitely.

**Tile recycling system:** A fixed 3×3 grid of tile nodes surrounds the player at all times. As the player moves, any tile that exits the visible area is immediately repositioned to the opposite side of the grid. Only 9 tile nodes ever exist at once regardless of how far the player walks, keeping performance flat throughout the run.

For MVP, all 9 tiles share a single repeating texture. Varied environments are a stretch goal.

---

## 6. Playable Character

### Cinder *(only character — MVP)*
**The ember spirit**

| Attribute | Value |
|---|---|
| Attack type | Melee radial burst |
| Attack name | Ember Ring |
| Range | Short — radius ~120px around player |
| Attack rate | Every 1.2 seconds |
| Special trait | Hits ALL enemies in radius simultaneously |
| Scaling strength | Powerful at high density (late run); weak vs lone enemies |
| Base HP | 100 |

**Ember Ring:** Every 1.2s a distance check runs against all active enemies at the player's position. All enemies within 120px take damage. A brief ring-shaped particle effect fires outward as visual feedback. No projectile node is created — pure area query.

Additional characters are a stretch goal and are not expected for MVP. No character select screen is needed until stretch goals are pursued.

---

## 7. Enemies

### Scuttler
Fast, fragile, low damage. Introduced at run start.

| Attribute | Value |
|---|---|
| Movement speed | Fast |
| HP | Low |
| Contact damage | Low |
| Behaviour | Moves directly toward player at all times |

### Brute
Slow, tanky, high damage. Introduced at 1:00.

| Attribute | Value |
|---|---|
| Movement speed | Slow |
| HP | High |
| Contact damage | High |
| Behaviour | Moves directly toward player at all times |

Together, Scuttlers and Brutes create two simultaneous spatial problems: Scuttlers must be kited and area-cleared, Brutes must be respected and avoided.

---

## 8. Boss — Void Colossus

Spawns at 5:00 after the void surge. Has a visible health bar displayed on the HUD.

### Phase 1 (100% → 50% HP)

The Void Colossus behaves as a heavily scaled-up Brute — slow movement, high contact damage, large sprite. No new systems required beyond a health bar. This phase is intentionally straightforward to let the player orient before the difficulty escalates.

### Phase 2 (50% → 0% HP)

At 50% HP a phase transition plays (brief screen flash, boss grows slightly). The Void Colossus gains one special attack: **Void Stomp**.

**Void Stomp:** Every 4 seconds, the boss briefly stops moving and slams the ground. Four shockwave lines fire outward in cardinal directions (up, down, left, right). Each shockwave is a rectangular hitbox node that expands rapidly outward then disappears after ~0.6 seconds. The player must move into the gaps between the four lines to avoid damage. The tell (boss pausing) gives the player roughly 0.5 seconds to react.

The boss continues walking toward the player between stomps. Contact damage remains active throughout both phases.

### Defeating the boss

The run ends when the boss reaches 0 HP. The run summary screen is shown.

---

## 9. XP and Leveling

### Target pacing

The target is **8–10 levels per run**. This gives the player a meaningful power-up choice roughly every 30–40 seconds on average, which feels active without being overwhelming.

### XP curve

The curve is intentionally front-loaded — levels come more frequently early when the screen is sparse, and slow down late when the player is already powerful and the screen is chaotic.

The exact XP-per-level values are to be tuned during week 2 playtesting by adjusting a multiplier. The baseline to test first is:

| Level | Approx. XP required |
|---|---|
| 1 → 2 | 20 |
| 2 → 3 | 35 |
| 3 → 4 | 55 |
| 4 → 5 | 80 |
| 5 → 6 | 110 |
| 6 → 7 | 145 |
| 7 → 8 | 185 |
| 8 → 9 | 230 |
| 9 → 10 | 280 |

XP per enemy kill should be tuned to match the spawn rate curve. A rough starting point: Scuttlers drop 4 XP, Brutes drop 10 XP.

---

## 10. In-Run Power-Ups

Offered as a choice of 3 cards on level-up. Each power-up has a stack cap; once capped it is removed from the draw pool for the rest of that run.

**Kindling burst** is only included in the draw pool when at least one other power-up is still available. If it would be the sole remaining card, it is excluded and pool exhaustion triggers instead.

### Power-up list

| Power-up | Type | Max stacks | Cap behaviour |
|---|---|---|---|
| Scorch | Offensive | 2× | +20% damage per stack. Removed at cap. |
| Afterburn | Offensive | 3× | Each stack adds +5 dmg/sec to the DoT (same 3s duration). |
| Twin flame | Offensive | 1× | Unique — removed immediately after first pick. |
| Eruption | Offensive | 2× | 2nd stack raises kill-proc chance from 25% → 50%. |
| Wider reach | Offensive | 2× | +30% attack radius per stack. |
| Rapid cycle | Offensive | 3× | ×0.75 attack interval per stack (~0.51s at 3 stacks). |
| Ember shell | Defensive | 1× | Unique — one-hit shield, regenerates every 15s. |
| Smoldering | Defensive | 2× | 2nd stack raises regen to 10 HP/sec (not additive). |
| Ashen hide | Defensive | 2× | +15% damage reduction per stack, additive (30% max). |
| Heat sink | Defensive | 3× | +30 max HP per stack (+90 max over a run). |
| Rekindle | Defensive | 1× | Unique — consumed on use (revive at 40% HP), then removed. |
| Draft | Utility | 3× | +20% move speed per stack (73% faster at max). |
| Magnetic pull | Utility | 2× | 1st stack: ×2 orb pull range. 2nd stack: ×3. |
| Kindling burst | Utility | N/A | Grants an immediate bonus level-up choice. Only in pool when other power-ups remain. |
| Ash tithe | Utility | 1× | +50% Ash earned this run. Unique. |
| Overload | Utility | 1× | Next level-up shows 4 cards instead of 3. Unique. |

### Pool exhaustion

Pool exhaustion triggers when every power-up is at cap (and Kindling burst is therefore also excluded). The level-up screen is skipped and an **overflow reward** is applied instantly:

- +15 max HP (and current HP)
- +10% damage multiplier
- A "Max build" notification is shown to the player

All subsequent level-ups in that run also trigger the overflow reward.

---

## 11. Permanent Upgrades (Ember Tree)

Displayed as a flat upgrade list (not a visual node web) for MVP. Purchased between runs with Ash. Stat upgrades are repeatable up to their listed cap, with increasing cost per tier. Unlocks are one-time purchases.

### Stat upgrades (repeatable)

| Upgrade | Effect | Max stacks |
|---|---|---|
| Tempered body | +10 max HP | 5× |
| Hotter core | +8% attack damage | 4× |
| Swift drift | +5% move speed | 3× |
| Ember hoard | +10% Ash earned per run | 5× |
| Stoked | +6% attack speed | 3× |

### Unlocks (one-time)

| Upgrade | Effect |
|---|---|
| Second wind | Rekindle power-up can now appear in level-up pools |
| Volatile start | Each run begins with one random offensive power-up already applied |
| Kindling cache | XP orbs grant 10% more XP |
| Twin offering | Level-up always shows 3 cards (early runs show only 2 by default) |
| Ashen echo | After the boss dies, a 30-second bonus wave begins with extra Ash reward |

---

## 12. Run Data Tracking

All of the following is recorded per run and displayed on the run summary screen:

- Time survived
- Enemies killed (total, and split by type)
- Final level reached
- Power-ups collected (which ones, in order acquired)
- Ash earned

Data is collected passively throughout the run and passed to the summary screen at run end. No external storage needed — run data does not persist beyond the summary screen.

---

## 13. UI Screens

| Screen | Contents |
|---|---|
| Main menu | Start run, Ember Tree, total runs, best score |
| Ember Tree | Flat upgrade list with costs and unlock status |
| In-game HUD | HP bar, XP bar, run timer, boss HP bar (boss phase only) |
| Level-up overlay | 3 power-up cards (pauses the game) |
| Run summary | Time survived, enemies killed, level reached, power-ups collected, Ash earned, "Run Again" button |

---

## 14. Technical Overview (SpriteKit)

| System | Approach |
|---|---|
| Player movement | Joystick delta applied to player node position each tick |
| Auto-attack | Repeating timer triggers attack function |
| Enemies | Object pool (~30 nodes); nodes are recycled rather than destroyed and recreated |
| Enemy movement | Move-toward-player action, target recalculated each tick |
| Collision detection | Physics bitmasks with contact delegate |
| XP orbs | Distance check each tick for magnetic pull; removed on player overlap |
| Map | 3×3 tile grid recycled around player position; 9 tile nodes total |
| Spawn positioning | Always relative to camera edge at player's world position |
| Spawn rate | Single formula driven by elapsed time; no hardcoded breakpoints |
| Boss stomp hitboxes | 4 rectangular nodes expanding outward, removed after ~0.6s |
| Run data | Tracked in a single in-memory struct, passed to summary screen at run end |
| Persistence | Codable struct for Ash balance and Ember Tree state, saved to UserDefaults |
| Camera | Camera node following player |
| Menus | Separate scene per screen |
| Particles | Emitter nodes for attack feedback and death effects |

---

## 15. MVP Scope (5-week plan)

| Week | Goal |
|---|---|
| Week 1 | Player moves on recycled tile map, Scuttler enemy follows and damages player, basic collision |
| Week 2 | XP orbs on kill, level-up system, power-up cards, Brute enemy introduced, HUD |
| Week 3 | Continuous spawn rate scaling, void surge at 5:00, Void Colossus boss (both phases), run summary screen with tracked data |
| Week 4 | Persistent Ash, main menu, Ember Tree flat list with working upgrades |
| Week 5 | Polish pass: sound effects, particle effects, screen shake on boss hit, balance tuning, bug fixing |

---

## 16. Stretch Goals

Only pursue if MVP is completed ahead of schedule.

- Additional playable characters (Vex — ranged; Grit — tank) with character select screen
- 2–3 additional enemy types with distinct movement patterns (circling, dashing)
- Varied map textures or a second map
- Local high score board
- Haptic feedback on level-up
- Ashen echo bonus wave (post-boss content)

---

*Document version 1.2 — subject to revision during development*
