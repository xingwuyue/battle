# 主角招式系统设计

## 1. 目标

- 仅面向主角角色设计一套可扩展的招式系统。
- 支持普通攻击、固定连招、带输入窗口的连招、冲刺攻击、跳跃攻击等派生招式。
- 支持“输入命令 + 上下文条件 + 招式匹配”的统一驱动方式。
- 支持每个招式独立配置动画、位移、可衔接下一招、取消窗口。
- 支持跳跃及其他腾空表现时，根据 `Shadow` 与 `VisualRoot` 的高度关系自动缩放阴影。

## 2. 现状评估

当前项目已有以下基础：

- 角色通过 [character.gd](file:///E:/myproject/battle/script/character/character.gd) 管理输入、状态机、视觉动画与物理移动。
- 状态机通过 [state_machine.gd](file:///E:/myproject/battle/script/state_machine/state_machine.gd) 驱动 `idle / move / jump / attack / defend ...` 等状态。
- 角色场景 [c001.tscn](file:///E:/myproject/battle/tscn/character/c001.tscn) 已具备：
  - `VisualRoot`：承载视觉偏移。
  - `AnimationPlayer`：可播放 `jump_motion` 等程序驱动动画。
  - 影子节点当前为 `Sprite2D`，建议统一重命名为 `Shadow`。

当前问题：

- `attack.gd` 只能代表单一攻击状态，不适合连招、冲刺攻击、跳跃攻击扩展。
- 触发逻辑目前按状态名和输入直接写死，不适合后续扩招。
- 跳跃视觉位移与影子缩放尚未建立统一关系。

## 3. 总体方案

采用“配置为主、代码匹配执行”的方案：

- **输入层**：物理按键先转换为逻辑命令，例如 `light_attack`。
- **规则层**：每个招式配置自己的触发条件、动画、位移、连招窗口、派生条件。
- **运行层**：代码根据当前角色上下文，匹配可用招式并执行。

不推荐两种极端方案：

- 不推荐全部硬编码在状态脚本中，后续分支会快速失控。
- 不推荐把条件写成字符串表达式解释执行，维护和排错成本过高。

## 4. 状态结构调整

建议将主角动作层改为以下结构：

- `idle`：空闲。
- `move`：地面移动/冲刺移动。
- `jump`：普通跳跃状态，负责空中移动与基础腾空表现。
- `action`：统一动作状态，负责所有主动招式。
- `defend / hit / die / interaction / tool`：保持原有职责。

说明：

- `attack001 / attack002 / sprint001 / jump_attack001` 不再是状态名。
- 它们成为 `action` 状态中的“当前招式实例”。
- `action` 状态只关心“当前正在执行哪一个 move_id”。

## 5. 数据结构设计

### 5.1 输入命令

新增逻辑命令层，不让招式直接绑定物理键位。

建议命令枚举：

- `light_attack`
- `heavy_attack`
- `skill`
- `jump`
- `defend`

按键映射示例：

- `J` -> `light_attack`
- 鼠标左键 -> `light_attack`

这样后续替换键位、加手柄都不会影响招式配置。

### 5.2 主角招式表资源

新增两个资源：

- `PlayerMoveData`：单个招式定义。
- `PlayerMoveSet`：主角招式表，存放多个 `PlayerMoveData`。

建议挂载位置：

- 挂在主角专用数据资源上，或直接挂在 `Character` 上。
- 若后续主角只有一个，可先挂在 `Character` 上，降低改造成本。

### 5.3 PlayerMoveData 字段

建议字段如下：

- `move_id: StringName`
  - 招式唯一标识，例如 `attack001`、`attack002`、`sprint001`。
- `display_name: String`
  - 展示名称，便于编辑器查看。
- `input_command: StringName`
  - 触发该招式的逻辑输入命令，例如 `light_attack`。
- `priority: int`
  - 同一输入命中多条规则时，优先级更高者先匹配。
- `animation_name: StringName`
  - 精灵动画名称。
- `motion_animation_name: StringName`
  - 视觉位移动画名称，可为空。
- `duration_override: float`
  - 可选；未填写时由动画时长推导。
- `required_state_tags: PackedStringArray`
  - 必须满足的上下文标签，例如 `ground`、`idle`、`sprint`。
- `blocked_state_tags: PackedStringArray`
  - 不能存在的上下文标签，例如 `air`。
- `required_prev_move_id: StringName`
  - 必须从哪个前置招式衔接，例如 `attack001`。
- `required_phase: StringName`
  - 需要命中的阶段，例如 `startup`、`active`、`recovery`、`combo_window`。
- `consume_input_buffer: bool`
  - 命中后是否消耗缓存输入。
- `root_motion_enabled: bool`
  - 是否启用程序驱动位移。
- `root_motion_curve: Resource`
  - 位移配置资源。
- `combo_links: Array[StringName]`
  - 理论上允许接入的后续招式列表。
- `cancel_tags: PackedStringArray`
  - 可取消到哪些类型的招式，例如 `ground_combo`、`air_combo`。
- `tags: PackedStringArray`
  - 该招式自身标签，例如 `ground_attack`、`air_attack`、`sprint_attack`。

### 5.4 位移资源

新增 `MoveRootMotionData` 资源，建议字段：

- `total_displacement: Vector2`
  - 整段动作总位移。
- `apply_facing: bool`
  - 是否受角色朝向影响。
- `mode: StringName`
  - 位移模式，例如 `curve`、`segments`。
- `time_points: PackedFloat32Array`
  - 关键时间点，范围 0 到 1。
- `position_points: Array[Vector2]`
  - 对应时间点的累计位移。

说明：

- 程序每帧根据动作进度插值出本帧位移，并写入 `character.velocity` 或直接累加位置。
- 地面突进、短滑步、跳斩前冲都能复用这一套。

### 5.5 阶段窗口

每个招式建议统一拆成以下阶段：

- `startup`：前摇。
- `active`：生效期。
- `recovery`：后摇。
- `combo_window`：允许接下一招的输入窗口。

阶段建议单独配置成时间窗口数组：

- `phase_name`
- `start_time`
- `end_time`

好处：

- `attack002` 可以要求 `required_prev_move_id = attack001`
- 同时要求 `required_phase = combo_window`
- 不需要把“后摇阶段”写死在代码里。

## 6. 上下文标签设计

不直接用状态名做全部判断，改为由代码汇总上下文标签。

建议基础标签：

- `idle`
- `move`
- `ground`
- `air`
- `sprint`
- `jump`
- `action`
- `defend`

建议动作标签：

- `ground_attack`
- `air_attack`
- `sprint_attack`
- `combo`

运行时由角色统一生成：

- 当前状态是 `idle` 时，加入 `idle`。
- 当前状态是 `move` 且 `is_dashing = true` 时，加入 `move` 和 `sprint`。
- 当前处于空中或跳跃表现中时，加入 `air`。
- 当前动作带 `sprint_attack` 标签时，供后续取消和派生判断。

## 7. 匹配规则

当玩家输入一个逻辑命令时，按以下顺序匹配：

1. 收集当前上下文标签。
2. 收集当前动作上下文：
   - 当前 `move_id`
   - 当前阶段
   - 当前动作剩余时间
   - 当前输入缓冲
3. 从 `PlayerMoveSet` 中筛出 `input_command` 一致的招式。
4. 过滤不满足 `required_state_tags` 的招式。
5. 过滤命中 `blocked_state_tags` 的招式。
6. 过滤不满足 `required_prev_move_id` 的招式。
7. 过滤不满足 `required_phase` 的招式。
8. 根据 `priority` 由高到低选中最终招式。

推荐优先级规则：

- 连招派生优先于状态派生。
- 状态派生优先于普通起手。
- 普通起手优先级最低。

例如：

- `attack002`：优先级 100
- `sprint001`：优先级 80
- `attack001`：优先级 10

这样同一次 `light_attack` 输入会优先接连段，再考虑冲刺攻击，最后才是普通起手。

## 8. 你给出的配置示例如何落地

### 8.1 attack001

- `move_id = attack001`
- `input_command = light_attack`
- `required_state_tags = [ground, idle]`
- `blocked_state_tags = [sprint, air]`
- `required_prev_move_id = ""`
- `required_phase = ""`
- `priority = 10`
- `animation_name = attack001`
- `tags = [ground_attack, combo]`

### 8.2 attack002

- `move_id = attack002`
- `input_command = light_attack`
- `required_state_tags = []`
- `blocked_state_tags = []`
- `required_prev_move_id = attack001`
- `required_phase = combo_window`
- `priority = 100`
- `animation_name = attack002`
- `tags = [ground_attack, combo]`

### 8.3 sprint001

- `move_id = sprint001`
- `input_command = light_attack`
- `required_state_tags = [ground, sprint]`
- `blocked_state_tags = [air]`
- `required_prev_move_id = ""`
- `required_phase = ""`
- `priority = 80`
- `animation_name = sprint001`
- `tags = [ground_attack, sprint_attack]`

## 9. 跳跃 Shadow 缩放方案

### 9.1 核心原则

- 不根据动画名硬编码缩放逻辑。
- 不在 `jump.gd` 中直接写死曲线。
- 统一根据 `VisualRoot` 相对初始位置的垂直偏移计算 `Shadow` 缩放。

### 9.2 计算方式

角色记录：

- `visual_root_origin`
- `shadow_origin_scale`
- `shadow_min_scale_ratio`
- `shadow_height_for_min_scale`

每帧计算：

- `height = max(0, visual_root_origin.y - visual_root.position.y)`
- `ratio = clamp(height / shadow_height_for_min_scale, 0.0, 1.0)`
- `scale_factor = lerp(1.0, shadow_min_scale_ratio, ratio)`
- `shadow.scale = shadow_origin_scale * scale_factor`

效果：

- 跳得越高，影子越小。
- 回落时自动恢复。
- 任何会抬高 `VisualRoot` 的动作都能复用，例如跳斩、击飞、腾空技能。

### 9.3 场景规范

建议主角场景统一：

- `Shadow`：阴影节点，建议为 `Sprite2D`
- `VisualRoot`：视觉根节点
- `AnimatedSprite2D`：角色帧动画
- `AnimationPlayer`：视觉运动动画播放器

若当前场景中影子节点名仍为 `Sprite2D`，建议统一重命名为 `Shadow`。

## 10. 攻击位移方案

### 10.1 目标

- 普通攻击可轻微前送。
- 冲刺攻击可长距离前冲。
- 跳跃攻击可在空中沿朝向推进。
- 位移由程序驱动，而不是依赖贴图动画本身错位。

### 10.2 执行原则

- 位移数据由招式资源配置。
- `action` 状态负责按动作进度执行位移。
- 位移执行和表现动画解耦。

### 10.3 推荐实现

动作开始时：

- 重置当前招式时间。
- 读取 `root_motion_curve`。

动作每帧更新时：

- 根据 `elapsed / duration` 得到归一化进度。
- 从位移曲线算出累计位移。
- 与上一帧累计位移做差，得到本帧增量。
- 增量结合朝向写入移动。

这样可以避免：

- 直接按速度常量推进导致动作节奏不贴合动画。
- 动作切段时突然跳位。

## 11. 输入缓冲建议

为了让连招手感稳定，建议加一个短输入缓冲：

- `input_buffer_time = 0.12 ~ 0.2 秒`

处理方式：

- 玩家按下 `light_attack` 时，不立刻丢弃输入。
- 若当前未命中规则，则在缓冲期内等待。
- 一旦进入 `combo_window`，再尝试消费输入并切到下一招。

这样可以减少：

- 玩家明明按到了，但因为时机早了几帧没有接上。

## 12. 配置建议

### 12.1 配置什么交给资源

建议放到资源里的内容：

- 招式 ID
- 输入命令
- 需要/禁止的上下文标签
- 前置招式
- 前置阶段
- 动画名
- 视觉运动动画名
- 位移参数
- 连招后续列表
- 招式标签
- 优先级

### 12.2 什么交给代码

建议交给代码处理的内容：

- 当前状态转换
- 当前上下文标签生成
- 当前阶段推进
- 输入缓冲
- 最终规则匹配
- 位移执行
- Shadow 缩放

结论：

- 资源负责“描述数据”。
- 代码负责“解释数据并执行”。

## 13. 实施顺序

建议按以下顺序实现：

1. 主角输入改为逻辑命令。
2. 新增 `PlayerMoveData / PlayerMoveSet / MoveRootMotionData`。
3. 新增 `action` 状态，替代当前单一 `attack` 状态逻辑。
4. 给 `Character` 增加动作上下文、输入缓冲、当前招式执行器。
5. 给 `Character` 增加 `Shadow` 自动缩放逻辑。
6. 先接通 `attack001 / attack002 / sprint001`。
7. 再扩 `jump_attack001` 等空中派生。

## 14. 配置使用说明

给策划/配置使用时，按以下步骤：

1. 在主角的 `PlayerMoveSet` 中新增一个招式条目。
2. 填写 `move_id` 和 `animation_name`。
3. 选择该招式的 `input_command`。
4. 按触发条件填写：
   - `required_state_tags`
   - `blocked_state_tags`
   - `required_prev_move_id`
   - `required_phase`
5. 如果招式有前冲或滑步，配置 `root_motion_curve`。
6. 如果招式可以接后续连段，填写 `combo_links`。
7. 调整 `priority`，避免和其他同输入招式冲突。

示例理解：

- 普通站立轻攻击：配 `ground + idle`
- 冲刺攻击：配 `ground + sprint`
- 跳跃攻击：配 `air`
- 第二段连招：配 `required_prev_move_id = attack001` 与 `required_phase = combo_window`

## 15. 风险与边界

- 若后续要支持“按住方向键 + 攻击”形成更复杂招式分支，输入命令层需要扩展方向修饰符。
- 若后续要支持“命中后才能派生”的技表，需再增加命中事件条件。
- 若后续要支持敌人共用这套系统，建议再把 `PlayerMoveSet` 抽象为通用 `MoveSet`。

当前阶段不建议提前做：

- 复杂脚本表达式条件
- 全角色统一招式系统
- 打击判定、受击框、命中冻结等完整战斗框架

## 16. 本次设计结论

本方案最终采用：

- **主角统一 `action` 状态**
- **逻辑输入命令层**
- **结构化招式资源表**
- **代码进行规则匹配与执行**
- **VisualRoot 驱动 Shadow 缩放**
- **招式资源驱动攻击位移**

这套方案能覆盖当前需求，并为后续扩展以下内容留出空间：

- 三段连招
- 冲刺攻击
- 跳跃攻击
- 特殊派生攻击
- 后续取消与输入缓冲
