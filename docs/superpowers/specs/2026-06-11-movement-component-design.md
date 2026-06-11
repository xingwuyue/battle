# 角色移动组件化设计

## 1. 目标

- 将角色的平面移动与高度系统从 `Character` 中拆出，收敛到独立移动组件。
- 保持当前 `ability` 与 `state` 分层不变，不把外部调用点一次性打散。
- 让 `Character` 保留宿主与门面职责，对外接口尽量稳定。
- 为后续扩展击退、浮空、减速、位移技能等公共移动能力预留边界。

## 2. 现状评估

当前项目已有以下职责分布：

- [player_controller.gd](file:///E:/myproject/battle/script/character/player_controller.gd) 负责采集玩家输入，并写入 `character.input_direction`，同时把跳跃/冲刺输入分发给能力脚本。
- [jump_ability.gd](file:///E:/myproject/battle/script/ability/jump_ability.gd) 与 [dash_ability.gd](file:///E:/myproject/battle/script/ability/dash_ability.gd) 负责主动能力输入判定与门槛检查。
- [state_machine.gd](file:///E:/myproject/battle/script/state/state_machine.gd) 以及地面/空中/冲刺状态负责状态切换。

目前主要问题集中在 [character.gd](file:///E:/myproject/battle/script/character/character.gd)：

- 同时承担了宿主、移动结算、高度系统、朝向更新、移动动画更新等多种职责。
- `height / vertical_velocity / movement_speed_multiplier` 等运行时移动数据直接堆在角色本体上。
- `_physics_process()` 既处理高度系统，又做平面位移和移动动画，后续继续扩玩法时容易膨胀。
- 虽然已经有 `ability` / `state` 两层，但中间缺少“movement 组件层”，导致移动相关共性逻辑无处安放。

## 3. 方案对比

本次评估了三种方案：

- 轻量拆分：只把实现搬到 helper，`Character` 仍主导逻辑。
- 标准组件化：新增完整移动组件，`Character` 保留对外转发接口。
- 激进解耦：所有外部系统都直接依赖移动组件。

本次采用 **标准组件化**：

- 新增独立 `MovementComponent` 承接移动与高度实现。
- `Character` 只保留门面接口，不让现有 `state` / `ability` 立刻全部改成直连组件。
- 外部优先继续通过 `character.xxx()` 使用能力，内部实现再委托给组件。

## 4. 职责边界

### 4.1 Character

`Character` 只保留宿主职责：

- 持有角色基础资源 `data`。
- 持有场景节点引用，例如 `StateMachine`、`VisualRoot`、`AnimatedSprite2D`。
- 持有上层运行时输入与状态数据，例如 `input_direction`、`action_state`、`environment_state`。
- 提供对外门面接口，例如 `apply_vertical_impulse()`、`is_airborne()`、`get_current_move_speed()`。
- 在 `_physics_process()` 中转发到移动组件。

`Character` 不再直接实现：

- 高度积分。
- 平面位移结算。
- 朝向翻转。
- 地面 `idle/walk` 动画更新。

### 4.2 MovementComponent

`MovementComponent` 负责：

- 结算平面移动速度，并调用 `move_and_slide()`。
- 管理高度系统，包括 `height`、`vertical_velocity`、重力积分与落地判定。
- 根据输入方向更新朝向。
- 根据当前状态更新地面 `walk / idle` 动画。
- 管理移动速度倍率。
- 对 `Character` 提供统一移动查询与操作接口。

### 4.3 PlayerController / Ability / State

- `PlayerController` 继续只采集输入，不结算位移。
- `JumpAbility`、`DashAbility` 继续通过 `character.xxx()` 访问公共移动接口。
- `GroundState`、`AirState`、`DashState` 继续通过 `character` 查询空中状态、设置速度倍率、触发跳跃等。

## 5. 组件接口设计

### 5.1 MovementComponent 对内接口

建议新增 [movement_component.gd](file:///E:/myproject/battle/script/movement/movement_component.gd)，提供以下方法：

- `setup(host: Character) -> void`
  - 缓存宿主角色引用，避免每帧反查。
- `physics_update(delta: float) -> void`
  - 统一驱动高度系统、位移、动画、朝向与视觉高度更新。
- `is_airborne() -> bool`
- `can_receive_vertical_impulse() -> bool`
- `apply_vertical_impulse(impulse: float) -> bool`
- `set_movement_speed_multiplier(multiplier: float) -> void`
- `get_movement_speed_multiplier() -> float`
- `get_current_move_speed() -> float`
- `get_height() -> float`
- `get_vertical_velocity() -> float`

内部私有方法建议包括：

- `_update_height(delta: float) -> void`
- `_apply_horizontal_movement(sm: StateMachine) -> void`
- `_can_move_by_state(sm: StateMachine) -> bool`
- `_update_facing() -> void`
- `_update_move_animation(sm: StateMachine) -> void`
- `_update_visual_height() -> void`

### 5.2 Character 门面接口

`Character` 保留以下对外接口，内部转发给 `movement_component`：

- `is_airborne() -> bool`
- `can_receive_vertical_impulse() -> bool`
- `apply_vertical_impulse(impulse: float) -> bool`
- `set_movement_speed_multiplier(multiplier: float) -> void`
- `get_current_move_speed() -> float`

`Character` 继续自己保留：

- `get_base_move_speed() -> float`
  - 该值来源于 `CharacterData`，本身属于角色基础属性，不属于组件内部状态。
- `play_animation(anim_name: String) -> void`
  - 该能力更接近角色视觉能力，保留在宿主层更合适。

### 5.3 运行时数据归属

下列数据从 `Character` 迁移到 `MovementComponent`：

- `height`
- `vertical_velocity`
- `movement_speed_multiplier`

下列数据继续保留在 `Character`：

- `input_direction`
- `environment_state`
- `action_state`

说明：

- `environment_state` 与 `action_state` 仍然属于角色公共状态，对状态机和其他系统更直观。
- `MovementComponent` 负责写入 `character.environment_state`，但不拥有行为层语义。

## 6. 场景结构调整

建议在角色场景中新增节点：

- `MovementComponent`

推荐层级：

- `Character`
- `MovementComponent`
- `PlayerController`
- `StateMachine`
- `VisualRoot`

`Character` 中新增引用：

- `@onready var movement_component: MovementComponent = $MovementComponent`

初始化建议：

- `Character._ready()` 中先加载数据，再调用 `movement_component.setup(self)`，最后做初始视觉同步。
- `PlayerController._ready()` 保持现有逻辑不变。
- `StateMachine._ready()` 保持现有逻辑不变。

## 7. 文件改动清单

### 7.1 新增文件

- `script/movement/movement_component.gd`

### 7.2 修改文件

- [character.gd](file:///E:/myproject/battle/script/character/character.gd)
  - 删除移动与高度系统实现细节。
  - 增加组件引用与转发接口。
  - 将 `_physics_process()` 改为调用组件。
- 角色场景文件
  - 新挂载 `MovementComponent` 节点与脚本。

### 7.3 尽量不改或只做极小改动的文件

- [player_controller.gd](file:///E:/myproject/battle/script/character/player_controller.gd)
- [jump_ability.gd](file:///E:/myproject/battle/script/ability/jump_ability.gd)
- [dash_ability.gd](file:///E:/myproject/battle/script/ability/dash_ability.gd)
- [ground_state.gd](file:///E:/myproject/battle/script/state/ground_state.gd)
- [air_state.gd](file:///E:/myproject/battle/script/state/air_state.gd)
- [dash_state.gd](file:///E:/myproject/battle/script/state/dash_state.gd)

目标是让这些脚本继续走 `character.xxx()`，避免本次重构扩大影响面。

## 8. 数据流

每个物理帧的数据流如下：

1. `PlayerController` 读取输入并更新 `character.input_direction`。
2. `PlayerController` 把跳跃/冲刺输入记录到能力脚本。
3. `StateMachine` 驱动当前状态做状态判定。
4. `Character._physics_process(delta)` 调用 `movement_component.physics_update(delta)`。
5. `MovementComponent`：
   - 更新高度系统；
   - 根据状态机判断是否允许移动；
   - 结算平面位移；
   - 更新朝向；
   - 更新视觉高度；
   - 在符合条件时更新地面移动动画。

说明：

- 状态切换仍由状态层负责。
- 实际位移执行与高度积分则统一由组件负责。

## 9. 错误处理与防御性策略

- 如果 `movement_component` 节点缺失，`Character._ready()` 应输出明确错误，避免静默失效。
- 如果 `visual_root` 或 `animated_sprite` 缺失，组件相关视觉更新逻辑应安全跳过，而不是报空引用。
- 如果 `state_machine` 尚未准备好，移动组件应沿用当前逻辑：默认允许基础位移，避免初始化阶段卡死。
- 如果 `CharacterData` 未配置，继续沿用当前默认资源回退逻辑。

## 10. 迁移步骤

推荐按以下顺序落地：

1. 新增 `MovementComponent` 脚本，实现从 `Character` 挪出的移动与高度逻辑。
2. 修改 `Character`，加入组件引用与转发接口。
3. 调整角色场景，挂载 `MovementComponent` 节点。
4. 运行并验证地面移动、朝向、跳跃、落地、冲刺是否与现状一致。
5. 清理 `Character` 中不再使用的旧字段和私有方法。

## 11. 验证点

改造后至少验证以下行为：

- 地面 `WASD`/方向键移动仍正常，斜向速度仍被归一化。
- 地面待机与移动时 `idle / walk` 动画切换正常。
- 水平朝向翻转与当前输入一致。
- 跳跃后角色进入空中，`VisualRoot` 上抬表现正常。
- 落地后高度归零，能正确回到地面状态。
- 冲刺状态下速度倍率生效，退出冲刺后速度恢复。
- 地面可跳，空中不可重复起跳，保持当前限制不变。

## 12. 测试建议

本次以回归验证为主，不强制新增大量自动化测试。

建议最低限度检查：

- 打开 Godot 工程后确认脚本无解析错误。
- 检查修改文件的诊断信息，确保无明显类型或空引用告警。
- 手动在角色场景中验证移动、跳跃、冲刺 3 条主链路。

若后续项目开始增加自动化覆盖，优先为以下内容补测试：

- `MovementComponent` 的高度积分逻辑。
- `apply_vertical_impulse()` 的地面限制。
- `get_current_move_speed()` 的倍率叠加结果。

## 13. 风险与范围边界

本次重构不处理以下内容：

- 受击击退系统。
- 浮空连击或二段跳。
- 复杂根运动或技能位移。
- 把全部状态脚本都改成直接依赖组件。

已知风险：

- 如果角色场景未同步加上 `MovementComponent` 节点，会导致运行时报错。
- 如果后续又把新的移动规则直接写回 `Character`，会破坏这次组件化边界。

## 14. 结论

本次采用“**MovementComponent 承接实现，Character 保留门面接口**”的标准组件化方案。

这样可以：

- 让 `Character` 回归宿主职责；
- 保持 `ability` / `state` 对外调用方式基本稳定；
- 为后续更多公共移动能力提供清晰挂载点；
- 在当前项目阶段以较低风险完成职责拆分。
