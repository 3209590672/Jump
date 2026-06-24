-- ============================================================================
-- 《不许跳！》D1 原型 - main.lua
-- 编排层：初始化所有模块，驱动每帧更新循环，连接渲染
--
-- 核心循环：瞄准 → 开火 → 反冲 → 飞行 → 落地/掉落 → 快速重试
-- 渲染方式：NanoVG 白盒（矩形 + 线 + 文本）
-- 坐标系：960×720 逻辑画布，Y 向上，原点在左下角
--
-- 帧更新 14 步：
--   1. 更新视口  2. 读输入  3. 更新计时  4. 更新冷却
--   5. 保存位置  6. R键重开  7. 开火反冲  8. 水平移动
--   9. 重力  10. 限速  11. 积分  12. 碰撞  13. 掉落重生  14. 终点检测
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ===== 模块引用 =====
local Viewport = require("core.viewport")
local EventBus = require("core.event_bus")
local InputController = require("gameplay.input_controller")
local PlayerController = require("gameplay.player_controller")
local RecoilSystem = require("gameplay.recoil_system")
local CollisionChecker = require("gameplay.collision_checker")
local RespawnSystem = require("gameplay.respawn_system")
local FinishChecker = require("gameplay.finish_checker")
local D1Renderer = require("ui.d1_renderer")
local D1Hud = require("ui.d1_hud")

local playerConfig = require("config.player_config")
local levelConfig = require("config.level_d1_config")

-- ===== NanoVG 上下文 =====
local vg = nil

-- ===== 玩家运行时状态 =====
-- position.y = 玩家底部 Y 坐标（不是中心）
-- position.x = 玩家水平中心
local player = {
    position = { x = 0, y = 0 },
    previousPosition = { x = 0, y = 0 },  -- 上一帧位置（碰撞穿越判定用）
    velocity = { x = 0, y = 0 },          -- 当前速度（px/s）
    width = playerConfig.width,
    height = playerConfig.height,
    isGrounded = false,        -- 是否站在平台上
    airShotsUsed = 0,          -- 本次滞空已使用的补枪次数
    fireCooldownLeft = 0,      -- 开火冷却剩余时间（秒）
    respawnCount = 0,          -- 累计事故（掉落）次数
    finished = false,          -- 是否已通关
}

-- ===== 关卡运行时状态 =====
local levelState = {
    elapsedTime = 0,   -- 本次挑战已用时间（秒）
    finished = false,  -- 是否已通关（通关后冻结更新）
}

-- ===== 当前帧输入缓存 =====
local currentInput = {
    moveAxis = 0,              -- -1/0/1
    aimDir = { x = 0, y = -1 },  -- 归一化瞄准方向
    firePressed = false,
    respawnPressed = false,
}

-- ============================================================================
-- 生命周期：Start / Stop
-- ============================================================================

function Start()
    SampleStart()
    -- 保持默认鼠标模式（可见光标，用于瞄准）
    SampleInitMouseMode(MM_ABSOLUTE)

    -- 创建 NanoVG 上下文（参数 1 = 开启抗锯齿）
    vg = nvgCreate(1)
    if not vg then
        print("[Main] ERROR: Failed to create NanoVG context!")
        return
    end
    print("[Main] NanoVG context created")

    -- 初始化 HUD 字体（只调用一次）
    D1Hud.initFont(vg)

    -- 将玩家放到出生点
    RespawnSystem.resetPlayerTransform(player, levelConfig)

    -- 订阅引擎事件
    SubscribeToEvent("Update", "HandleUpdate")               -- 每帧逻辑更新
    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")  -- NanoVG 渲染时机

    -- 注册游戏事件监听（调试日志，稳定后可删除）
    EventBus.on("player_fire", function(data)
        print(string.format("[Event] Fire at (%.0f, %.0f) aim=(%.2f, %.2f)",
            data.x, data.y, data.aimX, data.aimY))
    end)
    EventBus.on("player_land", function(data)
        print("[Event] Landed on: " .. tostring(data.platformId))
    end)

    print("[Main] D1 Prototype started - No Jumping Allowed!")
    print("[Main] Controls: A/D move, Mouse aim, LMB fire, R restart")
end

function Stop()
    EventBus.clear()
    if vg then
        nvgDelete(vg)
        vg = nil
    end
end

-- ============================================================================
-- 每帧更新（14 步固定顺序）
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- 防止异常大的 dt 导致物理爆炸（如窗口拖动卡顿后突然释放）
    dt = math.min(dt, 1 / 20)

    -- 步骤 1：刷新视口缩放（屏幕尺寸可能在运行时变化）
    local g = GetGraphics()
    Viewport.update(g:GetWidth(), g:GetHeight())

    -- 步骤 2：读取输入（统一为 moveAxis/aimDir/fire/respawn）
    currentInput = InputController.read(player)

    -- 步骤 3：更新计时（通关后停止）
    if not levelState.finished then
        levelState.elapsedTime = levelState.elapsedTime + dt
    end

    -- 步骤 4：更新开火冷却
    PlayerController.updateCooldown(player, dt)

    -- 步骤 5：保存上一帧位置（碰撞穿越判定需要）
    PlayerController.savePreviousPosition(player)

    -- 步骤 6：处理 R 键重开（优先级最高，立即生效）
    if currentInput.respawnPressed then
        RespawnSystem.restartRun(player, levelConfig, levelState)
        return  -- 重开后本帧不再继续
    end

    -- 通关后冻结所有玩法逻辑（只保留 R 键可用）
    if levelState.finished then
        return
    end

    -- 步骤 7：开火与反冲
    if currentInput.firePressed then
        RecoilSystem.tryFire(player, currentInput.aimDir)
    end

    -- 步骤 8：水平移动（地面加速/摩擦，空中微调）
    PlayerController.applyGroundMove(player, currentInput.moveAxis, dt)

    -- 步骤 9：施加重力（上升轻、下落重）
    PlayerController.applyGravity(player, dt)

    -- 步骤 10：限制速度（防止极端情况）
    PlayerController.clampVelocity(player)

    -- 步骤 11：速度积分到位置
    PlayerController.integrate(player, dt)

    -- 步骤 12：平台碰撞检测与修正
    CollisionChecker.resolvePlatforms(player, levelConfig.platforms)

    -- 步骤 13：掉落重生检测
    RespawnSystem.update(player, levelConfig, levelState)

    -- 步骤 14：终点到达检测
    FinishChecker.update(player, levelConfig.finish, levelState)
end

-- ============================================================================
-- NanoVG 渲染（在引擎渲染管线的 NanoVGRender 时机调用）
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if not vg then return end

    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    nvgBeginFrame(vg, screenW, screenH, 1.0)

    -- 先绘制场景（平台、玩家、瞄准线）
    D1Renderer.draw(vg, player, levelState, currentInput)

    -- 再绘制 HUD（计时、事故、通关面板）——覆盖在场景之上
    D1Hud.draw(vg, player, levelState)

    nvgEndFrame(vg)
end

-- ============================================================================
-- 引擎兼容（空实现，防止手机端报错）
-- ============================================================================

function GetScreenJoystickPatchString()
    return ""
end
