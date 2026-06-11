# 角色攻击模块设计

## 1. 目标

- 为玩家角色接入基础攻击模块，支持鼠标左键和 `J` 键触发攻击。
- 接入资源化招式数据，避免把伤害帧、位移帧、体力消耗等数值散落在代码中。
- 保持现有 `Character`、`PlayerController`、`StateMachine`、`GroundState`、`AirState`、`DashState` 分层不被打散。
- 支持首批攻击派生：地面普攻 1/2/3、冲刺攻击、空中攻击。
- 为后续补动画资源、扩更多招式、增加受击与击退系统预留边界。

## 2. 现状评估

当前项目已经具备以下基础：

- [player_controller.gd](file:///E:/myproject/battle/script/character/player_controller.gd) 负责采集玩家输入，并将跳跃、冲刺输入分发给能力脚本。
- [state_machine.gd](file:///E:/myproject/battle/script/state/state_machine.gd) 负责驱动状态切换，并已经预留了攻击子状态枚举 `Core.AttackPhase`。
- [ground_state.gd](file:///E:/myproject/battle/script/state/ground_state.gd)、[air_state.gd](file:///E:/myproject/battle/script/state/air_state.gd)、[dash_state.gd](file:///E:/myproject/battle/script/state/dash_state.gd) 已经明确了地面、空中、冲刺三种入口状态。
- [character.gd](file:///E:/myproject/battle/script/character/character.gd) 持有角色数据、动画播放器、状态机与移动组件引用，适合作为攻击系统的宿主门面。
- [c001.tres](file:///E:/myproject/battle/asset/animation/c001.tres) 已有基础动画资源，可用于首批攻击动画重命名和占位映射。

当前缺少的部分主要有：

- 没有攻击输入能力层，攻击按键还未被统一采集。
- 没有 `AttackState`，攻击执行逻辑无处安放。
- 没有资源化的招式定义，伤害帧、位移帧、体力消耗、判定盒等数据尚无统一结构。
- 没有伤害盒节点和命中结算入口。
- 没有连段和派生的统一编排逻辑。

## 3. 方案对比

本次评估三种方案：

- 纯代码写死：所有招式参数、连段窗口和动画名直接写在 `AttackState`。
- 资源化招式 + 代码编排派生：招式本体数据进资源，派生和连段规则仍由代码控制。
- 全资源化攻击树：招式数据和派生关系都做成资源。

本次采用 **资源化招式 + 代码编排派生**，原因如下：

- 符合当前需求，招式数值可以独立配置，满足 `m_c001_a001` 这类命名约定。
- 代码只负责“何时接下一招”和“从哪个状态进入哪种攻击”，逻辑更清晰。
- 比全资源化攻击树更轻量，适合当前项目阶段。
- 后续补动画资源时，只需要改资源或动画名映射，不需要反复改主流程。

## 4. 总体架构

### 4.1 AttackAbility

新增 `AttackAbility`，职责如下：

- 采集鼠标左键和 `J` 键攻击输入。
- 记录“本帧是否触发攻击按下”。
- 向状态层提供统一查询接口，例如 `consume_attack_pressed()`。

`AttackAbility` 不负责：

- 决定当前该播哪一招。
- 结算伤害。
- 推进攻击帧。

### 4.2 AttackState

新增 `AttackState`，职责如下：

- 根据当前入口状态选择招式。
- 播放攻击动画。
- 推进攻击帧计数。
- 根据帧数据处理位移、伤害盒开关、攻击阶段同步。
- 处理攻击输入缓存和连段衔接。
- 在攻击结束后回到 `GroundState` 或 `AirState`。

`AttackState` 不负责：

- 采集按键。
- 保存角色固定配置数据。

### 4.3 MoveData

新增单招式资源 `MoveData`，每个招式一个资源文件，用于保存：

- 动画名。
- 总帧数。
- 伤害倍率。
- 体力消耗。
- 伤害帧段。
- 位移帧段。
- 伤害盒位置和尺寸。
- 是否允许在出招期或后摇期缓存下一招。

### 4.4 CharacterAttackSet

新增角色攻击配置资源 `CharacterAttackSet`，职责如下：

- 汇总该角色有哪些攻击招式。
- 提供地面连段、冲刺攻击、空中攻击等入口资源。

这样可以避免在代码中硬编码某个角色的攻击资源路径。

## 5. 数据结构设计

### 5.1 MoveData

建议新增 [move_data.gd](file:///E:/myproject/battle/script/data/move_data.gd)，字段如下：

- `move_id: String`
  - 招式 ID，例如 `a001`
- `move_name: String`
  - 招式名，例如“平地轻击 1”
- `animation_name: StringName`
  - 对应动画名，例如 `ground_combo_1`
- `damage_multiplier: float`
  - 最终伤害 = `character.data.attack * damage_multiplier`
- `stamina_cost: float`
  - 释放该招式时扣除的体力
- `total_frames: int`
  - 该招式的总帧数
- `startup_frame_range: FrameRangeData`
  - 前摇帧范围
- `active_frame_ranges: Array[FrameRangeData]`
  - 出招帧范围，允许多段
- `recovery_frame_range: FrameRangeData`
  - 后摇帧范围
- `movement_segments: Array[MovementSegmentData]`
  - 位移段，允许多段
- `hitbox_offset: Vector2`
  - 伤害盒偏移，默认位于角色身前
- `hitbox_size: Vector2`
  - 伤害盒尺寸
- `can_queue_next_in_active: bool`
  - 出招阶段是否允许缓存下一招
- `can_queue_next_in_recovery: bool`
  - 后摇阶段是否允许缓存下一招

### 5.2 FrameRangeData

建议新增 `frame_range_data.gd`，只描述一个帧区间：

- `start_frame: int`
- `end_frame: int`

说明：

- 初版不使用字符串 `"2-5"` 保存帧段。
- 统一使用显式起止帧，避免运行时解析字符串。

### 5.3 MovementSegmentData

建议新增 `movement_segment_data.gd`，字段如下：

- `start_frame: int`
- `end_frame: int`
- `distance: float`

说明：

- 每一段位移在自己的帧区间内按帧平滑推进。
- 初版只影响水平位移，不参与高度系统。

### 5.4 CharacterAttackSet

建议新增 `character_attack_set.gd`，字段如下：

- `ground_combo_moves: Array[MoveData]`
  - 地面普攻链，例如 1、2、3 段
- `dash_attack_move: MoveData`
  - 冲刺攻击
- `air_attack_move: MoveData`
  - 空中攻击

后续若要扩展蓄力攻击、上挑、下劈、投技等，可继续在该资源中增加字段。

## 6. 命名约定

### 6.1 招式资源命名

采用资源命名约定：

- `m_c001_a001`
- `m_c001_a002`
- `m_c001_a003`
- `m_c001_dash_a001`
- `m_c001_air_a001`

其中：

- `c001` 表示角色编号。
- `a001` 表示普通招式编号。
- `dash` 和 `air` 表示特殊入口类型。

### 6.2 动画命名

动画名统一改为语义化命名：

- `attack001` -> `ground_combo_1`
- `attack002` -> `ground_combo_2`

后续新增动画建议按以下命名：

- `ground_combo_3`
- `dash_attack`
- `air_attack`

首批缺失资源可先做占位映射，但主流程统一使用语义化动画名。

## 7. 场景与节点设计

### 7.1 角色场景新增节点

在 [c001.tscn](file:///E:/myproject/battle/tscn/character/c001.tscn) 中建议新增：

- `PlayerController/AttackAbility`
- `StateMachine/AttackState`
- `AttackHitbox`
- `AttackHitbox/CollisionShape2D`

### 7.2 AttackHitbox

`AttackHitbox` 采用 `Area2D`，初版只做固定前方矩形盒。

节点职责：

- 根据当前招式和角色朝向更新位置。
- 在伤害帧内激活，在非伤害帧关闭。
- 收集进入伤害盒的对象，交给攻击状态做伤害结算。

初版设计约束：

- 伤害盒默认位于角色身前。
- 初版不根据每一帧切换不同盒形。
- 初版只做简单矩形判定，不做复杂多边形盒。

## 8. 运行时上下文设计

`AttackState` 需要维护一份运行时攻击上下文，建议包含：

- `current_move: MoveData`
- `current_move_frame: int`
- `current_combo_index: int`
- `queued_next_attack: bool`
- `queued_next_move: MoveData`
- `attack_variant: StringName`
  - 例如 `ground`、`dash`、`air`
- `active_hit_window_index: int`
- `already_hit_targets: Dictionary`

作用如下：

- `current_move` 和 `current_move_frame` 用于推进当前招式。
- `queued_next_attack` 和 `queued_next_move` 用于连段缓存。
- `attack_variant` 用于记录这次攻击入口来自哪里。
- `already_hit_targets` 用于避免同一伤害窗内重复命中同一目标。

## 9. 攻击输入设计

### 9.1 输入来源

支持以下两种触发方式：

- 鼠标左键
- `J` 键

### 9.2 输入处理方式

`PlayerController` 在每个物理帧继续负责分发输入：

- `jump_ability.capture_input()`
- `dash_ability.capture_input()`
- `attack_ability.capture_input()`

攻击输入处理原则：

- 输入采集在能力层。
- 输入消费在状态层。
- `AttackState` 不直接读 `Input`，避免状态层依赖输入系统细节。

## 10. 进入攻击状态条件

### 10.1 允许发起攻击的入口条件

本次按你的要求，允许角色在以下条件下进入攻击流程：

- 入口状态允许：
  - 地面
  - 冲刺
  - 空中
- 行为状态允许：
  - `idle`
  - `attack`
  - `pickup`
  - `dash`
- 攻击子状态允许：
  - `RECOVERY`

结合当前项目已有状态结构，落地规则明确如下：

- 从 `GroundState` 可直接进入攻击。
- 从 `DashState` 可直接进入攻击。
- 从 `AirState` 可直接进入攻击。
- 若当前已经在 `AttackState`，则只有当攻击子状态为 `RECOVERY` 时，才允许接收新的攻击输入并切入下一招。
- `pickup` 行为允许被攻击打断时，才可转入攻击；若后续拾取逻辑改为不可打断，应同步收紧该入口。

说明：

- 当前项目里的 `dash` 实际属于行为状态而不是环境状态。
- 为了贴合你的表达与现有代码结构，本设计在实现时以“允许从 `GroundState` / `DashState` / `AirState` 发起攻击”为准。
- 当外层查询条件时，可同时参考环境状态、行为状态和攻击子状态，但最终真正的入口控制仍由各状态脚本与 `AttackState` 共同决定。

## 11. AttackState 执行流程

### 11.1 进入攻击状态

`AttackState.enter()` 执行以下步骤：

1. 根据入口状态或预设上下文，确定本次要执行的 `MoveData`。
2. 播放 `current_move.animation_name`。
3. 扣除 `current_move.stamina_cost`。
4. 重置 `current_move_frame`。
5. 清空 `queued_next_attack` 和 `queued_next_move`。
6. 清空 `already_hit_targets`。
7. 初始化伤害盒位置和尺寸。

### 11.2 每帧更新

`AttackState.physics_update(delta)` 每帧执行：

1. 推进 `current_move_frame`。
2. 判断当前属于前摇、出招还是后摇。
3. 根据帧段决定是否激活伤害盒。
4. 根据位移段决定是否施加水平位移。
5. 根据输入窗口判断是否允许缓存下一招。
6. 招式结束时决定回基础状态还是切下一招。

### 11.3 攻击阶段同步

攻击阶段映射到 `Core.AttackPhase`：

- 前摇 -> `STARTUP`
- 出招 -> `ACTIVE`
- 后摇 -> `RECOVERY`

`AttackState` 每帧调用 `state_machine.update_sub_attack_state(...)`，保持现有三层状态查询结构可用。

## 12. 伤害盒与伤害帧规则

### 12.1 伤害盒激活规则

当 `current_move_frame` 落在任意 `active_frame_ranges` 中时：

- 打开 `AttackHitbox.monitoring`
- 更新伤害盒位置

不在伤害帧内时：

- 关闭伤害盒

### 12.2 命中规则

当有目标进入伤害盒时：

- 若目标已存在于 `already_hit_targets`，则本次伤害窗不重复结算。
- 若目标不在集合中，则结算一次伤害，并记录到集合。

初版伤害公式：

- `final_damage = character.data.attack * current_move.damage_multiplier`

### 12.3 多段伤害窗

若一个招式存在多个 `active_frame_ranges`：

- 每个伤害窗都可以单独重置一次 `already_hit_targets`。
- 这样同一招的不同段命中可以多次生效。

初版也可以先简化为：

- 整个招式过程中同一目标只吃一次伤害。

推荐本次实现采用“按伤害窗重置”的方式，更符合多段攻击预期。

## 13. 位移规则

位移由 `movement_segments` 控制。

每个段的计算原则：

- 在 `start_frame` 到 `end_frame` 区间内逐帧推进。
- 每帧位移 = `distance / segment_frame_count`
- 朝右时为正，朝左时为负

初版约束：

- 只推动 X 轴。
- 不改动高度系统。
- 不采用瞬移式根运动。

这样可以与当前 [movement_component.gd](file:///E:/myproject/battle/script/character/movement_component.gd) 的水平移动体系共存。

## 14. 派生与连段规则

### 14.1 派生入口

从不同状态进入攻击时，入口规则如下：

- `GroundState` 按攻击 -> 地面普攻 1
- `DashState` 按攻击 -> 冲刺攻击
- `AirState` 按攻击 -> 空中攻击

### 14.2 地面连段

- `ground_combo_1` 在出招或后摇阶段按攻击：
  - 缓存 `ground_combo_2`
- `ground_combo_2` 在出招或后摇阶段按攻击：
  - 缓存 `ground_combo_3`
- `ground_combo_3`：
  - 当前轮结束，不继续派生

### 14.3 冲刺攻击派生

- `dash_attack` 在出招或后摇阶段按攻击：
  - 缓存 `ground_combo_2`

原因：

- 对应需求“冲刺攻击出招和后摇按攻击，到攻击后摇时候就是播攻击2动画”。

### 14.4 空中攻击派生

- `air_attack` 初版不接空中连段。
- 招式结束后：
  - 若角色仍在空中，回 `AirState`
  - 若已经落地，回 `GroundState`

### 14.5 缓存规则

- 只允许在出招期和后摇期缓存下一招。
- 前摇期不允许缓存。
- 缓存的是“下一招意图”，不提前打断当前招。
- 当前招式正常结束后，若存在缓存，则无缝切入下一招。

说明：

- 这里的“attack 行为状态允许进入攻击”，在实现上具体指“当前已处于 `AttackState`，且攻击子状态为 `RECOVERY`，允许续接下一招”。
- 因此前摇和出招阶段不会被新的攻击输入打断，只会在允许的窗口内记录缓存输入。

## 15. 动画占位策略

由于部分动画资源后续补充，本次允许占位映射：

- `ground_combo_1` 使用对应重命名后的首段普攻动画
- `ground_combo_2` 使用对应重命名后的二段普攻动画
- `ground_combo_3` 初版可暂时复用 `ground_combo_2`
- `dash_attack` 初版可暂时复用 `ground_combo_1`
- `air_attack` 初版可暂时复用 `ground_combo_1`

后续补资源时，只需要更新资源或动画名映射，不需要改攻击主流程。

## 16. 文件改动清单

### 16.1 新增脚本

- `script/ability/attack_ability.gd`
- `script/state/attack_state.gd`
- `script/data/move_data.gd`
- `script/data/attack/frame_range_data.gd`
- `script/data/attack/movement_segment_data.gd`
- `script/data/attack/character_attack_set.gd`

### 16.2 新增资源

- `script/data/attack/c001_attack_set.tres`
- `script/data/attack/m_c001_a001.tres`
- `script/data/attack/m_c001_a002.tres`
- `script/data/attack/m_c001_a003.tres`
- `script/data/attack/m_c001_dash_a001.tres`
- `script/data/attack/m_c001_air_a001.tres`

### 16.3 修改脚本

- [character.gd](file:///E:/myproject/battle/script/character/character.gd)
  - 增加攻击配置资源引用
  - 增加攻击伤害或体力处理辅助接口
- [player_controller.gd](file:///E:/myproject/battle/script/character/player_controller.gd)
  - 挂接并驱动 `AttackAbility`
- [ground_state.gd](file:///E:/myproject/battle/script/state/ground_state.gd)
  - 支持地面攻击入口
- [air_state.gd](file:///E:/myproject/battle/script/state/air_state.gd)
  - 支持空中攻击入口
- [dash_state.gd](file:///E:/myproject/battle/script/state/dash_state.gd)
  - 支持冲刺攻击入口
- [state_machine.gd](file:///E:/myproject/battle/script/state/state_machine.gd)
  - 注册 `AttackState`
- [c001.tres](file:///E:/myproject/battle/asset/animation/c001.tres)
  - 动画改名为语义化命名
- [c001.tscn](file:///E:/myproject/battle/tscn/character/c001.tscn)
  - 挂接 `AttackHitbox`、`AttackAbility`、`AttackState`

## 17. 实现要求

- 新增和修改的代码都使用详细的简体中文注释。
- 注释重点说明：
  - 状态切换条件
  - 攻击帧推进逻辑
  - 伤害盒开关逻辑
  - 位移段计算逻辑
  - 连段缓存和派生选择逻辑
- 注释写在关键变量、核心函数和复杂判断前，避免后续维护时必须反推逻辑。
- 保持注释与实现一致，若后续调整规则，必须同步更新注释。

## 18. 错误处理与防御性策略

- 如果角色未配置攻击资源，攻击输入应安全失败，并输出明确警告。
- 如果缺少 `AttackHitbox` 节点，攻击状态应跳过命中逻辑而不是直接报空引用。
- 如果动画名缺失，攻击状态应输出警告并保证状态最终能退出。
- 如果体力不足，攻击入口应直接拒绝进入攻击状态。
- 如果招式帧数配置与动画帧数不一致，以 `MoveData.total_frames` 为准推进逻辑，但应输出配置警告。

## 19. 验证点

本次设计落地后，至少验证以下行为：

- 鼠标左键和 `J` 都能触发攻击。
- 地面状态下首击能进入 `ground_combo_1`。
- `ground_combo_1` 与 `ground_combo_2` 可以正确连段。
- `ground_combo_2` 可以接 `ground_combo_3`。
- 冲刺攻击可以进入 `dash_attack`，并可派生到 `ground_combo_2`。
- 空中攻击可以进入 `air_attack`，结束后正确回空中或地面状态。
- 伤害盒只在伤害帧内开启。
- 攻击位移只在配置帧内发生。
- 体力消耗按每招正确扣除。
- 语义化动画名重命名后播放正常。

## 20. 测试建议

本次以回归验证和最小必要检查为主，不强制扩大量自动化测试。

建议最低限度检查：

- Godot 工程中无脚本解析错误。
- 最近编辑文件诊断信息正常。
- 在测试场景中手动验证地面、冲刺、空中三类攻击入口。
- 手动验证至少一条完整地面连段和一条冲刺派生链。

若后续开始增加自动化覆盖，优先补以下方向：

- `AttackState` 的帧推进与阶段切换
- 伤害窗开关逻辑
- 位移段逐帧推进逻辑
- 连段缓存和派生选择逻辑

## 21. 实施边界

本次设计明确不处理以下内容：

- 敌人受击动画和受击状态
- 击退、浮空、硬直、霸体
- 暴击、防御减伤、属性克制
- 复杂命中盒动画同步
- 完整技能树或资源化派生表

## 22. 结论

本次攻击模块采用“**资源化招式数据 + AttackState 执行 + 代码编排派生**”方案。

该方案具备以下优点：

- 满足当前对招式数值资产化的要求。
- 与现有状态机和能力层结构兼容。
- 能较低风险地支持地面、冲刺、空中的首批攻击玩法。
- 后续补动画和扩数值时，改动集中、维护成本低。
