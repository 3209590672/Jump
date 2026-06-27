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
local UIManager = require("ui.ui_manager")
local VFX = require("ui.vfx")
local DialogBox = require("ui.dialog_box")
local TriggerSystem = require("gameplay.trigger_system")
local SFX = require("ui.sfx")
local TowerGenerator = require("gameplay.tower_generator")

local playerConfig = require("config.player_config")
local debugConfig = require("config.debug_config")

-- 关卡配置注册表（按 id 索引）
local levelConfigs = {
    ["01"]    = require("config.level_01_config"),
    ["2-1"]   = require("config.level_2_1_config"),
    ["2-2"]   = require("config.level_2_2_config"),
    ["2-3"]   = require("config.level_2_3_config"),
    ["tower"] = require("config.level_tower_config"),
}

-- 当前激活的关卡配置
local levelConfig = levelConfigs["01"]

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
    hasGun = true,             -- 是否拥有枪械（拾取前为 false）
    currentWeapon = nil,       -- 当前武器配置引用（由 enterLevel 设置）
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
    slowMotionHeld = false,
    respawnPressed = false,
}

-- ===== 慢动作参数 =====
local slowMotion = {
    scale = 0.35,
}

-- ============================================================================
-- 生命周期：Start / Stop
-- ============================================================================

-- 关卡列表数据（后续可从存档读取 bestTime）
local levelsData = {
    { id = "01",    name = "入职校准", unlocked = true, bestTime = nil },
    { id = "2-1",   name = "2-1 大力！", unlocked = true, bestTime = nil },
    { id = "2-2",   name = "2-2 跨越！", unlocked = true, bestTime = nil },
    { id = "2-3",   name = "2-3 刹车！", unlocked = true, bestTime = nil },
    { id = "tower", name = "无限爬塔", unlocked = true, bestTime = nil },
}

-- 爬塔模式标记
local isTowerMode = false

-- 当前正在玩的关卡 id
local currentLevelId = "01"

--- 进入关卡（按 id 切换配置 + 初始化场景 + 显示 HUD）
---@param id string 关卡 id
local function enterLevel(id)
    id = id or currentLevelId
    currentLevelId = id

    -- 切换关卡配置
    levelConfig = levelConfigs[id] or levelConfigs["01"]

    -- 初始化场景
    Viewport.init(levelConfig.canvas.w, levelConfig.canvas.h)
    D1Renderer.setLevel(levelConfig)
    RespawnSystem.resetPlayerTransform(player, levelConfig)

    -- 清理上一局遗留反馈
    VFX.reset()
    SFX.reset()
    DialogBox.reset()

    -- 重置状态
    levelState.elapsedTime = 0
    levelState.finished = false
    player.respawnCount = 0
    player.finished = false

    -- 枪械状态（根据关卡配置选择初始武器）
    local weaponConfig = require("config.weapon_config")
    player.hasGun = levelConfig.startWithGun ~= false
    if levelConfig.startWeapon == "shotgun" then
        player.currentWeapon = weaponConfig.shotgun
    else
        player.currentWeapon = weaponConfig.calibratePistol
    end

    -- 爬塔模式初始化
    isTowerMode = (id == "tower")
    if isTowerMode then
        TowerGenerator.init(levelConfig.tower, levelConfig.canvas.w)
    end

    -- 加载触发区域
    TriggerSystem.load(levelConfig.triggers)

    -- 显示游戏 HUD
    UIManager.showPlayingHud()
end

function Start()
    SampleStart()
    SampleInitMouseMode(MM_ABSOLUTE)

    -- 创建 NanoVG 上下文
    vg = nvgCreate(1)
    if not vg then
        print("[Main] ERROR: Failed to create NanoVG context!")
        return
    end
    print("[Main] NanoVG context created")

    -- 初始化 UI 系统
    UIManager.init()

    -- 订阅引擎事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")

    -- ===== 页面流转事件 =====

    -- 标题页 → 关卡选择
    EventBus.on("ui_goto_level_select", function()
        UIManager.showLevelSelect(levelsData)
    end)

    -- 关卡选择 → 返回标题
    EventBus.on("ui_goto_title", function()
        UIManager.showTitle()
    end)

    -- 关卡选择 → 开始游戏
    EventBus.on("ui_start_level", function(data)
        print("[Main] Starting level: " .. tostring(data.id))
        enterLevel(data.id)
    end)

    -- 结果页 → 重试（使用当前关卡 id）
    EventBus.on("ui_retry_level", function()
        enterLevel(currentLevelId)
    end)

    -- 游戏中通关事件 → 显示结果页
    EventBus.on("level_finish", function(data)
        -- 更新最佳成绩
        local levelName = currentLevelId
        for _, lv in ipairs(levelsData) do
            if lv.id == currentLevelId then
                if not lv.bestTime or data.time < lv.bestTime then
                    lv.bestTime = data.time
                end
                levelName = lv.name
            end
        end
        UIManager.showResult(player, levelState, levelName)
    end)

    -- 调试日志
    if debugConfig.enableEventLog then
        EventBus.on("player_fire", function(data)
            print(string.format("[Event] Fire at (%.0f, %.0f) aim=(%.2f, %.2f)",
                data.x, data.y, data.aimX, data.aimY))
        end)
        EventBus.on("player_land", function(data)
            print("[Event] Landed on: " .. tostring(data.platformId))
        end)
    end

    -- 初始化视觉反馈 + 音效
    VFX.init()
    VFX.initFont(vg)
    SFX.init()

    -- 初始化对话框字体
    DialogBox.initFont(vg)

    -- 触发区域事件处理
    EventBus.on("trigger_enter", function(data)
        local id = data.id

        -- 显示对话（如果该触发点有对话配置）
        if levelConfig.dialogs and levelConfig.dialogs[id] then
            DialogBox.show(levelConfig.dialogs[id])
        end

        -- 拾取枪械
        if id == "pickup_gun" then
            player.hasGun = true
            local wc = require("config.weapon_config")
            player.currentWeapon = wc.calibratePistol
            print("[Main] Pistol picked up!")
        elseif id == "pickup_shotgun" then
            local wc = require("config.weapon_config")
            player.currentWeapon = wc.shotgun
            print("[Main] Shotgun picked up!")
        end
    end)

    -- 启动时显示标题页
    UIManager.showTitle()
    print("[Main] Game started - showing title screen")
end

function Stop()
    UIManager.shutdown()
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
    dt = math.min(dt, 1 / 20)

    -- 非游戏页面时不执行游戏逻辑
    if UIManager.getScreen() ~= "playing" then return end

    -- 步骤 0：R 键重开优先级最高，即使对话 / hitstop 激活也必须生效
    if input:GetKeyPress(KEY_R) then
        enterLevel(currentLevelId)
        return
    end

    -- 步骤 0a：VFX 计时更新（hitstop/屏震独立于玩法）
    VFX.update(player, dt)

    -- 步骤 0b：对话框更新（对话激活时冻结玩法输入）
    DialogBox.update(dt)

    -- 步骤 1：刷新视口缩放 + 相机跟随（含前瞻 + 屏震偏移）
    local g = GetGraphics()
    Viewport.update(g:GetWidth(), g:GetHeight())
    local lx, ly = VFX.getLookahead()
    local sx, sy = VFX.getShakeOffset()
    local followX = player.position.x + lx + sx
    local followY = player.position.y + player.height * 0.5 + ly + sy

    -- 爬塔模式：相机只往上，不跟随下落
    if isTowerMode then
        local currentCamCenter = Viewport.camY + Viewport.viewH * 0.5
        if followY < currentCamCenter then
            followY = currentCamCenter  -- 不下降
        end
    end

    Viewport.follow(followX, followY)

    -- 对话或 hitstop 激活时不执行玩法逻辑
    if DialogBox.isActive() or VFX.isHitstopActive() then
        return
    end

    -- 步骤 2：读取输入
    currentInput = InputController.read(player)
    local gameDt = currentInput.slowMotionHeld and (dt * slowMotion.scale) or dt

    -- 步骤 3：更新计时（通关后停止，使用真实时间）
    if not levelState.finished then
        levelState.elapsedTime = levelState.elapsedTime + dt
    end

    -- 步骤 4：更新开火冷却
    PlayerController.updateCooldown(player, gameDt)

    -- 步骤 5：保存上一帧位置（碰撞穿越判定需要）
    PlayerController.savePreviousPosition(player)

    -- 步骤 6：R 键已在步骤 0 处理，避免被对话 / hitstop 拦截

    -- 通关后冻结所有玩法逻辑（只保留 R 键可用）
    if levelState.finished then
        return
    end

    -- 步骤 6.5：武器切换（爬塔模式按 1/2 切换）
    if isTowerMode or (levelConfig.enableWeaponSwitch) then
        local inputCfg = require("config.input_config")
        local wc = require("config.weapon_config")
        if input:GetKeyPress(inputCfg.weapon1) then
            player.currentWeapon = wc.calibratePistol
        elseif input:GetKeyPress(inputCfg.weapon2) then
            player.currentWeapon = wc.shotgun
        end
    end

    -- 步骤 7：开火与反冲（必须拥有枪械）
    if currentInput.firePressed and player.hasGun then
        RecoilSystem.tryFire(player, currentInput.aimDir)
    end

    -- 步骤 8：水平移动（地面加速/摩擦，空中微调）
    PlayerController.applyGroundMove(player, currentInput.moveAxis, gameDt)

    -- 步骤 9：施加重力（上升轻、下落重）
    PlayerController.applyGravity(player, gameDt)

    -- 步骤 10：限制速度（防止极端情况）
    PlayerController.clampVelocity(player)

    -- 步骤 11：速度积分到位置
    PlayerController.integrate(player, gameDt)

    -- 步骤 12：平台碰撞检测与修正
    if isTowerMode then
        -- 爬塔：使用动态生成的平台
        local towerPlatforms = TowerGenerator.getPlatforms()
        CollisionChecker.resolvePlatforms(player, towerPlatforms)
    else
        CollisionChecker.resolvePlatforms(player, levelConfig.platforms)
    end

    -- 步骤 13：掉落/死亡检测
    if isTowerMode then
        -- 爬塔：更新高度 + 生成新平台 + 死亡判定
        TowerGenerator.updateMaxHeight(player.position.y)
        local camBottom = Viewport.camY
        local camTop = camBottom + Viewport.viewH
        TowerGenerator.update(camTop, camBottom)

        -- 掉到相机底部以下 → 结算
        local deathLine = camBottom - levelConfig.tower.deathBelowCamera
        if player.position.y < deathLine then
            levelState.finished = true
            levelState.elapsedTime = TowerGenerator.getMaxHeight()  -- 用高度作为分数
            EventBus.emit("level_finish", {
                time = levelState.elapsedTime,
                respawnCount = player.respawnCount,
            })
        end
    else
        RespawnSystem.update(player, levelConfig, levelState)
    end

    -- 步骤 14：触发区域检测
    TriggerSystem.update(player)

    -- 步骤 15：终点到达检测（非爬塔模式）
    if not isTowerMode then
        FinishChecker.update(player, levelConfig.finish, levelState)
    end

    -- 步骤 16：更新 UI HUD
    UIManager.updateHud(player, levelState)
end

-- ============================================================================
-- NanoVG 渲染（在引擎渲染管线的 NanoVGRender 时机调用）
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if not vg then return end
    -- 非游戏页面时不绘制游戏世界（标题/选关/结果页由 UI 系统渲染）
    if UIManager.getScreen() ~= "playing" then return end

    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    nvgBeginFrame(vg, screenW, screenH, 1.0)
    local drawOpts = nil
    if isTowerMode then
        drawOpts = { platforms = TowerGenerator.getPlatforms() }
    end
    D1Renderer.draw(vg, player, levelState, currentInput, drawOpts)
    VFX.draw(vg, player, currentInput)
    DialogBox.draw(vg)
    nvgEndFrame(vg)
end

-- ============================================================================
-- 引擎兼容（空实现，防止手机端报错）
-- ============================================================================

function GetScreenJoystickPatchString()
    return ""
end
