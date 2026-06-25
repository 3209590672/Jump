# 《不许跳！》D1 技术设计文档

版本：D1 / 技术原型版  
目标读者：程序  
适用范围：TapTap Code / UrhoX Lua 原型阶段  
核心目标：用最小实现验证“反冲跳跃”手感

---

## 1. D1 技术目标

D1 的技术目标不是搭完整工程，而是用最小代码验证核心手感：

```text
瞄准 → 开火 → 反冲 → 飞行 → 落地 / 失败 → 快速重试
```

D1 成功标准：

- 角色不用跳跃键也能完成房间。
- 开火反冲方向稳定、可预测。
- 失败后能在 0.5 秒内重试。
- PC 必须可玩，手机拖拽瞄准尽量可玩。
- 所有核心参数可在配置表里调整，不改逻辑代码。

---

## 2. D1 最小技术决策

为了让 D1 能直接开工，本文件先锁定一套最小实现方案。

### 2.1 坐标与单位

D1 使用固定逻辑画布，不直接使用 UrhoX 世界米单位。

```text
逻辑画布：960 × 720
逻辑坐标：Y 轴向上
渲染坐标：按屏幕坐标绘制，Y 轴通常向下
单位含义：本文所有坐标、速度、平台尺寸均为“逻辑像素”
```

也就是说：

```lua
spawn = { x = 80, y = 320 }
gravity = 1400
recoilPower = 620
```

这些不是米单位，而是 D1 自定义逻辑坐标单位。

如果后续改为 UrhoX 场景单位，需要整体换算成米级参数，例如：

```lua
spawn = { x = 0.8, y = 3.2 }
gravity = 14.0
recoilPower = 6.2
```

D1 暂不做这件事。先用逻辑像素更快验证手感。

### 2.2 渲染方案

D1 推荐使用 NanoVG 绘制白盒原型。

绘制内容：

- 背景。
- 平台矩形。
- 玩家矩形。
- 终点矩形。
- 掉落区域提示。
- 瞄准线。
- 可选：反冲方向箭头。
- 简单 HUD 文本。

D1 不使用正式 Sprite、模型、动画状态机或复杂 UI 皮肤。

后续正式 UI 可以换成平台 UI 组件，但 D1 的计时、重生次数、通关提示可以先用 NanoVG 文本临时绘制。

### 2.3 视口策略

D1 使用固定逻辑画布 `960 × 720`，渲染时等比缩放到屏幕并居中。

第一版房间尽量全部放在一屏内，不做相机跟随。

这样可以避免 D1 同时调“手感”和“镜头”，降低变量数量。

---

## 3. 技术设计原则

本项目的程序准则来自 Unity 架构文档，但当前目标环境是 TapTap Code / UrhoX Lua，所以只吸收原则，不照搬 Unity API。

### 需要吸收的原则

- 单一职责：输入、移动、反冲、碰撞、重生、UI 分开。
- 速度驱动：维护 `velocity`，不要直接瞬移 `position`。
- 数据外置：玩家、武器、关卡参数放 config。
- 事件解耦：开火、落地、失败、通关只发事件，由 UI/音效/特效订阅。
- 组合优先：Player 组合多个模块，不做复杂继承链。

### 不要照搬的 Unity 概念

| Unity 概念 | Lua / TapTap Code 对应方式 |
|---|---|
| MonoBehaviour | 普通 Lua module + `init/update` 函数 |
| ScriptableObject | Lua 配置表 |
| GetComponent | 显式持有模块引用，或事件通信 |
| CharacterController | 轻量自定义速度积分，后续再接平台物理 |
| Interface | 约定函数签名 / 小模块协议 |

---

## 4. D1 推荐目录结构

D1 阶段建议只建这些脚本：

```text
scripts/
├── main.lua
├── config/
│   ├── player_config.lua
│   ├── weapon_config.lua
│   └── level_d1_config.lua
├── core/
│   ├── event_bus.lua
│   └── viewport.lua
├── gameplay/
│   ├── input_controller.lua
│   ├── player_controller.lua
│   ├── recoil_system.lua
│   ├── collision_checker.lua
│   ├── respawn_system.lua
│   └── finish_checker.lua
└── ui/
    ├── d1_hud.lua
    └── d1_renderer.lua
```

### `main.lua` 职责

`main.lua` 是 D1 编排层，只负责把模块串起来。

职责：

- 初始化渲染、输入、配置、玩家状态。
- 订阅 update / render 事件。
- 每帧按固定顺序调用 gameplay 模块。
- 把玩家状态交给 HUD / renderer。
- 维护 D1 的简单 timer / levelState。

`main.lua` 不应该写复杂反冲、碰撞或 UI 细节。

### D1 暂时不要建

- 完整武器系统。
- 完整状态机框架。
- 关卡选择系统。
- 排行榜适配器。
- 存档系统。
- 多角色/敌人基类。

这些东西 D1 用不到，先不要让架构把手感测试拖慢。

---

## 5. 模块职责

### 5.1 `config/player_config.lua`

只放玩家移动相关参数。

```lua
return {
  moveSpeed = 90,
  groundAcceleration = 1200,
  groundFriction = 1600,
  airControlAcceleration = 180,
  gravity = 1400,
  fallGravity = 1800,
  maxFallSpeed = 1200,
  maxHorizontalSpeed = 900,
  groundSnapSpeed = 60,
  landingGraceWidth = 6,
  landingGraceHeight = 4
}
```

说明：

- 所有数值都是逻辑像素单位。
- `moveSpeed` 只是地面左右慢速移动，不是主要移动方式。
- `airControlAcceleration` 要低，避免玩家靠空中方向键飞行。
- `fallGravity` 可以大于 `gravity`，让下落更干脆。
- `landingGraceWidth` / `landingGraceHeight` 用来做轻微落地宽容。

---

### 5.2 `config/weapon_config.lua`

D1 只有一把“校准手枪”。

```lua
return {
  calibratePistol = {
    recoilPower = 620,
    cooldown = 0.32,
    maxAirShots = 1,
    minAimLengthPixels = 12,
    maxSpeedAfterRecoil = 1100
  }
}
```

说明：

- `recoilPower` 是最关键参数。
- `maxAirShots = 1`，落地后恢复。
- `minAimLengthPixels` 用于触屏拖拽；拖拽距离太短不触发开火。
- `maxSpeedAfterRecoil` 防止多次叠速度导致不可控。
- D1 不做随机散布，不做持续开火，不做弹药。

---

### 5.3 `config/level_d1_config.lua`

D1 关卡用数据搭白盒。

```lua
return {
  canvas = { w = 960, h = 720 },
  spawn = { x = 80, y = 320 },
  fallY = -120,
  finish = { x = 840, y = 620, w = 80, h = 80 },
  platforms = {
    { id = "start", x = 40,  y = 260, w = 180, h = 24 },
    { id = "p1",    x = 300, y = 330, w = 180, h = 24 },
    { id = "p2",    x = 500, y = 470, w = 160, h = 24 },
    { id = "p3",    x = 690, y = 600, w = 140, h = 24 }
  }
}
```

平台先用矩形。D1 不做斜坡、移动平台、机关。

---

## 6. 核心数据结构

D1 玩家运行时状态可以先保持简单：

```lua
local player = {
  position = { x = 0, y = 0 },
  previousPosition = { x = 0, y = 0 },
  velocity = { x = 0, y = 0 },
  width = 32,
  height = 48,
  isGrounded = false,
  airShotsUsed = 0,
  fireCooldownLeft = 0,
  respawnCount = 0,
  finished = false
}
```

`previousPosition` 必须保留，用于平台穿越判定，避免高速下落穿过平台或侧面碰撞被误判为落地。

输入状态：

```lua
local input = {
  moveAxis = 0,
  aimDir = { x = 0, y = -1 },
  firePressed = false,
  respawnPressed = false
}
```

关卡运行状态建议由 `main.lua` 或 `levelState` 维护：

```lua
local levelState = {
  elapsedTime = 0,
  hasStarted = true,
  finished = false
}
```

D1 计时可以进入房间即开始，不必做复杂起跑判定。

---

## 7. 逻辑坐标与屏幕坐标转换

游戏逻辑坐标使用 Y 向上，NanoVG / 屏幕绘制通常是 Y 向下，所以必须统一通过 `viewport.lua` 转换。

推荐接口：

```lua
Viewport = {
  canvasW = 960,
  canvasH = 720,
  scale = 1,
  offsetX = 0,
  offsetY = 0
}

function Viewport.update(screenW, screenH)
  local scaleX = screenW / Viewport.canvasW
  local scaleY = screenH / Viewport.canvasH
  Viewport.scale = math.min(scaleX, scaleY)
  Viewport.offsetX = (screenW - Viewport.canvasW * Viewport.scale) * 0.5
  Viewport.offsetY = (screenH - Viewport.canvasH * Viewport.scale) * 0.5
end

function Viewport.worldToScreen(x, y)
  local sx = Viewport.offsetX + x * Viewport.scale
  local sy = Viewport.offsetY + (Viewport.canvasH - y) * Viewport.scale
  return sx, sy
end

function Viewport.screenToWorld(sx, sy)
  local x = (sx - Viewport.offsetX) / Viewport.scale
  local y = Viewport.canvasH - ((sy - Viewport.offsetY) / Viewport.scale)
  return x, y
end
```

所有鼠标坐标、触屏坐标必须先转成逻辑世界坐标，再参与瞄准计算。

---

## 8. 每帧 update 顺序

推荐固定顺序：

```text
1. 刷新视口尺寸
2. 读取输入，并把屏幕坐标转换到逻辑坐标
3. 更新 timer / 冷却计时
4. 保存 previousPosition
5. 处理开火与反冲
6. 处理水平慢速移动
7. 处理重力
8. 限制速度
9. 根据 velocity 移动 position
10. 处理平台碰撞与落地
11. 检查掉落重生
12. 检查终点
13. 更新 HUD / 渲染状态
```

伪代码：

```lua
function update(dt)
  dt = math.min(dt, 1 / 20)

  Viewport.update(screenW, screenH)

  local input = InputController.read(Viewport, player)

  if not levelState.finished then
    levelState.elapsedTime = levelState.elapsedTime + dt
  end

  PlayerController.updateCooldown(player, dt)
  PlayerController.savePreviousPosition(player)

  if input.respawnPressed then
    RespawnSystem.restartRun(player, level, levelState)
    return
  end

  if not levelState.finished then
    if input.firePressed then
      RecoilSystem.tryFire(player, input.aimDir)
    end

    PlayerController.applyGroundMove(player, input.moveAxis, dt)
    PlayerController.applyGravity(player, dt)
    PlayerController.clampVelocity(player)
    PlayerController.integrate(player, dt)

    CollisionChecker.resolvePlatforms(player, level.platforms)
    RespawnSystem.update(player, level, levelState)
    FinishChecker.update(player, level.finish, levelState)
  end

  D1Hud.update(player, levelState)
end
```

如果 TapTap Code 提供固定帧物理回调，优先在固定帧里跑核心物理。若只能拿到普通 `dt`，要对异常大的 `dt` 做上限裁剪。

---

## 9. 瞄准方向定义

D1 明确规定：

```text
aimDir 表示枪口指向方向。
aimDir 从玩家中心指向鼠标位置 / 触屏拖拽当前位置。
玩家会朝 -aimDir 方向飞。
```

PC：

```text
鼠标世界坐标 - 玩家中心 = aimDir
左键按下瞬间 firePressed = true
```

手机：

```text
右半屏按下并拖拽。
拖拽当前位置世界坐标 - 玩家中心 = aimDir。
松手瞬间，如果拖拽长度 >= minAimLengthPixels，则 firePressed = true。
```

D1 不采用“拉弓式反向拖拽”。也就是说，不是从当前点指向按下点，而是始终把拖拽当前位置当作枪口瞄准方向。

如果试玩发现手机这样不顺手，D2 再测试“拉弓式”。D1 先统一规则，避免 PC 与手机方向相反。

---

## 10. 输入设计

### PC

```text
A / D：左右移动
鼠标位置：瞄准
左键按下：开火
R：重生
```

### 手机

```text
左侧：水平移动
右侧：拖拽瞄准
右侧有效拖拽松手：开火
按钮：重生
```

输入模块对外只输出统一结构：

```lua
return {
  moveAxis = moveAxis,
  aimDir = aimDir,
  firePressed = firePressed,
  respawnPressed = respawnPressed
}
```

规则：

- PC 的 `firePressed` 表示左键按下瞬间。
- 手机的 `firePressed` 表示有效右侧拖拽释放瞬间。
- 拖拽长度小于 `minAimLengthPixels` 时，不触发开火。
- PC 与手机只在 `input_controller.lua` 内分支。后面的玩法逻辑不关心设备类型。

---

## 11. 反冲系统设计

核心公式：

```text
recoilVelocity = -aimDirection * recoilPower
player.velocity += recoilVelocity
```

Lua 伪代码：

```lua
function RecoilSystem.tryFire(player, aimDir)
  if player.fireCooldownLeft > 0 then
    return false
  end

  if not player.isGrounded and player.airShotsUsed >= weapon.maxAirShots then
    return false
  end

  local dir = normalizeOrDown(aimDir)

  player.velocity.x = player.velocity.x - dir.x * weapon.recoilPower
  player.velocity.y = player.velocity.y - dir.y * weapon.recoilPower

  clampSpeed(player.velocity, weapon.maxSpeedAfterRecoil)

  player.fireCooldownLeft = weapon.cooldown

  if not player.isGrounded then
    player.airShotsUsed = player.airShotsUsed + 1
  end

  EventBus.emit("player_fire", {
    x = player.position.x,
    y = player.position.y,
    aimX = dir.x,
    aimY = dir.y
  })

  return true
end
```

关键点：

- 反冲方向必须严格等于瞄准方向的反方向。
- 不允许加入随机散布。
- 空中补枪次数只在成功开火时消耗。
- 落地后恢复 `airShotsUsed = 0`。
- 开火失败可以不给反馈，或给一个很轻的“冷却中”反馈。

---

## 12. 地面移动设计

地面左右移动只是微调，不是核心跳跃。

推荐逻辑：

```lua
function PlayerController.applyGroundMove(player, moveAxis, dt)
  if player.isGrounded then
    local targetVx = moveAxis * playerConfig.moveSpeed
    player.velocity.x = moveTowards(
      player.velocity.x,
      targetVx,
      playerConfig.groundAcceleration * dt
    )

    if math.abs(moveAxis) < 0.01 then
      player.velocity.x = moveTowards(
        player.velocity.x,
        0,
        playerConfig.groundFriction * dt
      )
    end
  else
    player.velocity.x = player.velocity.x + moveAxis * playerConfig.airControlAcceleration * dt
  end
end
```

设计意图：

- 地面可以微调起跳点。
- 空中只能轻微修正，不能抢走反冲系统的主导权。
- 松手后不要瞬间停，用摩擦平滑减速。

---

## 13. 重力与速度上限

推荐：

```lua
function PlayerController.applyGravity(player, dt)
  local g = player.velocity.y > 0 and playerConfig.gravity or playerConfig.fallGravity
  player.velocity.y = player.velocity.y - g * dt
end
```

速度限制：

```lua
function PlayerController.clampVelocity(player)
  player.velocity.x = clamp(player.velocity.x, -playerConfig.maxHorizontalSpeed, playerConfig.maxHorizontalSpeed)
  player.velocity.y = math.max(player.velocity.y, -playerConfig.maxFallSpeed)
end
```

注意：

- D1 可以先不限制最大上升速度，只限制下落速度。
- 如果反冲叠加导致角色飞太疯，再加整体速度向量上限。

---

## 14. 平台碰撞与落地

D1 只做矩形平台，并使用上一帧位置做穿越判定。

### 14.1 必须保存上一帧位置

在移动积分前保存：

```lua
function PlayerController.savePreviousPosition(player)
  player.previousPosition.x = player.position.x
  player.previousPosition.y = player.position.y
end
```

### 14.2 落地判定

推荐判定逻辑：

```text
上一帧脚底 >= 平台顶部
当前帧脚底 <= 平台顶部
玩家正在下落 velocity.y <= 0
玩家水平范围与平台水平范围重叠
```

这样可以避免：

- 高速下落穿过平台。
- 从平台侧面撞上时被吸到平台顶。
- 从平台下方向上穿过时被错误判定为落地。

伪代码：

```lua
function CollisionChecker.isLandingOnPlatform(player, platform)
  local prevBottom = player.previousPosition.y
  local currBottom = player.position.y
  local platformTop = platform.y + platform.h

  local halfW = player.width * 0.5
  local playerLeft = player.position.x - halfW
  local playerRight = player.position.x + halfW

  local platformLeft = platform.x - playerConfig.landingGraceWidth
  local platformRight = platform.x + platform.w + playerConfig.landingGraceWidth

  local crossedTop = prevBottom >= platformTop and currBottom <= platformTop
  local falling = player.velocity.y <= 0
  local horizontalOverlap = playerRight >= platformLeft and playerLeft <= platformRight

  return crossedTop and falling and horizontalOverlap
end
```

### 14.3 落地处理

```lua
function CollisionChecker.resolvePlatforms(player, platforms)
  local wasGrounded = player.isGrounded
  player.isGrounded = false

  for _, platform in ipairs(platforms) do
    if CollisionChecker.isLandingOnPlatform(player, platform) then
      player.position.y = platform.y + platform.h
      player.velocity.y = 0
      player.isGrounded = true
      player.airShotsUsed = 0

      if not wasGrounded then
        EventBus.emit("player_land", { platformId = platform.id })
      end

      return
    end
  end
end
```

D1 暂不要求：

- 斜坡。
- 单向平台。
- 移动平台。
- 墙体滑动。
- 复杂多点碰撞。

---

## 15. 重生系统

D1 推荐自动快速重生。

触发条件：

- 玩家 `position.y < level.fallY`。
- 玩家按下 R / 重生按钮。

规则：

- 掉落后立即重生，最多保留 0.15 秒闪白反馈。
- R 键在非通关状态下可随时重生。
- 通关后 R 键用于重新开始 D1 房间。

重生逻辑：

```lua
function RespawnSystem.resetPlayerTransform(player, level)
  player.position.x = level.spawn.x
  player.position.y = level.spawn.y
  player.previousPosition.x = level.spawn.x
  player.previousPosition.y = level.spawn.y
  player.velocity.x = 0
  player.velocity.y = 0
  player.isGrounded = false
  player.airShotsUsed = 0
  player.fireCooldownLeft = 0
  player.finished = false
end

function RespawnSystem.respawnAfterFall(player, level)
  RespawnSystem.resetPlayerTransform(player, level)
  player.respawnCount = player.respawnCount + 1

  EventBus.emit("player_respawn", { count = player.respawnCount })
end

function RespawnSystem.restartRun(player, level, levelState)
  RespawnSystem.resetPlayerTransform(player, level)
  player.respawnCount = 0

  if levelState then
    levelState.elapsedTime = 0
    levelState.finished = false
  end

  EventBus.emit("player_respawn", { count = player.respawnCount })
end
```

如果是“掉落自动重生”，是否重置计时可按 D1 测试需要决定：

- 测完整通关时间：掉落不重置 timer，只增加重生次数。
- 测单次路线手感：掉落重置 timer。

D1 默认建议：掉落调用 `respawnAfterFall`，不重置 timer，只增加事故次数；手动 R 重开调用 `restartRun`，重置 timer 和事故次数。

---

## 16. 终点与计时

D1 计时由 `main.lua` 或 `levelState` 维护，不单独抽复杂 timer 模块。

完成条件：

```lua
if rectOverlap(playerRect, finishRect) then
  levelState.finished = true
  player.finished = true
  EventBus.emit("level_finish", {
    time = levelState.elapsedTime,
    respawnCount = player.respawnCount
  })
end
```

完成后 D1 明确采用冻结方案：

- 停止 timer。
- 禁止开火。
- 冻结玩家物理。
- 显示通关结果。
- 允许按 R 重新开始。

这样比“通关后继续乱飞”更简单，HUD 和成绩逻辑也更清楚。

---

## 17. 事件设计

`core/event_bus.lua` 保持极简。

需要的事件：

```text
player_fire
player_land
player_respawn
level_finish
```

只需要三个接口：

```lua
EventBus.on(eventName, callback)
EventBus.emit(eventName, data)
EventBus.clear()
```

D1 不做：

- 优先级。
- once。
- 异步事件。
- 事件队列。
- 复杂订阅对象生命周期。

边界：

- 每帧 HUD 数值，例如时间、重生次数、空中补枪次数：`D1Hud.update(player, levelState)`。
- 一次性提示，例如通关弹窗：订阅 `level_finish`。
- 开火、落地、重生反馈：订阅事件，或由 renderer 读取短时特效状态。

PlayerController 不要直接调用音效、UI、粒子。它只改变状态并发事件。

---

## 18. 瞄准反馈

D1 至少要画一条瞄准线。

瞄准线含义：

- 线指向枪口方向，也就是 `aimDir`。
- 玩家会朝反方向飞。

如果试玩者总是误解方向，可以额外显示一条淡色“反冲方向箭头”。

```text
实线：枪口方向
淡色箭头：玩家将被反冲的方向
```

D1 不建议做完整预测轨迹。原因：

- 成本更高。
- 容易让玩家只看轨迹，不学习反冲手感。
- 目前只需要方向反馈。

---

## 19. D1 渲染清单

`ui/d1_renderer.lua` 负责绘制白盒内容。

建议绘制顺序：

```text
1. 背景
2. 掉落危险区
3. 平台
4. 终点
5. 玩家
6. 瞄准线
7. 反冲方向箭头，可选
8. HUD 文本
9. 通关结果文本
```

所有世界坐标绘制前都通过 `Viewport.worldToScreen` 转换。

鼠标和触摸输入都通过 `Viewport.screenToWorld` 反算到逻辑坐标。

---

## 20. 数值调试顺序

不要同时调多个参数。推荐顺序：

1. `recoilPower`：先让玩家能从起点到平台 1。
2. `gravity / fallGravity`：调整飞行弧线是否干脆。
3. `maxFallSpeed`：避免下落过快穿平台。
4. `moveSpeed`：让地面微调有用但不喧宾夺主。
5. `airControlAcceleration`：让空中修正存在但不能飞行。
6. 平台位置和宽度：最后再调。

经验判断：

- 总是飞不过：先加反冲，不要先改平台。
- 总是飞过头：先降反冲或加重力。
- 总是落地烦：先加宽平台或增加边缘宽容。
- 玩家说“玄学”：先强化瞄准线和反冲方向反馈。

---

## 21. D1 技术验收清单

### 必须完成

- [ ] `scripts/main.lua`
- [ ] `scripts/config/player_config.lua`
- [ ] `scripts/config/weapon_config.lua`
- [ ] `scripts/config/level_d1_config.lua`
- [ ] `scripts/core/viewport.lua`
- [ ] 玩家受重力影响。
- [ ] 玩家能站在平台上。
- [ ] A/D 或移动输入可微调位置。
- [ ] 屏幕坐标能正确转换到逻辑坐标。
- [ ] 瞄准方向可视化。
- [ ] 开火产生反方向冲量。
- [ ] 空中最多补 1 枪。
- [ ] 落地恢复补枪次数。
- [ ] 平台落地使用上一帧穿越判定。
- [ ] 掉落后快速重生。
- [ ] 到达终点冻结玩家并显示用时、重生次数。
- [ ] R 可重新开始。

### 可以延后

- [ ] 手机输入。
- [ ] 音效。
- [ ] 粒子。
- [ ] 摄像机跟随优化。
- [ ] 通关评价文案。

### D1 不做

- [ ] 普通跳跃键。
- [ ] 持续开火。
- [ ] 多武器。
- [ ] 存档。
- [ ] 排行榜。
- [ ] 敌人/伤害。
- [ ] 程序生成地图。
- [ ] 完整 FSM 框架。

---

## 22. 主要风险与规避

| 风险 | 表现 | 规避 |
|---|---|---|
| 单位混乱 | 速度、重力、平台尺寸离谱 | D1 明确全部使用逻辑像素 |
| 坐标方向混乱 | 重力反了，瞄准线倒了 | 逻辑坐标 Y 向上，渲染统一转换 |
| 直接改位置 | 角色像瞬移，不像反冲 | 全部通过 velocity 积分移动 |
| 玩家控制不住 | 一枪飞太远、速度叠太高 | 降 recoilPower，加速度上限 |
| 控制像玄学 | 同样输入结果不一致 | 禁止随机冲量，固定参数 |
| 鼠标瞄准偏移 | 画布缩放后瞄准线不准 | 输入必须 screenToWorld |
| 空中控制太强 | 玩家不用枪也能飞 | 降低 airControlAcceleration |
| 平台碰撞烦躁 | 明明碰到边却掉下去 | 加边缘宽容，限制下落速度 |
| 高速穿平台 | 下落速度大时漏判 | 使用 previousPosition 穿越判定 |
| 架构过重 | D1 写不完 | 暂不做 FSM、存档、排行榜、多武器 |

---

## 23. D2 扩展预留

如果 D1 通过，D2 可以在不推翻架构的情况下扩展：

- 在 `weapon_config.lua` 加霰弹枪配置。
- 把 `RecoilSystem.tryFire` 拆成按 weaponId 读取参数。
- 在 `level_d1_config.lua` 基础上新增正式教程房间配置。
- UI 增加当前武器名和空中弹药显示。
- 把 NanoVG 白盒逐步替换为正式美术资源。

但 D1 不要提前实现这些。

---

## 24. 程序结论

D1 程序实现只需要追求一件事：

```text
玩家每一次开火后，都能清楚感觉到：
我刚才的角度，导致了这次飞行结果。
```

只要这个因果关系成立，后续的武器、关卡、剧情和成绩挑战才有继续制作的价值。