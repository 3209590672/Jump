-- ============================================================================
-- 视觉反馈模块（VFX）
-- 最低成本手感反馈：开火闪光 + 飞行拖尾
--
-- 设计原则：
--   - 纯视觉，不影响游戏逻辑
--   - 所有效果用 NanoVG 绘制，无外部资源依赖
--   - 通过 EventBus 监听事件自动触发
--
-- 使用方式：
--   VFX.init()                -- Start 中调用，注册事件
--   VFX.update(player, dt)   -- 每帧更新
--   VFX.draw(vg, player)     -- NanoVGRender 中调用
-- ============================================================================
local Viewport = require("core.viewport")
local EventBus = require("core.event_bus")

local VFX = {}

-- ===== 开火闪光 =====
local muzzleFlash = {
    active = false,
    timer = 0,
    duration = 0.08,    -- 闪光持续时间（秒）
    x = 0,              -- 闪光位置（逻辑坐标）
    y = 0,
    aimX = 0,           -- 枪口方向
    aimY = 0,
}

-- ===== 飞行拖尾 =====
local trail = {
    points = {},        -- 历史位置 {x, y, age}
    maxPoints = 12,     -- 最多保留多少个拖尾点
    spawnInterval = 0.02, -- 每隔多久记录一个点（秒）
    spawnTimer = 0,
    maxAge = 0.3,       -- 每个点的最大生存时间（秒）
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
end

--- 每帧更新
---@param player table
---@param dt number
function VFX.update(player, dt)
    -- 更新闪光计时
    if muzzleFlash.active then
        muzzleFlash.timer = muzzleFlash.timer - dt
        if muzzleFlash.timer <= 0 then
            muzzleFlash.active = false
        end
    end

    -- 更新拖尾：只在空中时记录位置
    if not player.isGrounded then
        trail.spawnTimer = trail.spawnTimer + dt
        if trail.spawnTimer >= trail.spawnInterval then
            trail.spawnTimer = 0
            table.insert(trail.points, {
                x = player.position.x,
                y = player.position.y + player.height * 0.5,
                age = 0,
            })
            -- 限制点数
            if #trail.points > trail.maxPoints then
                table.remove(trail.points, 1)
            end
        end
    else
        -- 落地时清空拖尾
        trail.spawnTimer = 0
    end

    -- 老化所有点
    local i = 1
    while i <= #trail.points do
        trail.points[i].age = trail.points[i].age + dt
        if trail.points[i].age >= trail.maxAge then
            table.remove(trail.points, i)
        else
            i = i + 1
        end
    end
end

--- 绘制所有 VFX
---@param vg userdata
---@param player table
function VFX.draw(vg, player)
    VFX.drawTrail(vg)
    VFX.drawMuzzleFlash(vg)
end

--- 绘制开火闪光
function VFX.drawMuzzleFlash(vg)
    if not muzzleFlash.active then return end

    -- 闪光位置：玩家中心 + 枪口方向偏移
    local offsetDist = 20
    local fx = muzzleFlash.x + muzzleFlash.aimX * offsetDist
    local fy = muzzleFlash.y + muzzleFlash.aimY * offsetDist

    local sx, sy = Viewport.worldToScreen(fx, fy)

    -- 透明度随时间衰减
    local t = muzzleFlash.timer / muzzleFlash.duration  -- 1→0
    local alpha = math.floor(255 * t)
    local radius = Viewport.scaleSize(8 + 6 * (1 - t))  -- 从小到大扩散

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

--- 绘制飞行拖尾
function VFX.drawTrail(vg)
    for _, pt in ipairs(trail.points) do
        local t = 1 - (pt.age / trail.maxAge)  -- 1→0（新→旧）
        local alpha = math.floor(150 * t)
        local radius = Viewport.scaleSize(3 * t + 1)

        local sx, sy = Viewport.worldToScreen(pt.x, pt.y)

        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, radius)
        nvgFillColor(vg, nvgRGBA(120, 180, 255, alpha))
        nvgFill(vg)
    end
end

return VFX
