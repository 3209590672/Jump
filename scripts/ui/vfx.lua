-- ============================================================================
-- 视觉反馈模块（VFX）
-- 手感反馈：开火闪光 / 飞行拖尾 / 落地飞尘 / 重生闪屏
--
-- 设计原则：
--   - 纯视觉，不影响游戏逻辑
--   - 所有效果用 NanoVG 绘制，无外部资源依赖
--   - 通过 EventBus 监听事件自动触发
-- ============================================================================
local Viewport = require("core.viewport")
local EventBus = require("core.event_bus")

local VFX = {}

-- ===== 开火闪光 =====
local muzzleFlash = {
    active = false,
    timer = 0,
    duration = 0.08,
    x = 0, y = 0,
    aimX = 0, aimY = 0,
}

-- ===== 飞行拖尾 =====
local trail = {
    points = {},
    maxPoints = 12,
    spawnInterval = 0.02,
    spawnTimer = 0,
    maxAge = 0.3,
}

-- ===== 落地飞尘 =====
local landingDust = {
    particles = {},   -- {x, y, vx, vy, age, maxAge}
}

-- ===== 重生闪屏 =====
local respawnFlash = {
    active = false,
    timer = 0,
    duration = 0.25,
}

--- 初始化：注册事件监听
function VFX.init()
    EventBus.on("player_fire", function(data)
        muzzleFlash.active = true
        muzzleFlash.timer = muzzleFlash.duration
        muzzleFlash.x = data.x
        muzzleFlash.y = data.y
        muzzleFlash.aimX = data.aimX
        muzzleFlash.aimY = data.aimY
    end)

    EventBus.on("player_land", function(data)
        VFX._spawnLandingDust(data)
    end)

    EventBus.on("player_respawn", function(data)
        respawnFlash.active = true
        respawnFlash.timer = respawnFlash.duration
    end)
end

-- ===== 落地飞尘生成 =====
function VFX._spawnLandingDust(data)
    -- 无法获取精确位置时用 0,0（实际绘制时用 player 位置）
    -- 标记需要在下一帧从 player 读取位置
    landingDust._pending = true
end

--- 每帧更新
---@param player table
---@param dt number
function VFX.update(player, dt)
    -- 开火闪光
    if muzzleFlash.active then
        muzzleFlash.timer = muzzleFlash.timer - dt
        if muzzleFlash.timer <= 0 then
            muzzleFlash.active = false
        end
    end

    -- 重生闪屏
    if respawnFlash.active then
        respawnFlash.timer = respawnFlash.timer - dt
        if respawnFlash.timer <= 0 then
            respawnFlash.active = false
        end
    end

    -- 落地飞尘：落地事件后从 player 位置生成粒子
    if landingDust._pending and player.isGrounded then
        landingDust._pending = false
        local px = player.position.x
        local py = player.position.y
        for i = 1, 6 do
            local angle = math.random() * math.pi  -- 0~π（向上扇形）
            local speed = 40 + math.random() * 60
            table.insert(landingDust.particles, {
                x = px + (math.random() - 0.5) * player.width * 0.6,
                y = py,
                vx = math.cos(angle) * speed * (math.random() > 0.5 and 1 or -1),
                vy = math.sin(angle) * speed * 0.5,
                age = 0,
                maxAge = 0.2 + math.random() * 0.15,
            })
        end
    end

    -- 更新落地飞尘粒子
    local i = 1
    while i <= #landingDust.particles do
        local p = landingDust.particles[i]
        p.age = p.age + dt
        if p.age >= p.maxAge then
            table.remove(landingDust.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy - 100 * dt  -- 微重力下落
            i = i + 1
        end
    end

    -- 飞行拖尾
    if not player.isGrounded then
        trail.spawnTimer = trail.spawnTimer + dt
        if trail.spawnTimer >= trail.spawnInterval then
            trail.spawnTimer = 0
            table.insert(trail.points, {
                x = player.position.x,
                y = player.position.y + player.height * 0.5,
                age = 0,
            })
            if #trail.points > trail.maxPoints then
                table.remove(trail.points, 1)
            end
        end
    else
        trail.spawnTimer = 0
    end

    -- 老化拖尾点
    local j = 1
    while j <= #trail.points do
        trail.points[j].age = trail.points[j].age + dt
        if trail.points[j].age >= trail.maxAge then
            table.remove(trail.points, j)
        else
            j = j + 1
        end
    end
end

--- 绘制所有 VFX
---@param vg userdata
---@param player table
function VFX.draw(vg, player)
    VFX.drawTrail(vg)
    VFX.drawLandingDust(vg)
    VFX.drawMuzzleFlash(vg)
    VFX.drawRespawnFlash(vg)
end

--- 开火闪光
function VFX.drawMuzzleFlash(vg)
    if not muzzleFlash.active then return end

    local offsetDist = 20
    local fx = muzzleFlash.x + muzzleFlash.aimX * offsetDist
    local fy = muzzleFlash.y + muzzleFlash.aimY * offsetDist
    local sx, sy = Viewport.worldToScreen(fx, fy)

    local t = muzzleFlash.timer / muzzleFlash.duration
    local alpha = math.floor(255 * t)
    local radius = Viewport.scaleSize(8 + 6 * (1 - t))

    -- 外圈光晕
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, radius * 1.5)
    nvgFillColor(vg, nvgRGBA(255, 200, 80, math.floor(alpha * 0.3)))
    nvgFill(vg)

    -- 内圈亮点
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, radius * 0.6)
    nvgFillColor(vg, nvgRGBA(255, 255, 220, alpha))
    nvgFill(vg)
end

--- 飞行拖尾
function VFX.drawTrail(vg)
    for _, pt in ipairs(trail.points) do
        local t = 1 - (pt.age / trail.maxAge)
        local alpha = math.floor(150 * t)
        local radius = Viewport.scaleSize(3 * t + 1)
        local sx, sy = Viewport.worldToScreen(pt.x, pt.y)

        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, radius)
        nvgFillColor(vg, nvgRGBA(120, 180, 255, alpha))
        nvgFill(vg)
    end
end

--- 落地飞尘
function VFX.drawLandingDust(vg)
    for _, p in ipairs(landingDust.particles) do
        local t = 1 - (p.age / p.maxAge)
        local alpha = math.floor(180 * t)
        local radius = Viewport.scaleSize(2.5 * t + 0.5)
        local sx, sy = Viewport.worldToScreen(p.x, p.y)

        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, radius)
        nvgFillColor(vg, nvgRGBA(200, 210, 230, alpha))
        nvgFill(vg)
    end
end

--- 重生闪屏（屏幕边缘红色闪烁）
function VFX.drawRespawnFlash(vg)
    if not respawnFlash.active then return end

    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    local t = respawnFlash.timer / respawnFlash.duration
    local alpha = math.floor(80 * t)

    -- 四边渐变边框（从边缘向内淡出）
    local borderSize = 40

    -- 上
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, borderSize)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, 0, borderSize,
        nvgRGBA(255, 60, 60, alpha), nvgRGBA(255, 60, 60, 0)))
    nvgFill(vg)

    -- 下
    nvgBeginPath(vg)
    nvgRect(vg, 0, screenH - borderSize, screenW, borderSize)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, screenH - borderSize, 0, screenH,
        nvgRGBA(255, 60, 60, 0), nvgRGBA(255, 60, 60, alpha)))
    nvgFill(vg)

    -- 左
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, borderSize, screenH)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, borderSize, 0,
        nvgRGBA(255, 60, 60, alpha), nvgRGBA(255, 60, 60, 0)))
    nvgFill(vg)

    -- 右
    nvgBeginPath(vg)
    nvgRect(vg, screenW - borderSize, 0, borderSize, screenH)
    nvgFillPaint(vg, nvgLinearGradient(vg, screenW - borderSize, 0, screenW, 0,
        nvgRGBA(255, 60, 60, 0), nvgRGBA(255, 60, 60, alpha)))
    nvgFill(vg)
end

return VFX
