# THE WEIGHT OF CONTROL — Technical Blueprint v1.0
### UM Game Jam 2026 | Team: [Your Team Name] | Theme: "Losing Control"
> **This document is the single source of truth for all development, delegation, and AI-assisted coding. Do not begin writing code without consulting the relevant section first.**

---

## TABLE OF CONTENTS
1. [Boss AI Decision: The Definitive Answer](#1-boss-ai-decision)
2. [Engine & Tech Stack](#2-engine--tech-stack)
3. [Core Architecture & Node Structure](#3-core-architecture--node-structure)
4. [Task Delegation & 74-Hour Timeline](#4-task-delegation--74-hour-timeline)
5. [Asset & Trigger Checklist](#5-asset--trigger-checklist)
6. [AI Workflow Guide](#6-ai-workflow-guide)
7. [Submission Compliance Checklist](#7-submission-compliance-checklist)

---

## 1. BOSS AI DECISION

**Answer: Strict Positional-FSM. Not fully dynamic, not fully scripted.**

Here is the reasoning. A purely scripted pattern (e.g., "always Dash first, then shoot, then jump") is trivially predictable after one cycle and makes the fight feel like a rhythm game, not an intelligent mirror. A fully dynamic reactive AI is a 2-day programming task — beyond scope.

The solution is a **Strict FSM with one positional check per state transition**. This means:

- The boss has a fixed set of states: `IDLE → TELEGRAPH → ATTACK → COOLDOWN → DECISION`
- At the `DECISION` node, the AI performs **one single check**: *"Is the player to my left, right, or above me?"*
- Based on that check, it selects the **next attack state** from a small weighted table
- Once an attack is chosen, it **executes it to completion** with no interruption

**Why this wins:**
- It requires programming only ONE enemy AI script (~150 lines in GDScript)
- The boss *feels* reactive because it faces the player before attacking, but it is perfectly deterministic and debuggable
- The telegraph phase (a visual wind-up animation / glow before each attack) is what teaches the player to bait the boss — not RNG

**Boss State Machine (Definitive Design):**

```
[IDLE] (1.5s after entering arena)
    → [TELEGRAPH_DASH] if player is on same Y-level (horizontal distance > 200px)
    → [TELEGRAPH_SHOOT] if player is above boss OR hiding behind cover
    → [TELEGRAPH_JUMP] if player is on a platform above boss

[TELEGRAPH_X] (0.8s wind-up, visual glow on the relevant ability orb)
    → [ATTACK_X]

[ATTACK_DASH]   → Boss dashes horizontally at full speed across the arena
[ATTACK_SHOOT]  → Boss fires 3 projectiles in a spread pattern toward player
[ATTACK_JUMP]   → Boss leaps to the player's platform and lands with a shockwave

[COOLDOWN] (1.2s after any attack, boss is vulnerable to environmental baiting)
    → [DECISION]

[DECISION]
    → Read player position
    → If boss has lost an orb, that attack type is removed from the table
    → Select next state → [TELEGRAPH_X]

[STAGGERED] (triggered when a fragile pillar collapses on boss)
    → Play stagger animation (1.5s)
    → Shatter the corresponding ability orb (particle effect)
    → Player absorbs orb (player re-gains that ability)
    → Return to [IDLE]
```

**Phase Progression (How the boss loses abilities):**

| Phase | Boss Has | Player Has | How Player Wins This Phase |
|---|---|---|---|
| Phase 1 | Dash + Shoot + Jump | Walk only | Bait ATTACK_DASH into Fragile Pillar A |
| Phase 2 | Shoot + Jump | Walk + Dash | Absorb Dash orb; use Dash to dodge projectiles and bait ATTACK_SHOOT into Turret Reflector |
| Phase 3 | Jump only | Walk + Dash + Shoot | Absorb Shoot orb; reflect projectile at boss mid-jump to shatter Jump orb |

---

## 2. ENGINE & TECH STACK

### Recommendation: **Godot 4.x (Stable)**

This is not a close call. Here is the objective breakdown:

| Criteria | Godot 4 | Unity | GameMaker |
|---|---|---|---|
| 2D physics for platformer | ✅ Native, excellent | ✅ Good | ✅ Good |
| FSM implementation | ✅ GDScript enums = trivial | ⚠️ Requires boilerplate | ⚠️ Requires boilerplate |
| HTML5/WebGL export | ✅ One-click, works on itch.io | ⚠️ Complex, IL2CPP issues | ✅ Good |
| Desktop export (Win/Mac) | ✅ One-click | ✅ One-click | ✅ One-click |
| 74-hour jam speed | ✅ GDScript is fastest to iterate | ❌ Compile times, slower | ✅ Fast |
| Pixel art rendering | ✅ Import settings easy | ⚠️ Needs configuration | ✅ Native |
| Free, no license issues | ✅ MIT License | ⚠️ Revenue threshold rules | ✅ Free tier available |
| Git-friendly scene format | ✅ Text-based `.tscn` | ❌ Binary `.unity` files = merge hell | ⚠️ Binary |

**Godot wins on 7 of 8 criteria for this specific project.** The text-based `.tscn` format is the deciding factor for a 3-person team using Git — it prevents merge conflicts that would destroy your Saturday night.

### Tech Stack Summary

| Component | Tool |
|---|---|
| Engine | Godot 4.3+ Stable |
| Language | GDScript (primary), no C# needed |
| Version Control | Git + GitHub (private repo) |
| Asset Creation | Aseprite (pixel art), BFXR/sfxr.me (SFX), OpenGameArt (royalty-free music) |
| AI Assets | Stable Diffusion / Midjourney for concept refs; must be disclosed |
| Export Targets | HTML5 (primary for itch.io), Windows .exe (backup) |
| Project Resolution | 320×180 (pixel-art standard, scales to any screen cleanly) |

### Godot Project Settings (Apply These First)

```
Project Settings:
  Display > Window > Size: 320 x 180
  Display > Window > Stretch Mode: canvas_items
  Display > Window > Stretch Aspect: keep
  Rendering > Textures > Default Texture Filter: Nearest  ← CRITICAL for pixel art
```

---

## 3. CORE ARCHITECTURE & NODE STRUCTURE

### 3.1 Global Scene Tree Overview

```
Main (Node)
├── GameManager (AutoLoad Singleton)    ← Global state, ability flags, scene transitions
├── AudioManager (AutoLoad Singleton)   ← All SFX/music calls go through here
│
├── UI (CanvasLayer)
│   ├── AbilityHUD                      ← Shows which abilities player has/lost
│   ├── BossHealthBar (hidden in trials)
│   └── TransitionOverlay               ← Fullscreen fade for scene changes
│
└── [Current Scene]                     ← Swapped via GameManager
    ├── Level_Intro
    ├── Level_Trial1
    ├── Level_Trial2
    ├── Level_Trial3
    └── Level_Boss
```

### 3.2 GameManager (AutoLoad Singleton) — `game_manager.gd`

This is the most important script. It holds ALL cross-scene state. Nothing else should store persistent data.

```gdscript
# game_manager.gd — DATA STRUCTURE (do not code yet, this is the blueprint)

var player_abilities = {
    "dash":      true,   # Set to false when sacrificed at Trial 1 gate
    "projectile": true,   # Set to false when sacrificed at Trial 2 gate
    "jump":      true    # Set to false when sacrificed at Trial 3 gate
}

var current_scene: String = "intro"
var boss_phase: int = 0   # 0=full, 1=lost_dash, 2=lost_shoot, 3=dead

func sacrifice_ability(ability_name: String) -> void:
    player_abilities[ability_name] = false
    # Emit signal so AbilityHUD updates
    emit_signal("ability_sacrificed", ability_name)

func reclaim_ability(ability_name: String) -> void:
    player_abilities[ability_name] = true
    emit_signal("ability_reclaimed", ability_name)

func load_scene(scene_path: String) -> void:
    # Fade out → change scene → fade in
    TransitionOverlay.fade_out()
    await get_tree().create_timer(0.5).timeout
    get_tree().change_scene_to_file(scene_path)
```

### 3.3 Player Controller — `player.gd`

The player script reads from GameManager. It NEVER stores ability state itself.

```
Player (CharacterBody2D)
├── CollisionShape2D
├── AnimatedSprite2D        ← Sprite sheets: idle, run, jump, dash, fall, dead
├── AbilityOrbs (Node2D)    ← Visual glowing orbs attached to player body
│   ├── DashOrb (Sprite2D)
│   ├── ProjectileOrb (Sprite2D)
│   └── JumpOrb (Sprite2D)
├── ProjectileSpawn (Marker2D)
├── GroundCheck (RayCast2D)
└── CoyoteTimer (Timer)     ← 0.1s grace window for jumping off ledge edges
```

**Player State Machine (Simple — only 6 states):**

```
IDLE → RUN → JUMP → FALL → DASH → DEAD

Transitions:
  IDLE: velocity.x == 0 and is_on_floor()
  RUN: abs(velocity.x) > 0 and is_on_floor()
  JUMP: jump input pressed AND GameManager.player_abilities["jump"] == true AND is_on_floor()
  FALL: velocity.y > 0 and NOT is_on_floor()
  DASH: dash input pressed AND GameManager.player_abilities["dash"] == true AND dash_cooldown <= 0
  DEAD: hp <= 0 → restart current scene
```

**Key Constants:**
```
WALK_SPEED = 120
DASH_SPEED = 380
DASH_DURATION = 0.18s
DASH_COOLDOWN = 0.9s
JUMP_VELOCITY = -320
GRAVITY = 900
```

### 3.4 Ability State Manager (Part of Player)

The player checks `GameManager.player_abilities` on every relevant input. No local flags needed.

```gdscript
# Inside player._input(event):
if event.is_action_pressed("jump"):
    if GameManager.player_abilities["jump"] and is_on_floor():
        _do_jump()

if event.is_action_pressed("dash"):
    if GameManager.player_abilities["dash"] and dash_cooldown <= 0:
        _do_dash()

if event.is_action_pressed("shoot"):
    if GameManager.player_abilities["projectile"]:
        _spawn_projectile()
```

### 3.5 Sacrifice Gate — `ability_gate.gd`

A self-contained interactable object placed in each Trial.

```
AbilityGate (Area2D)
├── CollisionShape2D    ← detection zone
├── AnimatedSprite2D    ← "locked gate" animation, "shatter" animation
├── GlowParticles (GPUParticles2D)
└── InteractPrompt (Label) ← "[E] to sacrifice DASH and pass through"
```

```gdscript
# ability_gate.gd — LOGIC BLUEPRINT
@export var ability_to_sacrifice: String  # Set in Inspector: "dash", "projectile", or "jump"

func _on_body_entered(body):
    if body.is_in_group("player"):
        show_prompt()

func _on_interact_pressed():
    if not GameManager.player_abilities[ability_to_sacrifice]:
        # Already sacrificed, just open
        _open_gate()
        return
    _play_sacrifice_cutscene()
    await sacrifice_animation.finished
    GameManager.sacrifice_ability(ability_to_sacrifice)
    _open_gate()
```

### 3.6 Boss FSM — `boss.gd`

The most complex script. Built on a GDScript `enum`.

```
Boss (CharacterBody2D)
├── CollisionShape2D
├── AnimatedSprite2D        ← States: idle, telegraph_dash, attack_dash, telegraph_shoot,
│                               attack_shoot, telegraph_jump, attack_jump, staggered, dead
├── AbilityOrbs (Node2D)
│   ├── DashOrb
│   ├── ShootOrb
│   └── JumpOrb
├── DashHitbox (Area2D)     ← Active only during ATTACK_DASH
├── ShockwaveArea (Area2D)  ← Active only on ATTACK_JUMP landing
├── ProjectileSpawn (Marker2D)
├── DecisionTimer (Timer)   ← 1.2s cooldown between attacks
└── StaggerTimer (Timer)    ← 1.5s stagger duration
```

**Boss Enum States:**
```gdscript
enum BossState {
    IDLE,
    TELEGRAPH_DASH,
    TELEGRAPH_SHOOT,
    TELEGRAPH_JUMP,
    ATTACK_DASH,
    ATTACK_SHOOT,
    ATTACK_JUMP,
    COOLDOWN,
    STAGGERED,
    DEAD
}
```

**Decision Logic (The Core):**
```gdscript
func _make_decision():
    var player_pos = player.global_position
    var boss_pos = global_position
    var dx = player_pos.x - boss_pos.x
    var dy = player_pos.y - boss_pos.y  # negative = player is ABOVE

    var available_attacks = []
    if GameManager.boss_abilities["dash"]:   available_attacks.append("dash")
    if GameManager.boss_abilities["shoot"]:  available_attacks.append("shoot")
    if GameManager.boss_abilities["jump"]:   available_attacks.append("jump")

    # Positional weighting
    var chosen = ""
    if abs(dx) > 200 and "dash" in available_attacks:
        chosen = "dash"         # Far away? Charge.
    elif dy < -80 and "jump" in available_attacks:
        chosen = "jump"         # Player above? Jump to them.
    elif "shoot" in available_attacks:
        chosen = "shoot"        # Default fallback.
    elif available_attacks.size() > 0:
        chosen = available_attacks[0]

    match chosen:
        "dash":  _set_state(BossState.TELEGRAPH_DASH)
        "shoot": _set_state(BossState.TELEGRAPH_SHOOT)
        "jump":  _set_state(BossState.TELEGRAPH_JUMP)
```

### 3.7 Environmental Hazard Objects

These are passive objects — they require minimal scripting.

**FragilePillar — `fragile_pillar.gd`**
```
FragilePillar (StaticBody2D)
├── CollisionShape2D
├── AnimatedSprite2D    ← "intact", "cracking", "destroyed"
├── DestroyZone (Area2D) ← Triggers if Boss DashHitbox enters this area
└── BossStaggerSignal   ← Emits "pillar_collapsed" signal with which ability to shatter
```

```gdscript
# fragile_pillar.gd
@export var shatters_boss_ability: String  # "dash", "shoot", or "jump"

func _on_destroy_zone_body_entered(body):
    if body.is_in_group("boss") and body.current_state == BossState.ATTACK_DASH:
        _play_collapse_animation()
        await anim.finished
        get_tree().call_group("boss", "trigger_stagger", shatters_boss_ability)
        queue_free()
```

### 3.8 Level Transition Logic

Each level scene ends when the player reaches an `ExitTrigger` Area2D.

```gdscript
# exit_trigger.gd
@export var next_scene: String  # e.g., "res://scenes/level_trial2.tscn"

func _on_body_entered(body):
    if body.is_in_group("player"):
        GameManager.load_scene(next_scene)
```

---

## 4. TASK DELEGATION & 74-HOUR TIMELINE

### Team Roles

| Person | Track | Responsibilities |
|---|---|---|
| **You (Lead)** | Track A: Core Systems & Boss | Player controller, GameManager singleton, Boss FSM, Ability Gates, Level glue |
| **Danish** | Track B: Level Design & Environment | All 4 scene layouts (TileMaps), environmental hazards, Trial logic puzzles, colliders |
| **Insyirah** | Track C: Art, Audio & UI | All sprites/animations, SFX, music integration, UI/HUD, particle effects, itch.io page |

### Git Workflow (CRITICAL — Follow This to Avoid Conflicts)

- Track A owns: `scripts/` folder, `autoloads/` folder
- Track B owns: `scenes/levels/` folder, `tilemaps/` folder
- Track C owns: `assets/` folder, `scenes/ui/` folder
- **Merge to `main` only at the checkpoints below** — work on your own branch otherwise

---

### Hour-by-Hour Timeline

#### 🟡 PHASE 1: Foundation (Hours 0–12) — Wed 10PM to Thu 10AM
*Goal: Everyone can run the game and see a player on screen*

| Hour | You (Track A) | Danish (Track B) | Insyirah (Track C) |
|---|---|---|---|
| 0–2 | Create Godot project, set project settings, configure Git repo, push skeleton folders | Clone repo, open project, confirm it runs | Clone repo, set up Aseprite, create 320×180 canvas template |
| 2–5 | Build `player.gd` — walk, jump, gravity. No dash/shoot yet. Player can die and respawn. | Build `level_trial1.tscn` TileMap — rough grey-box layout, no art | Create player spritesheet (idle 2fr, run 4fr, jump 1fr, fall 1fr) — 16×16px |
| 5–8 | Add Dash and Projectile to player. Add `GameManager` with ability flags. Test that disabling flags removes abilities. | Add platforms, vertical sections for Trial 1 chase. Place `ExitTrigger`. | Create `AbilityOrb` sprites (3 colors: cyan=dash, red=projectile, yellow=jump). Design tileset (16×16, 2 tile variants) |
| 8–12 | Build `AbilityGate` script. Test full ability sacrifice flow: sacrifice → gate opens → ability gone. | Polish Trial 1 layout. Add `ShadowClone` placeholder (simple enemy that chases at high speed). | Animate player sprites. Apply tileset to Danish's level. Confirm pixel-art render settings look correct. |

**Phase 1 Checkpoint: Player can walk, jump, dash, shoot. Sacrificing at a gate removes the ability permanently. Trial 1 grey-box is navigable.**

---

#### 🟠 PHASE 2: Levels & Enemies (Hours 12–36) — Thu 10AM to Fri 10AM
*Goal: All 3 Trials are playable grey-boxes with correct mechanics*

| Hour | You (Track A) | Danish (Track B) | Insyirah (Track C) |
|---|---|---|---|
| 12–18 | Build `ShadowClone.gd` — moves toward player at 2× walk speed, dies on contact with walls at speed, resets if player reaches exit. Simple NavAgent or manual chase is fine. | Build `level_trial2.tscn` — stealth puzzle layout. Place pushable blocks, lever triggers, turret placeholders. | Create Shadow Clone sprite (dark mirror of player). Create tileset variants for Trial 2 (more mechanical/sterile look) |
| 18–24 | Build `Turret.gd` (indestructible until crushed by block/lever). Build `PushableBlock.gd`. Build `Lever.gd` that triggers a `CrushZone`. | Build `level_trial3.tscn` — vertical falling maze. Place spike obstacles, wind updraft zones, crumbling floor tiles. | Create Turret sprite + shoot animation. Create pushable block sprite. Begin Sound FX: dash, jump, projectile fire, sacrifice. |
| 24–30 | Build `WindUpdraft.gd` (Area2D that applies upward velocity while player is inside). Build `CrumblingFloor.gd` (activates a 1s countdown timer on contact, then falls). | Connect all 3 Trial scenes to each other via ExitTriggers. Test full linear run-through. | Create Updraft visual (upward particles). Apply art to Trial 2 and 3. Create `AbilityHUD` UI — 3 orb icons that grey out when sacrificed. |
| 30–36 | **Bug fix and playtest window.** Full playthrough from Intro → Trial 1 → 2 → 3. Fix any ability state bugs, collision edge cases. | Playtest all 3 levels. Adjust difficulty — add/remove platforms, tune enemy speed. | Source/compose looping ambient music tracks (1 per level). Integrate audio into `AudioManager`. |

**Phase 2 Checkpoint: Complete playthrough from start to boss entrance is possible. All 3 sacrifices work. Art is applied. Audio plays.**

---

#### 🔴 PHASE 3: Boss & Polish (Hours 36–60) — Fri 10AM to Sat 10AM
*Goal: Boss fight is fully playable and winnable*

| Hour | You (Track A) | Danish (Track B) | Insyirah (Track C) |
|---|---|---|---|
| 36–44 | **Build Boss FSM.** Implement all 5 states (IDLE, 3 TELEGRAPH, 3 ATTACK, COOLDOWN, STAGGERED). Use placeholder rectangle art. Get decision logic working. | Build `level_boss.tscn` arena. Place 3 `FragilePillar` objects at specific X positions (one for each phase). Add `TurretReflector` for Phase 2. | Create Boss spritesheet — 24×24px. Animate: idle (2fr), telegraph glow (3fr), dash attack (2fr), shoot (2fr), jump (3fr), stagger (4fr). |
| 44–52 | Implement all 3 boss phases. Test `pillar_collapse → trigger_stagger → shatter_orb → player_absorbs_orb` loop for each phase. Fix phase transition bugs. | Playtest boss arena. Adjust pillar positions so baiting feels fair but challenging. Add destructible environment visual feedback. | Create boss SFX: telegraph hum, dash whoosh, projectile fire, stagger crash, orb shatter, orb absorb. Create victory particle effect for win state. |
| 52–60 | Build `Win Sequence` — after absorbing all 3 orbs, boss dissolves, environment transforms, credits text appears. Add Game Over / respawn flow. | Final polish pass on all levels — add background parallax layers, atmospheric details. Fix any TileMap gaps. | Create main menu scene. Design itch.io cover art (320×180 key art). Write game description for itch.io page. |

**Phase 3 Checkpoint: Game is fully winnable from start to finish. Boss fight is satisfying.**

---

#### 🟢 PHASE 4: Final Polish & Submission (Hours 60–74) — Sat 10AM to 11:59PM
*No new features. Fix only, submit.*

| Hour | All Tracks |
|---|---|
| 60–66 | Full team playtests. Log bugs. You fix critical bugs. Danish fixes level geometry issues. Insyirah fixes audio/UI bugs. |
| 66–70 | Export HTML5 build. Test in browser (Chrome + Firefox). Export Windows build. Test executable. Fix export-specific bugs (audio context issues in HTML5 are common). |
| 70–72 | Upload to itch.io. Fill in all required page info (game title, description with theme integration, team names, genre, 3+ screenshots, controls). Set visibility to Public. |
| 72–73 | Submit to UM Game Jam 2026 itch.io page. Verify submission confirms. All three team members verify they can see and play the live build. |
| 73–74 | **Sleep. Prepare pitch notes for Sunday.** |

---

## 5. ASSET & TRIGGER CHECKLIST

### 5A. Sprites / Visual Assets

#### Player
- [ ] `player_idle` — 2 frames, 16×16px
- [ ] `player_run` — 4 frames, 16×16px
- [ ] `player_jump` — 1 frame, 16×16px
- [ ] `player_fall` — 1 frame, 16×16px
- [ ] `player_dash` — 2 frames, 16×16px (motion blur effect)
- [ ] `player_shoot` — 1 frame (arm extended)
- [ ] `player_dead` — 2 frames (dissolve)
- [ ] `orb_dash` — 8×8px, cyan glow circle
- [ ] `orb_projectile` — 8×8px, red glow circle
- [ ] `orb_jump` — 8×8px, yellow glow circle
- [ ] `orb_shatter` — 4 frames particle burst

#### Enemies / Boss
- [ ] `shadow_clone_run` — 4 frames, 16×16px (darker palette of player)
- [ ] `boss_idle` — 2 frames, 24×24px
- [ ] `boss_telegraph_dash` — 3 frames (cyan orb pulses)
- [ ] `boss_attack_dash` — 2 frames (blurred motion)
- [ ] `boss_telegraph_shoot` — 3 frames (red orb pulses)
- [ ] `boss_attack_shoot` — 2 frames
- [ ] `boss_telegraph_jump` — 3 frames (yellow orb pulses)
- [ ] `boss_attack_jump` — 3 frames (arc + landing)
- [ ] `boss_staggered` — 4 frames (crack animation)
- [ ] `boss_dead` — 6 frames (dissolve + fragment into 3 orbs)

#### Environment
- [ ] `tileset_trial1` — 16×16px, cracked stone/monochrome (10 tile variants: floor, wall, platform, corner)
- [ ] `tileset_trial2` — 16×16px, mechanical/sterile (10 tile variants)
- [ ] `tileset_trial3` — 16×16px, void/falling (10 tile variants)
- [ ] `tileset_boss` — 16×16px, crystalline/mental architecture
- [ ] `fragile_pillar` — 16×48px, 3 states: intact, cracking, destroyed
- [ ] `ability_gate` — 16×32px, locked + open + shatter states (3 color variants for 3 abilities)
- [ ] `turret` — 16×16px, 2 frames (idle + shoot)
- [ ] `pushable_block` — 16×16px, 1 frame
- [ ] `lever` — 8×16px, 2 states (off/on)
- [ ] `crumbling_floor` — 16×16px, 3 states (intact, cracking, gone)
- [ ] `wind_updraft` — 16×32px, animated upward particles
- [ ] `projectile_player` — 8×4px (small white bullet)
- [ ] `projectile_boss` — 8×8px (dark energy ball, 2 frames)
- [ ] `background_parallax_L1` — 320×180px, dark monochrome (far layer)
- [ ] `background_parallax_L2` — 320×180px, slightly brighter (mid layer)
- [ ] `shockwave_ring` — 32×32px, 4 frames (boss jump landing)

#### UI
- [ ] `hud_orb_active_dash` — 12×12px
- [ ] `hud_orb_active_shoot` — 12×12px
- [ ] `hud_orb_active_jump` — 12×12px
- [ ] `hud_orb_lost` — 12×12px (greyed/cracked version)
- [ ] `boss_hp_bar_fill` — 120×8px
- [ ] `boss_hp_bar_bg` — 120×8px
- [ ] `main_menu_bg` — 320×180px key art
- [ ] `font_pixel` — Any free bitmap/pixel font (recommended: "Press Start 2P" from Google Fonts)

---

### 5B. Audio Assets

#### Sound Effects
- [ ] `sfx_jump` — Short upward whoosh (~150ms)
- [ ] `sfx_land` — Thud (~100ms)
- [ ] `sfx_dash` — Sharp air cut (~200ms)
- [ ] `sfx_shoot` — Small pop/zap (~150ms)
- [ ] `sfx_sacrifice` — Glass shatter + void resonance (~1s)
- [ ] `sfx_gate_open` — Low hum resolving to silence (~800ms)
- [ ] `sfx_orb_absorb` — Rising chime (~600ms)
- [ ] `sfx_boss_telegraph` — Low pulsing hum, loops for 0.8s
- [ ] `sfx_boss_dash` — Heavy whoosh (~300ms)
- [ ] `sfx_boss_shoot` — Dark energy fire (~200ms)
- [ ] `sfx_boss_jump` — Heavy footfall + wind (~500ms)
- [ ] `sfx_boss_stagger` — Impact crash + crystal crack (~800ms)
- [ ] `sfx_pillar_collapse` — Stone rumble + crash (~1.2s)
- [ ] `sfx_player_hurt` — Short grunt
- [ ] `sfx_player_death` — Dissolve/shatter (~800ms)
- [ ] `sfx_win` — Rising harmonic resolution (~2s)
- [ ] `sfx_ui_select` — Soft click

#### Music
- [ ] `bgm_intro` — Ambient, slow pulse, 60-80 BPM, loops
- [ ] `bgm_trial1` — Tense, minor key, slightly frantic
- [ ] `bgm_trial2` — Cold, mechanical, minimal
- [ ] `bgm_trial3` — Falling sensation, low bass drone
- [ ] `bgm_boss` — High intensity, distorted, mirrors intro theme
- [ ] `bgm_victory` — Short sting, 5-10s non-looping

*Recommended free sources: OpenGameArt.org, FreeMusicArchive.org, itch.io free asset packs. Cite all in credits.*

---

### 5C. Collision Triggers & Areas (Godot Area2D / RayCast2D)

- [ ] `PlayerGroundCheck` — RayCast2D, points down, detects floor for jump validity
- [ ] `PlayerHurtbox` — Area2D on player, detects enemy attacks
- [ ] `ShadowCloneDetect` — Area2D on Shadow Clone, chases player when in range
- [ ] `TurretVisionCone` — RayCast2D on Turret, line-of-sight for trial 2
- [ ] `CrushZone` — Area2D triggered by PushableBlock or Lever
- [ ] `WindUpdraftArea` — Area2D, applies constant upward force while player inside
- [ ] `CrumblingFloorTrigger` — Area2D on CrumblingFloor, starts countdown on player touch
- [ ] `AbilityGateZone` — Area2D, shows interact prompt
- [ ] `BossArenaZone` — Area2D, locks exit door and triggers boss music on entry
- [ ] `BossDashHitbox` — Area2D on Boss, active only during ATTACK_DASH, damages player + checks for pillar collision
- [ ] `BossShockwaveArea` — Area2D on Boss, activates on ATTACK_JUMP landing frame
- [ ] `BossProjectile` — Has its own Area2D, destroys self on collision
- [ ] `FragilePillarDestroyZone` — Area2D, detects when Boss body enters at high velocity
- [ ] `OrbAbsorbArea` — Area2D on shattered orb after pillar collapse, player walks through to reclaim
- [ ] `ExitTrigger` (×4) — One at end of each level scene

---

## 6. AI WORKFLOW GUIDE

This section tells you exactly how to prompt Claude, ChatGPT, or Copilot to build each module without wasting tokens or getting hallucinated code.

### The Master Rule
**Always paste the relevant Blueprint section + a concrete task.** Never give an AI a vague command like "make the boss work." Give it the FSM diagram from Section 1 and say "implement this exact FSM."

---

### Prompt Template for Each Module

**Module: Player Controller**
> "You are a Godot 4 GDScript expert. I need a `player.gd` script for a CharacterBody2D. Here are the exact constants: WALK_SPEED=120, DASH_SPEED=380, DASH_DURATION=0.18, DASH_COOLDOWN=0.9, JUMP_VELOCITY=-320, GRAVITY=900. The player has 6 states defined by this enum: [IDLE, RUN, JUMP, FALL, DASH, DEAD]. All ability checks must read from a global `GameManager` singleton that has a dictionary `player_abilities` with keys 'dash', 'projectile', 'jump'. Do not store ability state locally. Implement move_and_slide(), wall-based collision, and a coyote timer of 0.1s. Do not implement shooting yet."

**Module: GameManager Singleton**
> "You are a Godot 4 GDScript expert. Create an AutoLoad singleton script called `game_manager.gd`. It must contain: (1) a dictionary `player_abilities` with keys 'dash', 'projectile', 'jump' all defaulting to true; (2) a `boss_abilities` dictionary with the same keys; (3) a `sacrifice_ability(name)` function that sets the key false and emits a signal `ability_sacrificed(name)`; (4) a `reclaim_ability(name)` function that does the reverse; (5) a `load_scene(path)` function that triggers a fullscreen fade using a CanvasLayer called TransitionOverlay before calling `get_tree().change_scene_to_file(path)`. No other logic."

**Module: Boss FSM**
> "You are a Godot 4 GDScript expert. I need a `boss.gd` script for a CharacterBody2D. Here is the exact FSM I need implemented: [PASTE THE ENTIRE SECTION 3.6 FROM THIS DOCUMENT]. Use a GDScript enum with states: IDLE, TELEGRAPH_DASH, TELEGRAPH_SHOOT, TELEGRAPH_JUMP, ATTACK_DASH, ATTACK_SHOOT, ATTACK_JUMP, COOLDOWN, STAGGERED, DEAD. The decision logic must match the pseudocode in the blueprint exactly. Telegraph states play an animation for 0.8s before transitioning to the attack. Cooldown is 1.2s. The boss has a reference to the Player node called `player`. Do not add any logic not specified in the blueprint."

**Module: Fragile Pillar**
> "You are a Godot 4 GDScript expert. Create a `fragile_pillar.gd` for a StaticBody2D. It has an exported String variable `shatters_boss_ability` that is set in the Inspector. It has an Area2D child called DestroyZone. When a body in group 'boss' enters DestroyZone while the boss's `current_state` equals `BossState.ATTACK_DASH`, play a 'crumble' animation, await its completion, then call `get_tree().call_group('boss', 'trigger_stagger', shatters_boss_ability)`, then call `queue_free()`."

**Module: Ability Gate**
> "You are a Godot 4 GDScript expert. Create `ability_gate.gd` for an Area2D. It has an exported String `ability_to_sacrifice`. When a player body enters the area, show an `InteractPrompt` Label. When the player presses the 'interact' key (E), if `GameManager.player_abilities[ability_to_sacrifice]` is true: play a sacrifice animation, await its completion, call `GameManager.sacrifice_ability(ability_to_sacrifice)`, play a gate-open animation. If the ability is already false (already sacrificed in a replay scenario), skip directly to opening."

**Module: Wind Updraft**
> "You are a Godot 4 GDScript expert. Create `wind_updraft.gd` for an Area2D. While a CharacterBody2D in group 'player' is inside this area, apply a continuous upward velocity of -180 to `player.velocity.y` each physics frame. This should counteract gravity (which is 900) to create a gentle lift, not a rocket. When the player exits the area, stop applying the force."

**Module: Shadow Clone AI (Trial 1)**
> "You are a Godot 4 GDScript expert. Create `shadow_clone.gd` for a CharacterBody2D. This enemy: (1) chases the player at a speed of 250 using simple horizontal direction toward player; (2) applies gravity (900) so it falls; (3) does NOT jump — it can only walk; (4) on contact with the player hurtbox, emits a 'player_hit' signal; (5) if it walks off a ledge, it falls and is destroyed when Y > 1000."

---

### Debugging Prompts
When something breaks, use this template:
> "I am building [module name] in Godot 4 GDScript. Here is the relevant blueprint specification: [paste section]. Here is my current code: [paste code]. Here is the error/unexpected behavior: [describe exactly]. Fix only the specific bug described. Do not refactor unrelated code."

---

## 7. SUBMISSION COMPLIANCE CHECKLIST

Cross-reference against the UM Game Jam 2026 Handbook before submitting.

### Technical
- [ ] Game exports and runs as HTML5 in Chrome and Firefox
- [ ] Windows .exe export also works as backup
- [ ] No crashes during normal playthrough
- [ ] Game loads within 10 seconds on average hardware
- [ ] Controls work with keyboard (define: WASD/Arrow = move, Space = jump, Shift = dash, Z/F = shoot, E = interact)

### itch.io Page (Required)
- [ ] Game Title
- [ ] Brief description
- [ ] Genre listed (Puzzle-Platformer)
- [ ] Team name
- [ ] Names of all team members
- [ ] Comprehensive description explaining "Losing Control" theme integration
- [ ] At least 3 gameplay screenshots (take these from each trial + boss fight)
- [ ] Controls listed
- [ ] AI assets disclosed in description/credits (if any used)
- [ ] External assets credited (music sources, font credits)
- [ ] Platform set to Windows/macOS + HTML5

### Submission Steps
- [ ] itch.io project page set to **Public**
- [ ] Visited UM Game Jam 2026 itch.io page
- [ ] Clicked "Submit Here" and "Join Jam"
- [ ] Selected your project page and submitted **before 11:59 PM, 18 April 2026 GMT+8**
- [ ] Uploaded at least 30 minutes before deadline

### Pitch Prep (Sunday 19 April, PASUM)
- [ ] 4-minute pitch planned (suggest: 30s hook/story → 1min gameplay demo live → 1min trail walkthrough → 1min boss fight demo → 30s closing)
- [ ] At least one team member can demo the game on a laptop without internet dependency (use desktop build)
- [ ] Ready to answer: "How does your game embody the theme?" → Answer: "The mechanic IS the theme. You literally lose control, feel its absence, and earn it back."

---

*Blueprint v1.0 | Generated for UM Game Jam 2026 | Team: [Your Name], Danish, Insyirah*
*Good luck. You have a genuinely great concept. Execute it clean.*
