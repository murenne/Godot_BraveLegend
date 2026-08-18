# Brave Legend

[English](./README.md) | [中文](./README_cn.md) | [日本語](./README_jp.md)

这是一个基于 **Godot 4.7**（Forward+ 渲染器）开发的 2D 动作平台游戏原型  
除了状态机驱动的战斗与受伤/死亡逻辑外，还完整实现了标题页面、存档点、场景切换、暂停/结算界面、音频与手柄适配等一整套游戏外围系统

## Tech Stack

| 类别 | 技术 | 版本 | 描述 |
| :--- | :--- | :--- | :--- |
| **游戏引擎** | Godot Engine | 4.7（Forward+） | 核心游戏开发引擎 |
| **脚本语言** | GDScript | Godot 4.7 内置 | 引擎原生脚本语言 |
| **2D 物理引擎** | Jolt Physics | Godot 内置（3D 物理引擎，兼容驱动 2D） | 角色移动、碰撞与物理判定 |
| **地图系统** | TileMapLayer | Godot 4.x | 场景地形、前景/背景图层 |
| **视差背景** | Parallax2D | Godot 4.x | 多层视差滚动背景 |
| **全局单例** | Autoload | Godot 4.x | `Game` / `SoundManager` / `Vignette` 三个全局单例，管理流程、音频与画面效果 |
| **存档格式** | JSON / ConfigFile | Godot 内置 | 游戏进度存档（`user://data.sav`）与音频设置（`user://config.ini`） |
| **音频总线** | AudioServer Bus | `default_bus_layout.tres` | Master / SFX / BGM 三条独立总线，音量可调并持久化 |
| **输入设备** | Keyboard / Gamepad / Touch | Godot InputMap | 键鼠、手柄（含震动反馈）与触屏虚拟摇杆均已适配 |
| **美术格式** | Aseprite | - | 像素美术源文件（`.aseprite`），导出为序列帧 PNG |
| **渲染驱动** | Direct3D 12 | Windows | 项目渲染后端（`rendering_device/driver.windows`） |

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

1. 从 GitHub 克隆该项目至本地
2. 使用 Godot Engine 打开项目（确保 Godot 版本 >= 4.7）
3. 点击 Play 按钮（或按 F5）即可运行，默认从标题页面开始

## Control

| 操作 | 键盘 | 手柄 | 功能说明 |
| ---- | ---- | ---- | ------------------------ |
| 移动 | `A` / `D` | 左摇杆 / 方向键 | 左右移动 |
| 跳跃 | `Space`（长按/松开） | `A` 键（Xbox 布局） | 跳跃，松开提前可截断跳跃高度（可变跳跃） |
| 攻击 | `J` | `X` 键 | 攻击，攻击动画播放期间再次按下可触发连段（最多三段） |
| 滑铲 | `K` | 右摇杆按下 | 消耗精力值，精力不足或脚下有地面延伸时无法触发 |
| 交互 | `E` | `B` 键 | 与存档点、传送门等可交互物体互动 |
| 暂停 | `Esc` | `Start` 键 | 打开/关闭暂停菜单 |
| 蹬墙跳 | 靠墙 + `Space` | 靠墙 + `A` 键 | 贴墙下滑状态下触发 |

> 移动端触屏下会显示虚拟摇杆（`UI/virtual_joypad.tscn`），拖拽范围内自动映射为 `move_left` / `move_right` 输入；交互提示图标（`interaction_icon.gd`）会根据最近一次输入设备自动在键盘图标与手柄图标之间切换。

## Architecture

本项目采用**通用状态机 + 碰撞判定框 + 全局单例**的三层架构：角色行为由状态机驱动，战斗判定由碰撞框系统处理，跨场景的存档/音频/流程控制交给全局单例统一管理

### State Machine

`Classes/StateMachine.gd` 是一个与具体状态枚举解耦的通用有限状态机节点：

- **契约式驱动**：状态机本身不知道具体状态是什么，而是在每个物理帧调用 `owner` 的 `get_next_state(state)` 决定是否切换状态，再调用 `owner.tick_physics(state, delta)` 执行当前状态的物理表现
- **切换钩子**：状态变化时自动调用 `owner.transition_state(from, to)`，用于播放动画、重置一次性标记等
- **状态循环解析**：`_physics_process` 中使用 `while true` 循环连续解析 `get_next_state`，允许同一帧内发生多次状态跳转（例如着地瞬间立即进入攻击）
- **零耦合复用**：`Player`（`player.gd`）与 `enemy` / `boar`（`Enemy/enemy.gd`、`Enemy/boar.gd`）各自定义独立的 `State` 枚举，共用同一个 `StateMachine` 节点类型

**核心片段：**
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

基于 `Area2D` 信号实现的攻击判定系统：

- **HitBox**：附加在攻击碰撞形状上，在 `area_entered` 时向对方 `HurtBox` 发出 `hurt` 信号，同时自身也发出 `hit` 信号
- **HurtBox**：只负责声明 `hurt` 信号，具体的伤害结算由角色脚本的 `_on_hurt_box_hurt` 回调处理
- **物理层隔离**：通过 `PlayerHurtBox` / `EnemyHurtBox` 独立碰撞层区分玩家与敌人的受击判定，避免误伤
- **伤害数据封装**：`Damage`（`RefCounted`）仅携带 `amount` 和 `source`，在受击帧生成、在 `HURT` 状态切换时结算并清空，保证同一次判定只造成一次伤害
- **命中反馈联动**：玩家的 `_on_hit_box_hit` 回调在命中敌人瞬间触发短暂的镜头震动与顿帧（详见[相机、画面效果与顿帧](#camera-screen-effects-and-hit-stop)），受击方的 `HURT` 转换会触发手柄震动、镜头震动与无敌帧

---

### Stats System

`Classes/Stats.gd` 将生命值与精力值封装为可复用的 `Node` 组件：

- **属性驱动信号**：`health` / `energy` 通过 `setter` 自动 `clamp` 到 `[0, max]` 区间，数值变化时才发出 `health_changed` / `energy_changed` 信号，避免无意义的 UI 刷新
- **精力自动回复**：`_process` 中按 `energy_regen` 速率持续恢复精力，供滑铲等消耗性动作使用
- **可序列化**：提供 `to_dict()` / `from_dict()`，将当前生命值与上限数据导出/导入为普通字典，供存档系统直接落盘为 JSON
- **角色与 UI 解耦**：`Player` / `Stats` / `UI` 之间通过信号通信，状态面板不直接读取角色内部状态；`Player` 的 `stats` 属性直接引用全局的 `Game.player_stats`，使生命值在跨场景切换时保持不变

---

### Interactable System

`Classes/Interactable.gd` 提供统一的可交互物体基类，供存档点、传送门等场景物体继承：

- **纯检测型碰撞体**：`Interactable` 自身不设置 `collision_layer`/`collision_mask`，只监听第 2 层（`Player`）的 `body_entered` / `body_exited`
- **交互栈**：玩家进入检测范围时会调用 `player.register_interactable(self)`，将自身压入玩家的 `interacting_with` 数组；离开时再 `unregister_interactable` 移除。玩家按下交互键时取数组末位（`.back()`）执行 `interact()`，天然支持多个可交互物体重叠时优先响应最后进入的一个
- **虚方法扩展**：`interact()` 默认只打印日志并发出 `interacted` 信号，子类通过 `super()` 调用父类逻辑后再补充自身行为
- **具体实现**：
  - `Teleporter`（传送门 / `Objects/mine_gate.tscn` 等）：`interact()` 中调用 `Game.change_scene(path, {entry_point = entry_point})`，跳转到目标场景并对齐到指定的 `EntryPoint`
  - `save_stone`（存档点 / `Objects/save_stone.tscn`）：`interact()` 中播放"点亮"动画并调用 `Game.save_game()` 写入存档
- **交互提示图标**：玩家头顶的 `InteractionIcon`（`interaction_icon.gd`）根据 `interacting_with` 是否为空决定是否显示，并自动适配键盘/手柄图标

![Interactable System](./README_Images/SwitchScene.gif)

---

### Global Autoload Singletons

项目通过三个 Autoload 单例串联起跨场景的全局状态：

- **`Game`**（`Globals/game.gd`）：持有 `player_stats`（全局生命值/精力）、场景切换与淡入淡出转场、存档/读档（JSON 序列化到 `user://data.sav`）、音频设置持久化（`ConfigFile` 到 `user://config.ini`）、以及镜头震动请求信号 `camera_should_shake`
- **`SoundManager`**（`Globals/sound_manager.gd`）：统一管理 SFX 播放、BGM 切换（避免重复播放同一曲目）、UI 音效自动绑定（递归遍历节点树为 `Button` / `Slider` 挂接音效），以及音频总线音量的线性值 ↔ 分贝转换
- **`Vignette`**（挂载 `Vignette.gdshader` 的 `CanvasLayer`）：以 `layer = 10` 覆盖在最上层，通过着色器实现屏幕边缘暗角效果，用于烘托氛围

## Core Systems

项目已实现以下核心游戏系统：

### Player System

`player.gd` 基于 `CharacterBody2D` 实现的完整动作平台角色控制器：

- **状态集合**：待机、奔跑、跳跃、下落、着地、贴墙下滑、蹬墙跳、三段攻击、受伤、死亡、滑铲（起始/循环/结束）
- **土狼时间（Coyote Time）**：离开地面后 `coyote_timer` 仍允许短时间内起跳
- **跳跃缓冲**：`jump_request_timer` 缓存跳跃输入，落地瞬间也能响应提前按下的跳跃
- **可变跳跃高度**：松开跳跃键时若上升速度过快会被截断，实现"点按小跳、长按大跳"
- **贴墙检测与蹬墙跳**：通过 `HandChecker` / `FeetChecker` 两条 `RayCast2D` 判断是否可贴墙下滑，蹬墙跳有独立的速度矢量与短暂锁定时间
- **连段攻击**：攻击动画播放期间再次按下攻击键会置位 `is_combo_requested`，动画结束时据此决定进入下一段还是回到待机
- **滑铲**：消耗精力值，限时（`SLIDING_DURATION`）滑动，脚下不能有地面延伸
- **受伤与死亡**：受击后进入击退 + 无敌帧（`invincible_timer`），同时触发手柄震动与镜头震动，无敌期间角色贴图会闪烁；生命值归零后播放死亡动画并弹出"Game Over"界面（而非直接重载场景）
- **落地判定**：根据下落起始高度与结束高度差（`LANDING_HEIGHT`）决定播放硬直的"重着地"动画还是直接接奔跑
- **交互与暂停**：按交互键会驱动当前登记的可交互物体（见 [Interactable System](#interactable-system)），按暂停键弹出暂停菜单

![Player System](./README_Images/Action.gif)

### Enemy AI System

`Enemy/enemy.gd` 提供敌人基类，`Enemy/boar.gd`（野猪）在此基础上实现具体 AI 行为：

- **基类通用能力**：移动（`move`）、朝向翻转（`direction` 触发 `graphics.scale.x` 翻转）、重力下落；`_ready` 中自动加入 `enemies` 分组，供存档系统和场景逻辑统一查询
- **状态集合**：待机、巡逻行走、追击奔跑、受伤、死亡
- **视野检测**：`PlayerChekcker` 射线检测是否能看到玩家（`can_see_player`），发现玩家后切换为追击状态
- **环境感知转向**：`WallChekcker` / `FloorChekcker` 检测前方是否有墙或悬崖，触发转向，避免走出地图或撞墙
- **冷静计时器**：追击状态下丢失玩家视野后，`calm_down_timer` 到期才会回退为巡逻状态，避免频繁切换
- **受伤与死亡**：与玩家共用同一套击退 + 伤害结算模式，但没有无敌帧；死亡时发出 `died` 信号后 `queue_free()`，供关卡脚本（如 `scene_2.gd` 的 `_on_boar_died`）监听并触发后续流程（例如延时后切换到通关结算界面）

![Enemy AI System](./README_Images/Attack.gif)

### Scene Transition and Save System

由 `Game.gd` 统一驱动的场景切换与存档持久化：

- **淡入淡出转场**：`change_scene(path, params)` 先将 `SceneTree` 暂停并用 `Tween` 淡出成黑屏，`await` 完成后再实际切换场景、恢复 `SceneTree`，最后淡入，转场期间的 `Tween` 使用 `TWEEN_PAUSE_PROCESS` 保证暂停时仍能播放
- **入场点对齐**：场景中放置的 `EntryPoint`（`Marker2D`，携带朝向）会加入 `entry_points` 分组；切换场景时按 `entry_point` 名称匹配对应节点，调用 `World.update_player` 把玩家放到正确的位置与朝向
- **按场景保存敌人状态**：切场景前会调用当前 `World.to_dict()`，记录 `enemies` 分组中仍存活的节点路径，缓存进 `world_states` 字典；重新进入该场景时 `from_dict()` 会把不在存活列表里的敌人直接移除，实现"打死的敌人不会刷新回来"
- **存档 / 读档**：`save_game()` 把 `world_states`、`player_stats.to_dict()`、当前场景路径与玩家位置/朝向序列化为 JSON 写入 `user://data.sav`；`load_game()` 读回后通过 `change_scene` 的 `init` 回调注入 `world_states` 与角色属性
- **新游戏 / 返回标题**：`new_game()` 清空 `world_states` 并重置角色属性后跳转到 `world.tscn`；`back_to_title()` 跳转回标题页面，两者都复用同一套转场逻辑

![Scene Transition and Save System](./README_Images/SaveAndLoad.gif)

### Camera, Screen Effects and Hit-stop

- **相机边界限制**：`world.gd` 在 `_ready` 中根据 `Geometry` 图层的 `get_used_rect()` 与 `tile_size` 计算出地图四个方向的边界像素坐标，赋值给 `Camera2D` 的 `limit_*` 属性，防止相机看到地图之外的区域
- **平滑消抖**：手动调用 `reset_smoothing()`，避免游戏开始 / 切换场景传送玩家时相机产生瞬移感
- **多层视差背景**：使用多个 `Parallax2D` 节点（天空、山丘等）配置不同的 `scroll_scale`，实现近大远小的视差滚动效果
- **镜头震动**：`shakeCamera.gd` 挂在 `Camera2D` 上，监听 `Game.camera_should_shake` 信号累加震动强度，再按 `recovery_speed` 逐帧衰减并随机偏移 `offset`；命中敌人（较轻）与自身受击（较重）会请求不同强度的震动
- **顿帧（Hit-stop）**：玩家 `_on_hit_box_hit` 命中敌人瞬间将 `Engine.time_scale` 骤降至 `0.01`，短暂延时后（使用不受 `time_scale` 影响的物理计时器）恢复为 `1`，制造打击瞬间的停顿感
- **暗角效果**：全局 `Vignette` 单例常驻最上层画布，通过 `Vignette.gdshader` 在屏幕四周叠加渐变暗角

### Audio System

`Globals/sound_manager.gd` 统一管理三条音频总线（`Master` / `SFX` / `BGM`）：

- **SFX 播放**：`play_sfx(name)` 按节点名查找 `SFX` 容器下的 `AudioStreamPlayer` 并播放，供跳跃、攻击、受击、UI 交互等场景调用
- **BGM 切换去重**：`play_bgm(stream)` 在目标曲目已在播放时直接跳过，避免同一首 BGM 反复重启
- **UI 音效自动挂载**：`setup_ui_sound(node)` 递归遍历节点树，为 `Button` 自动绑定按下/聚焦音效、为 `Slider` 绑定数值变化/聚焦音效，并统一让鼠标悬停即获得焦点（便于手柄/键盘导航高亮同步）
- **音量持久化**：音量以线性值（0~1）在 UI 与 `ConfigFile` 之间传递，内部与分贝（`AudioServer` 总线音量）之间通过 `db_to_linear` / `linear_to_db` 转换，`Game.save_config` / `load_config` 负责读写 `user://config.ini`

### UI Flow

- **标题页面**（`title_screen.tscn`）：根据是否存在存档动态启用/禁用"读档"按钮，播放标题 BGM，并为所有按钮统一挂载 UI 音效
- **暂停菜单**（`pause_screen.tscn`）：监听 `pause` / `ui_cancel` 输入弹出或关闭，`visibility_changed` 信号直接驱动 `get_tree().paused`，无需额外状态同步
- **Game Over 界面**（`game_over_screen.tscn`）：玩家死亡后弹出，任意输入（键盘/鼠标/手柄）触发继续——有存档则读档重开，无存档则返回标题
- **通关结算界面**（`game_end_screen.tscn`）：逐行淡入淡出播放结局文本，播放完毕后任意输入返回标题
- **设置滑条**（`volume_slider.gd`）：绑定到指定的 `AudioServer` 总线，拖动即实时调整音量并立即写入配置文件

### Input Adaptation

- **多设备输入映射**：`project.godot` 的 `[input]` 段为每个动作（移动、跳跃、攻击、滑铲、交互、暂停）同时配置了键盘按键与手柄按键/摇杆事件
- **自适应操作提示图标**：`Classes/interaction_icon.gd` 监听最近一次输入事件类型，检测到手柄按钮/摇杆偏转时切换为对应手柄图标动画，检测到键鼠输入时切回键盘图标动画
- **触屏虚拟摇杆**：`UI/virtual_joypad.tscn` 配合 `UI/knob.gd`（继承 `TouchScreenButton`）实现拖拽范围限制的虚拟摇杆，拖动方向按比例映射为 `move_left` / `move_right` 的模拟输入值
- **手柄震动反馈**：玩家受伤时调用 `Input.start_joy_vibration` 触发短暂震动，增强打击反馈

## Statement

该项目基于 **Godot Engine 4.7** 开发，采用通用状态机 + 碰撞判定框 + 全局单例的架构，  
适用于 2D 动作平台游戏（Metroidvania / ARPG 类型）的学习与原型开发。

**关于美术、音频资源：**  
项目中 `Assets/Legacy-Fantasy - High Forest 2.3`、`Assets/generic_char_v0.2`、`Assets/gdb-gamepad-2(all)` 以及 `BGM/`、`SFX/` 目录下的音频文件均为第三方资源，仅用于本项目的学习与效果演示。  
其中 `generic_char_v0.2` 资源包作者联系方式见包内 `readme.TXT`（E-Mail: brullov.ad@gmail.com，Twitter: @brullov_art），其许可要求为：可用于免费或商业项目并可修改，但不得重新分发或转售，不得用于印刷品等实体产品。  
其余第三方资源（美术、音乐、音效、按键提示图标）版权归其原作者所有，仓库内未附带对应许可文件，请勿将本项目中的第三方资源用于商业用途或损害版权方利益，如需使用请自行查证并获取原作者授权。
