# Brave Legend

[English](./README.md) | [中文](./README_cn.md) | [日本語](./README_jp.md)

A 2D action-platformer prototype built with **Godot 4.7** (Forward+ renderer).  
Beyond the state-machine-driven combat and hurt/death logic, it implements a full surrounding game shell: a title screen, save stones, scene transitions, pause/ending screens, and audio and gamepad support.

## Tech Stack

| Category | Technology | Version | Description |
| :--- | :--- | :--- | :--- |
| **Game Engine** | Godot Engine | 4.7 (Forward+) | Core game development engine |
| **Scripting Language** | GDScript | Built into Godot 4.7 | Engine's native scripting language |
| **2D Physics** | Jolt Physics | Built into Godot (3D physics engine, drives 2D too) | Character movement, collision and physics queries |
| **Tilemap System** | TileMapLayer | Godot 4.x | Level geometry, foreground/background layers |
| **Parallax Background** | Parallax2D | Godot 4.x | Multi-layer scrolling parallax background |
| **Global Singletons** | Autoload | Godot 4.x | Three autoloads — `Game` / `SoundManager` / `Vignette` — manage flow, audio and screen effects |
| **Save Format** | JSON / ConfigFile | Built into Godot | Game-progress save data (`user://data.sav`) and audio settings (`user://config.ini`) |
| **Audio Buses** | AudioServer Bus | `default_bus_layout.tres` | Three independent buses — Master / SFX / BGM — with adjustable, persisted volume |
| **Input Devices** | Keyboard / Gamepad / Touch | Godot InputMap | Keyboard & mouse, gamepad (with vibration feedback), and a touch-screen virtual joystick are all supported |
| **Art Format** | Aseprite | - | Pixel-art source files (`.aseprite`), exported as PNG sprite sheets |
| **Rendering Driver** | Direct3D 12 | Windows | Project's rendering backend (`rendering_device/driver.windows`) |

---

<!--ts-->
* [Brave Legend](#brave-legend)
    * [Tech Stack](#tech-stack)
    * [Getting Started](#getting-started)
    * [Control](#control)
    * [Architecture](#architecture)
        * [State Machine](#state-machine)
        * [HitBox / HurtBox Combat Detection](#hitbox--hurtbox-combat-detection)
        * [Stats System](#stats-system)
        * [Interactable System](#interactable-system)
        * [Global Autoload Singletons](#global-autoload-singletons)
    * [Core Systems](#core-systems)
        * [Player System](#player-system)
        * [Enemy AI System](#enemy-ai-system)
        * [Scene Transition and Save System](#scene-transition-and-save-system)
        * [Camera, Screen Effects and Hit-stop](#camera-screen-effects-and-hit-stop)
        * [Audio System](#audio-system)
        * [UI Flow](#ui-flow)
        * [Input Adaptation](#input-adaptation)
    * [Statement](#statement)
<!--te-->

## Getting Started

1. Clone this project from GitHub
2. Open the project with Godot Engine (Godot >= 4.7 required)
3. Click the Play button (or press F5) to run — it starts from the title screen by default

## Control

| Action | Keyboard | Gamepad | Description |
| ---- | ---- | ---- | ------------------------ |
| Move | `A` / `D` | Left stick / D-pad | Move left / right |
| Jump | `Space` (hold / release) | `A` button (Xbox layout) | Releasing early cuts the jump short (variable jump height) |
| Attack | `J` | `X` button | Pressing again while the attack animation is playing chains into the next combo hit (up to 3 hits) |
| Slide | `K` | Right stick click | Costs energy; cannot be triggered without enough energy or when the ground continues ahead |
| Interact | `E` | `B` button | Interacts with save stones, teleporters and other interactable objects |
| Pause | `Esc` | `Start` button | Opens/closes the pause menu |
| Wall jump | Against a wall + `Space` | Against a wall + `A` button | Triggered while wall-sliding |

> On touch devices a virtual joystick (`UI/virtual_joypad.tscn`) is shown, mapping drag distance to `move_left` / `move_right` input. The on-screen interaction prompt icon (`interaction_icon.gd`) automatically switches between keyboard and gamepad icons based on the most recently used input device.

## Architecture

The project uses a three-layer architecture — **generic state machine + hit/hurt collision boxes + global singletons**: character behavior is driven by the state machine, combat detection is handled by the collision-box system, and cross-scene concerns (saving, audio, flow control) are managed centrally by global singletons.

### State Machine

`Classes/StateMachine.gd` is a generic finite-state-machine node decoupled from any concrete state enum:

- **Contract-driven**: the state machine itself knows nothing about the concrete states. Every physics frame it calls the `owner`'s `get_next_state(state)` to decide whether to transition, then calls `owner.tick_physics(state, delta)` to run the current state's physics behavior
- **Transition hook**: whenever the state changes, `owner.transition_state(from, to)` is called automatically — used to play animations, reset one-shot flags, etc.
- **Resolved in a loop**: `_physics_process` resolves `get_next_state` in a `while true` loop, allowing multiple state transitions within the same frame (e.g. landing and immediately entering an attack)
- **Zero-coupling reuse**: `Player` (`player.gd`) and `enemy` / `boar` (`Enemy/enemy.gd`, `Enemy/boar.gd`) each define their own independent `State` enum, while sharing the exact same `StateMachine` node type

**Core snippet:**
```gdscript
var current_state: int = -1:
    set(v):
        owner.transition_state(current_state, v)
        current_state = v
        state_time = 0

func _physics_process(delta: float) -> void:
    while true:
        var next := owner.get_next_state(current_state) as int
        if next == KEEP_CURRENT:
            break
        current_state = next

    owner.tick_physics(current_state, delta)
    state_time += delta
```

---

### HitBox / HurtBox Combat Detection

A hit-detection system built on `Area2D` signals:

- **HitBox**: attached to an attack's collision shape; on `area_entered` it emits a `hurt` signal on the opposing `HurtBox`, and emits its own `hit` signal as well
- **HurtBox**: only declares the `hurt` signal — the actual damage resolution is handled by the character script's `_on_hurt_box_hurt` callback
- **Physics layer isolation**: `PlayerHurtBox` / `EnemyHurtBox` are kept on separate collision layers so player and enemy hurtboxes never collide with the wrong side
- **Encapsulated damage data**: `Damage` (a `RefCounted`) only carries `amount` and `source`. It is created on the hit frame and consumed/cleared when the state machine transitions into `HURT`, guaranteeing a single hit only ever applies damage once
- **Impact feedback**: the player's `_on_hit_box_hit` callback triggers a brief camera shake and hit-stop the instant it lands a hit on an enemy (see [Camera, Screen Effects and Hit-stop](#camera-screen-effects-and-hit-stop)); transitioning into `HURT` on the receiving end triggers gamepad rumble, camera shake and invincibility frames

---

### Stats System

`Classes/Stats.gd` wraps health and energy into a reusable `Node` component:

- **Property-driven signals**: `health` / `energy` are automatically clamped to `[0, max]` in their setters, and `health_changed` / `energy_changed` are only emitted when the value actually changes — avoiding pointless UI refreshes
- **Automatic energy regeneration**: `_process` continuously restores energy at the `energy_regen` rate, feeding consumable actions such as sliding
- **Serializable**: `to_dict()` / `from_dict()` export/import the current health and max values as a plain dictionary, letting the save system write them straight into JSON
- **Decoupled from character and UI**: `Player`, `Stats` and the UI communicate purely through signals; the status panel never reads a character's internal state directly. The player's `stats` property references the global `Game.player_stats` directly, so health persists across scene transitions

---

### Interactable System

`Classes/Interactable.gd` is a shared base class for interactable scene objects such as save stones and teleporters:

- **Detection-only collider**: `Interactable` sets no `collision_layer`/`collision_mask` of its own; it only listens for `body_entered` / `body_exited` on layer 2 (`Player`)
- **Interaction stack**: entering an `Interactable`'s area calls `player.register_interactable(self)`, pushing it onto the player's `interacting_with` array; leaving calls `unregister_interactable` to remove it. Pressing the interact key runs `interact()` on the last entry (`.back()`), so overlapping interactables naturally favor whichever one was entered most recently
- **Virtual method for extension**: the base `interact()` just logs and emits an `interacted` signal; subclasses call `super()` first, then add their own behavior
- **Concrete implementations**:
  - `Teleporter` (e.g. `Objects/mine_gate.tscn`): `interact()` calls `Game.change_scene(path, {entry_point = entry_point})`, jumping to the target scene and aligning the player to the named `EntryPoint`
  - `save_stone` (`Objects/save_stone.tscn`): `interact()` plays an "activated" animation and calls `Game.save_game()` to write the save file
- **Interaction prompt icon**: the `InteractionIcon` above the player's head (`interaction_icon.gd`) shows or hides based on whether `interacting_with` is empty, and automatically adapts between keyboard and gamepad icons

![Interactable System](./README_Images/SwitchScene.gif)

---

### Global Autoload Singletons

Three autoloads tie cross-scene global state together:

- **`Game`** (`Globals/game.gd`): owns `player_stats` (global health/energy), scene transitions with fade in/out, save/load (JSON serialized to `user://data.sav`), persisted audio settings (`ConfigFile` at `user://config.ini`), and the `camera_should_shake` signal for requesting camera shake
- **`SoundManager`** (`Globals/sound_manager.gd`): centrally manages SFX playback, BGM switching (skipping restarts of an already-playing track), automatic UI sound wiring (recursively walking the node tree to hook up `Button` / `Slider` sounds), and linear-value ↔ decibel conversion for bus volume
- **`Vignette`** (a `CanvasLayer` running `Vignette.gdshader`): sits on top at `layer = 10`, using a shader to darken the screen's edges for atmosphere

## Core Systems

The project currently implements the following core systems:

### Player System

`player.gd`, built on `CharacterBody2D`, is a full action-platformer character controller:

- **State set**: idle, running, jumping, falling, landing, wall-sliding, wall-jumping, 3-hit attack combo, hurt, dying, sliding (start/loop/end)
- **Coyote time**: `coyote_timer` still allows a jump for a short window after leaving the ground
- **Jump buffering**: `jump_request_timer` caches the jump input so an early press still registers right as the character lands
- **Variable jump height**: releasing the jump button while still rising cuts the upward velocity short, giving a "tap for a small hop, hold for a full jump" feel
- **Wall detection and wall jump**: two `RayCast2D`s, `HandChecker` / `FeetChecker`, determine whether the player can wall-slide; wall jumping applies its own velocity vector with a brief input lock
- **Combo attacks**: pressing attack again while the attack animation is playing sets `is_combo_requested`, which decides at animation end whether to advance to the next hit or return to idle
- **Sliding**: costs energy, is time-limited (`SLIDING_DURATION`), and requires the ground ahead to end
- **Hurt and death**: getting hit triggers knockback plus invincibility frames (`invincible_timer`) along with gamepad rumble and camera shake, during which the sprite flickers; once health reaches zero, the death animation plays and a "Game Over" screen appears instead of the scene simply reloading
- **Landing detection**: the height difference between the start and end of a fall (`LANDING_HEIGHT`) decides whether a hard "landing" animation plays or the character transitions straight into running
- **Interact and pause**: pressing interact drives whatever interactable is currently registered (see [Interactable System](#interactable-system)); pressing pause opens the pause menu

![Player System](./README_Images/Action.gif)

### Enemy AI System

`Enemy/enemy.gd` provides the enemy base class, and `Enemy/boar.gd` (the boar) implements concrete AI behavior on top of it:

- **Shared base capabilities**: movement (`move`), facing flip (`direction` drives `graphics.scale.x`), and gravity; `_ready` automatically adds the enemy to the `enemies` group so the save system and level scripts can query it uniformly
- **State set**: idle, patrol walk, chase run, hurt, dying
- **Vision detection**: a `PlayerChekcker` raycast checks whether the player is visible (`can_see_player`); spotting the player switches the enemy into the chase state
- **Environment-aware turning**: `WallChekcker` / `FloorChekcker` detect walls ahead or the edge of a platform and trigger a turn, preventing the enemy from walking off the map or into a wall
- **Calm-down timer**: while chasing, losing sight of the player only reverts the enemy to patrol once `calm_down_timer` expires, avoiding rapid state flip-flopping
- **Hurt and death**: shares the same knockback + damage resolution pattern as the player, but without invincibility frames; on death it emits a `died` signal before `queue_free()`, letting level scripts (e.g. `scene_2.gd`'s `_on_boar_died`) react — for instance, transitioning to the ending screen after a short delay

![Enemy AI System](./README_Images/Attack.gif)

### Scene Transition and Save System

Driven entirely by `Game.gd`:

- **Fade transitions**: `change_scene(path, params)` first pauses the `SceneTree` and fades to black with a `Tween`; after `await`-ing completion, it actually switches the scene, unpauses, and fades back in. The transition tweens use `TWEEN_PAUSE_PROCESS` so they keep playing while the tree is paused
- **Entry-point alignment**: `EntryPoint` markers (`Marker2D` nodes carrying a facing direction) placed in a scene join the `entry_points` group; when changing scenes, the matching node is looked up by name and `World.update_player` places the player at the correct position and facing
- **Per-scene enemy persistence**: before leaving a scene, `World.to_dict()` records the node paths of everything still alive in the `enemies` group into the `world_states` dictionary; re-entering that scene calls `from_dict()`, which removes any enemy not on the alive list — so enemies you've already killed don't respawn
- **Save / load**: `save_game()` serializes `world_states`, `player_stats.to_dict()`, the current scene path, and the player's position/facing into JSON written to `user://data.sav`; `load_game()` reads it back and injects `world_states` and character stats through `change_scene`'s `init` callback
- **New game / back to title**: `new_game()` clears `world_states`, resets character stats, and jumps to `world.tscn`; `back_to_title()` jumps back to the title screen — both reuse the same transition logic

![Scene Transition and Save System](./README_Images/SaveAndLoad.gif)

### Camera, Screen Effects and Hit-stop

- **Camera bounds clamping**: in `_ready`, `world.gd` computes the map's edge coordinates from the `Geometry` layer's `get_used_rect()` and `tile_size`, and assigns them to `Camera2D`'s `limit_*` properties so the camera can never see past the edge of the map
- **Smoothing reset**: `reset_smoothing()` is called manually to avoid a visible camera glide when the game starts or when the player is teleported by a scene transition
- **Multi-layer parallax background**: multiple `Parallax2D` nodes (sky, hills, etc.) are configured with different `scroll_scale` values to produce a near-moves-fast, far-moves-slow parallax scrolling effect
- **Camera shake**: `shakeCamera.gd`, attached to the `Camera2D`, listens for `Game.camera_should_shake` to accumulate shake strength, then decays it every frame at `recovery_speed` while randomly offsetting `offset`; landing a hit (lighter) and getting hit (heavier) each request a different shake strength
- **Hit-stop**: the instant the player's `_on_hit_box_hit` lands a hit, `Engine.time_scale` is dropped to `0.01`, then restored to `1` after a brief delay (using a timer unaffected by `time_scale`), producing a satisfying pause on impact
- **Vignette**: the global `Vignette` singleton sits on the topmost canvas layer, using `Vignette.gdshader` to overlay a gradient darkening around the screen's edges

### Audio System

`Globals/sound_manager.gd` centrally manages three audio buses (`Master` / `SFX` / `BGM`):

- **SFX playback**: `play_sfx(name)` looks up an `AudioStreamPlayer` under the `SFX` container by node name and plays it — used for jumping, attacking, taking damage, UI interactions, and more
- **Deduplicated BGM switching**: `play_bgm(stream)` skips the request outright if the target track is already playing, avoiding needless restarts of the same music
- **Automatic UI sound wiring**: `setup_ui_sound(node)` recursively walks the node tree, wiring press/focus sounds onto every `Button` and value-changed/focus sounds onto every `Slider`, and makes hovering with the mouse grab focus (keeping gamepad/keyboard navigation highlighting in sync)
- **Persisted volume**: volume is passed between the UI and `ConfigFile` as a linear value (0–1), converted internally to/from decibels (the `AudioServer` bus volume) via `db_to_linear` / `linear_to_db`; `Game.save_config` / `load_config` read and write `user://config.ini`

### UI Flow

- **Title screen** (`title_screen.tscn`): enables/disables the "Load Game" button based on whether a save file exists, plays the title BGM, and wires UI sounds onto every button
- **Pause menu** (`pause_screen.tscn`): opens/closes on the `pause` / `ui_cancel` input; its `visibility_changed` signal drives `get_tree().paused` directly, with no extra state syncing needed
- **Game Over screen** (`game_over_screen.tscn`): appears when the player dies; any input (keyboard/mouse/gamepad) continues — loading the save if one exists, or returning to the title screen otherwise
- **Ending screen** (`game_end_screen.tscn`): fades ending text in and out line by line; any input after the last line returns to the title screen
- **Volume slider** (`volume_slider.gd`): bound to a specific `AudioServer` bus, adjusting volume live as it's dragged and immediately writing the change to the config file

### Input Adaptation

- **Multi-device input mapping**: the `[input]` section of `project.godot` configures both a keyboard key and a gamepad button/stick event for every action (move, jump, attack, slide, interact, pause)
- **Adaptive prompt icon**: `Classes/interaction_icon.gd` watches the most recent input event type, switching to the matching gamepad icon animation when it sees a gamepad button press/stick tilt, and back to the keyboard icon animation on keyboard/mouse input
- **Touch-screen virtual joystick**: `UI/virtual_joypad.tscn`, paired with `UI/knob.gd` (extending `TouchScreenButton`), implements a drag-limited virtual joystick whose drag direction is mapped proportionally to simulated `move_left` / `move_right` input
- **Gamepad rumble feedback**: taking damage calls `Input.start_joy_vibration` for a brief rumble, reinforcing the feeling of impact

## Statement

This project is built with **Godot Engine 4.7**, using a generic state machine + hit/hurt collision box + global singleton architecture,  
suitable for learning and prototyping 2D action-platformer games (Metroidvania / ARPG style).

**Regarding art and audio assets:**  
`Assets/Legacy-Fantasy - High Forest 2.3`, `Assets/generic_char_v0.2`, `Assets/gdb-gamepad-2(all)`, and the audio files under `BGM/` and `SFX/` are all third-party assets, used here only for learning and demonstration purposes.  
The `generic_char_v0.2` pack's author contact info is included in its own `readme.TXT` (E-Mail: brullov.ad@gmail.com, Twitter: @brullov_art); its license permits free or commercial use and modification, but prohibits redistribution/resale and use in printed or other physical products.  
All other third-party assets (art, music, sound effects, control-prompt icons) remain the property of their original authors — this repository does not include their license files. Please do not use the third-party assets from this project for commercial purposes or in any way that infringes on the copyright holders' interests; verify licensing and obtain permission from the original authors before any such use.
