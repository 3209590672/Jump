-- ============================================================================
-- 视觉反馈模块（VFX）
-- 手感反馈：开火闪光 / 飞行拖尾 / 落地飞尘 / 重生闪屏
--         / hitstop / 屏震 / 失败吐槽飘字 / 相机前瞻
-- ============================================================================
local Viewport = require("core.viewport")
local EventBus = require("core.event_bus")

local VFX = {}

-- ===== 开火闪光 =====
local muzzleFlash = {
    active = false, timer = 0, duration = 0.08,
    x = 0, y = 0, aimX = 0, aimY = 0,
}

-- ===== 飞行拖尾 =====
local trail = {
    points = {}, maxPoints = 12,
    spawnInterval = 0.02, spawnTimer = 0, maxAge = 0.3,
}

-- ===== 落地飞尘 =====
local landingDust = { particles = {}, _pending = false }

-- ===== 重生闪屏 =====
local respawnFlash = { active = false, timer = 0, duration = 0.25 }

-- ===== Hitstop（全局暂停） =====
local hitstop = { active = false, timer = 0, duration = 2 / 60 }  -- 2帧 ≈ 0.033s

-- ===== 屏震 =====
local screenShake = { active = false, timer = 0, duration = 0.08, magnitude = 3, offsetX = 0, offsetY = 0 }

-- ===== 失败吐槽飘字 =====
local quip = {
    active = false,
    timer = 0,
    duration = 2.0,
    text = "",
    lastIndex = 0,  -- 防连续重复
    pool = {
        "本次下落完全符合重力标准。",
        "系统建议：把枪口朝向你不想去的地方。",
        "安全条例第7条：禁止用脸着陆。",
        "很好，双脚离地但不算跳。",
        "测试编号 +1。继续。",
        "这不是失败，是数据采集。",
        "重力正常工作中，无需报修。",
        "建议调整角度，而非调整心态。",
        "上一位测试员在这里也摔了。",
        "符合预期。请重新校准。",
        "落地姿势评分：需改进。",
        "校准手枪表示它没有问题。",
    },
    fontId = -1,
}

-- ===== 相机前瞻 =====
local lookahead = { x = 0, y = 0, strength = 30, smoothing = 5 }

--- 清理所有运行中反馈（完整重开 / 切关时调用）
function VFX.reset()
    muzzleFlash.active = false
    muzzleFlash.timer = 0

    trail.points = {}
    trail.spawnTimer = 0

    landingDust.particles = {}
    landingDust._pending = false

    respawnFlash.active = false
    respawnFlash.timer = 0

    hitstop.active = false
    hitstop.timer = 0

    screenShake.active = false
    screenShake.timer = 0
    screenShake.offsetX = 0
    screenShake.offsetY = 0

    quip.active = false
    quip.timer = 0
    quip.text = ""

    lookahead.x = 0
    lookahead.y = 0
end

--- 初始化
function VFX.init()
    EventBus.on("player_fire", function(data)
        -- 闪光
        muzzleFlash.active = true
        muzzleFlash.timer = muzzleFlash.duration
        muzzleFlash.x = data.x
        muzzleFlash.y = data.y
        muzzleFlash.aimX = data.aimX
        muzzleFlash.aimY = data.aimY
        -- Hitstop
        hitstop.active = true
        hitstop.timer = hitstop.duration
        -- 屏震
        screenShake.active = true
        screenShake.timer = screenShake.duration
    end)

    EventBus.on("player_land", function(data)
        landingDust._pending = true
    end)

    EventBus.on("player_respawn", function(data)
        respawnFlash.active = true
        respawnFlash.timer = respawnFlash.duration
        -- 触发失败吐槽（data.count > 0 表示掉落重生而非 R 重开）
        if data.count and data.count > 0 then
            VFX._showQuip()
        end
    end)
end

--- 初始化飘字字体
function VFX.initFont(vg)
    quip.fontId = nvgCreateFont(vg, "quip", "Fonts/MiSans-Regular.ttf")
end

--- Hitstop 是否激活（main 用此判断是否跳过帧更新）
function VFX.isHitstopActive()
    return hitstop.active
end

--- 获取屏震偏移（Viewport 渲染时加上）
function VFX.getShakeOffset()
    return screenShake.offsetX, screenShake.offsetY
end

--- 获取相机前瞻偏移
function VFX.getLookahead()
    return lookahead.x, lookahead.y
end

--- 每帧更新
function VFX.update(player, dt)
    -- Hitstop 计时（独立于游戏逻辑）
    if hitstop.active then
        hitstop.timer = hitstop.timer - dt
        if hitstop.timer <= 0 then hitstop.active = false end
    end

    -- 屏震
    if screenShake.active then
        screenShake.timer = screenShake.timer - dt
        if screenShake.timer <= 0 then
            screenShake.active = false
            screenShake.offsetX = 0
            screenShake.offsetY = 0
        else
            local t = screenShake.timer / screenShake.duration
            local mag = screenShake.magnitude * t
            screenShake.offsetX = (math.random() * 2 - 1) * mag
            screenShake.offsetY = (math.random() * 2 - 1) * mag
        end
    end

    -- 闪光
    if muzzleFlash.active then
        muzzleFlash.timer = muzzleFlash.timer - dt
        if muzzleFlash.timer <= 0 then muzzleFlash.active = false end
    end

    -- 重生闪屏
    if respawnFlash.active then
        respawnFlash.timer = respawnFlash.timer - dt
        if respawnFlash.timer <= 0 then respawnFlash.active = false end
    end

    -- 失败飘字
    if quip.active then
        quip.timer = quip.timer - dt
        if quip.timer <= 0 then quip.active = false end
    end

    -- 落地飞尘
    if landingDust._pending and player.isGrounded then
        landingDust._pending = false
        local px, py = player.position.x, player.position.y
        for i = 1, 6 do
            local angle = math.random() * math.pi
            local speed = 40 + math.random() * 60
            table.insert(landingDust.particles, {
                x = px + (math.random() - 0.5) * player.width * 0.6,
                y = py, vx = math.cos(angle) * speed * (math.random() > 0.5 and 1 or -1),
                vy = math.sin(angle) * speed * 0.5, age = 0, maxAge = 0.2 + math.random() * 0.15,
            })
        end
    end
    local i = 1
    while i <= #landingDust.particles do
        local p = landingDust.particles[i]
        p.age = p.age + dt
        if p.age >= p.maxAge then table.remove(landingDust.particles, i)
        else p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt; p.vy = p.vy - 100 * dt; i = i + 1 end
    end

    -- 拖尾
    if not player.isGrounded then
        trail.spawnTimer = trail.spawnTimer + dt
        if trail.spawnTimer >= trail.spawnInterval then
            trail.spawnTimer = 0
            table.insert(trail.points, { x = player.position.x, y = player.position.y + player.height * 0.5, age = 0 })
            if #trail.points > trail.maxPoints then table.remove(trail.points, 1) end
        end
    else trail.spawnTimer = 0 end
    local j = 1
    while j <= #trail.points do
        trail.points[j].age = trail.points[j].age + dt
        if trail.points[j].age >= trail.maxAge then table.remove(trail.points, j) else j = j + 1 end
    end

    -- 相机前瞻（平滑跟随瞄准方向）
    local targetLX = player.velocity.x * 0.04  -- 速度方向轻微前瞻
    local targetLY = player.velocity.y * 0.03
    -- 限制幅度
    targetLX = math.max(-lookahead.strength, math.min(lookahead.strength, targetLX))
    targetLY = math.max(-lookahead.strength, math.min(lookahead.strength, targetLY))
    -- 平滑插值
    local s = math.min(1, lookahead.smoothing * dt)
    lookahead.x = lookahead.x + (targetLX - lookahead.x) * s
    lookahead.y = lookahead.y + (targetLY - lookahead.y) * s
end

--- 绘制所有 VFX
function VFX.draw(vg, player, inputState)
    VFX.drawTrail(vg)
    VFX.drawLandingDust(vg)
    VFX.drawMuzzleFlash(vg)
    VFX.drawRespawnFlash(vg)
    VFX.drawQuip(vg)
    VFX.drawSlowMotionOverlay(vg, inputState)
end

-- ===== 内部绘制函数 =====

function VFX.drawMuzzleFlash(vg)
    if not muzzleFlash.active then return end
    local offsetDist = 20
    local fx = muzzleFlash.x + muzzleFlash.aimX * offsetDist
    local fy = muzzleFlash.y + muzzleFlash.aimY * offsetDist
    local sx, sy = Viewport.worldToScreen(fx, fy)
    local t = muzzleFlash.timer / muzzleFlash.duration
    local alpha = math.floor(255 * t)
    local radius = Viewport.scaleSize(8 + 6 * (1 - t))
    nvgBeginPath(vg); nvgCircle(vg, sx, sy, radius * 1.5)
    nvgFillColor(vg, nvgRGBA(255, 200, 80, math.floor(alpha * 0.3))); nvgFill(vg)
    nvgBeginPath(vg); nvgCircle(vg, sx, sy, radius * 0.6)
    nvgFillColor(vg, nvgRGBA(255, 255, 220, alpha)); nvgFill(vg)
end

function VFX.drawTrail(vg)
    for _, pt in ipairs(trail.points) do
        local t = 1 - (pt.age / trail.maxAge)
        local sx, sy = Viewport.worldToScreen(pt.x, pt.y)
        nvgBeginPath(vg); nvgCircle(vg, sx, sy, Viewport.scaleSize(3 * t + 1))
        nvgFillColor(vg, nvgRGBA(120, 180, 255, math.floor(150 * t))); nvgFill(vg)
    end
end

function VFX.drawLandingDust(vg)
    for _, p in ipairs(landingDust.particles) do
        local t = 1 - (p.age / p.maxAge)
        local sx, sy = Viewport.worldToScreen(p.x, p.y)
        nvgBeginPath(vg); nvgCircle(vg, sx, sy, Viewport.scaleSize(2.5 * t + 0.5))
        nvgFillColor(vg, nvgRGBA(200, 210, 230, math.floor(180 * t))); nvgFill(vg)
    end
end

function VFX.drawRespawnFlash(vg)
    if not respawnFlash.active then return end
    local g = GetGraphics()
    local screenW, screenH = g:GetWidth(), g:GetHeight()
    local t = respawnFlash.timer / respawnFlash.duration
    local alpha = math.floor(80 * t)
    local bs = 40
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, bs)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, 0, bs, nvgRGBA(255,60,60,alpha), nvgRGBA(255,60,60,0))); nvgFill(vg)
    nvgBeginPath(vg); nvgRect(vg, 0, screenH-bs, screenW, bs)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, screenH-bs, 0, screenH, nvgRGBA(255,60,60,0), nvgRGBA(255,60,60,alpha))); nvgFill(vg)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, bs, screenH)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, bs, 0, nvgRGBA(255,60,60,alpha), nvgRGBA(255,60,60,0))); nvgFill(vg)
    nvgBeginPath(vg); nvgRect(vg, screenW-bs, 0, bs, screenH)
    nvgFillPaint(vg, nvgLinearGradient(vg, screenW-bs, 0, screenW, 0, nvgRGBA(255,60,60,0), nvgRGBA(255,60,60,alpha))); nvgFill(vg)
end

function VFX.drawQuip(vg)
    if not quip.active then return end
    if quip.fontId == -1 then return end
    local g = GetGraphics()
    local screenW, screenH = g:GetWidth(), g:GetHeight()
    local t = quip.timer / quip.duration
    -- 淡入淡出：前 0.2s 淡入，后 0.5s 淡出
    local alpha = 200
    local elapsed = quip.duration - quip.timer
    if elapsed < 0.2 then alpha = math.floor(200 * (elapsed / 0.2)) end
    if quip.timer < 0.5 then alpha = math.floor(200 * (quip.timer / 0.5)) end

    nvgFontFaceId(vg, quip.fontId)
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(220, 220, 240, alpha))
    nvgText(vg, screenW * 0.5, screenH - 50, quip.text, nil)
end

function VFX.drawSlowMotionOverlay(vg, inputState)
    if not inputState or not inputState.slowMotionHeld then return end

    local g = GetGraphics()
    local screenW, screenH = g:GetWidth(), g:GetHeight()

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(20, 45, 90, 36))
    nvgFill(vg)

    local edge = 70
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, edge)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, 0, edge,
        nvgRGBA(80, 180, 255, 46), nvgRGBA(80, 180, 255, 0)))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRect(vg, 0, screenH - edge, screenW, edge)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, screenH - edge, 0, screenH,
        nvgRGBA(80, 180, 255, 0), nvgRGBA(80, 180, 255, 46)))
    nvgFill(vg)

    for i = 1, 3 do
        local y = screenH * (0.32 + i * 0.08)
        nvgBeginPath(vg)
        nvgMoveTo(vg, 0, y)
        nvgLineTo(vg, screenW, y)
        nvgStrokeColor(vg, nvgRGBA(120, 220, 255, 18))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end
end

function VFX._showQuip()
    -- 从池子中选一条，不和上次重复
    local idx = quip.lastIndex
    local attempts = 0
    while idx == quip.lastIndex and attempts < 5 do
        idx = math.random(1, #quip.pool)
        attempts = attempts + 1
    end
    quip.lastIndex = idx
    quip.text = quip.pool[idx]
    quip.active = true
    quip.timer = quip.duration
end

return VFX
