-- ============================================================================
-- 轨迹预测模块（解耦独立模块）
-- 模拟开火后的物理轨迹并绘制为点状抛物线
--
-- 职责：
--   - 根据当前瞄准方向模拟反冲后的飞行路线
--   - 使用与游戏完全相同的物理参数（重力、反冲力、限速）
--   - 检测轨迹是否碰到平台，标记预测落点
--
-- 解耦设计：
--   - 通过 trajectory_config.lua 控制开关和所有视觉参数
--   - 不修改任何游戏状态（纯只读模拟）
--   - 由外部调用 draw()，不自行订阅事件
--   - 依赖注入：平台数据和物理参数从外部传入或读取 config
--
-- 使用方式：
--   local TrajectoryPreview = require("ui.trajectory_preview")
--   TrajectoryPreview.draw(vg, player, aimDir, platforms)
-- ============================================================================
local Viewport = require("core.viewport")
local trajConfig = require("config.trajectory_config")
local playerConfig = require("config.player_config")
local weaponConfig = require("config.weapon_config")

local TrajectoryPreview = {}

--- 绘制轨迹预测（外部调用入口）
-- 如果 config.enabled = false 则直接返回，不做任何绘制
---@param vg userdata NanoVG 上下文
---@param player table 玩家当前状态（只读，不修改）
---@param aimDir table {x, y} 当前瞄准方向
---@param platforms table[] 平台列表（用于碰撞预测）
function TrajectoryPreview.draw(vg, player, aimDir, platforms)
    -- 总开关
    if not trajConfig.enabled then return end

    -- 只在地面上、且尚未开火时显示轨迹（第一次反冲辅助瞄准）
    -- 空中不显示：空中补枪靠手感，不靠辅助线
    if not player.isGrounded then return end

    local weapon = weaponConfig.calibratePistol

    -- 冷却中不显示（刚开完火还没离地的瞬间）
    if player.fireCooldownLeft > 0 then return end

    -- 模拟初始速度 = 当前速度 + 反冲冲量
    local simVx = player.velocity.x - aimDir.x * weapon.recoilPower
    local simVy = player.velocity.y - aimDir.y * weapon.recoilPower

    -- 反冲后限速（与 recoil_system.lua 逻辑一致）
    local speed = math.sqrt(simVx * simVx + simVy * simVy)
    if speed > weapon.maxSpeedAfterRecoil then
        local ratio = weapon.maxSpeedAfterRecoil / speed
        simVx = simVx * ratio
        simVy = simVy * ratio
    end

    -- 模拟起点：玩家底部中心
    local simX = player.position.x
    local simY = player.position.y

    -- 逐步模拟并绘制
    for i = 1, trajConfig.totalSteps do
        -- 重力（与 player_controller 相同的分离重力）
        local g = simVy > 0 and playerConfig.gravity or playerConfig.fallGravity
        simVy = simVy - g * trajConfig.simDt

        -- 下落限速
        simVy = math.max(simVy, -playerConfig.maxFallSpeed)

        -- 位置积分
        simX = simX + simVx * trajConfig.simDt
        simY = simY + simVy * trajConfig.simDt

        -- 平台碰撞预测（简化：点穿过平台顶即视为落地）
        local hitPlatform = false
        for _, p in ipairs(platforms) do
            local pTop = p.y + p.h
            if simX >= p.x and simX <= p.x + p.w then
                if simY <= pTop and simY >= pTop - trajConfig.platformHitTolerance and simVy <= 0 then
                    simY = pTop
                    hitPlatform = true
                    break
                end
            end
        end

        -- 绘制轨迹点（按间隔）
        if i % trajConfig.dotInterval == 0 then
            local sx, sy = Viewport.worldToScreen(simX, simY)
            local alpha = math.max(trajConfig.alphaMin, trajConfig.alphaStart - i * trajConfig.alphaDecay)
            local dotR = Viewport.scaleSize(trajConfig.dotRadius)

            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, dotR)
            nvgFillColor(vg, nvgRGBA(
                trajConfig.dotColorR,
                trajConfig.dotColorG,
                trajConfig.dotColorB,
                alpha
            ))
            nvgFill(vg)
        end

        -- 落到平台或掉出画布 → 画落点标记并停止
        if hitPlatform or simY < -100 then
            local lx, ly = Viewport.worldToScreen(simX, simY)
            nvgBeginPath(vg)
            nvgCircle(vg, lx, ly, Viewport.scaleSize(trajConfig.landingDotRadius))
            nvgFillColor(vg, nvgRGBA(
                trajConfig.landingColorR,
                trajConfig.landingColorG,
                trajConfig.landingColorB,
                trajConfig.landingAlpha
            ))
            nvgFill(vg)
            break
        end
    end
end

return TrajectoryPreview
