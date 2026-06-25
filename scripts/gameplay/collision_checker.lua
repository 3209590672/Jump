-- ============================================================================
-- 碰撞检测器
-- 实心平台碰撞：玩家不能从任何方向穿过平台
--
-- 碰撞体示意：
--   玩家 AABB：
--     left   = position.x - width/2
--     right  = position.x + width/2
--     bottom = position.y
--     top    = position.y + height
--
--   平台 AABB：
--     left   = platform.x
--     right  = platform.x + platform.w
--     bottom = platform.y
--     top    = platform.y + platform.h
--
-- 碰撞处理顺序：
--   1. 先积分位置（在 player_controller 中完成）
--   2. 逐平台检测 AABB 重叠
--   3. 计算最小分离轴（penetration 最小的方向推出）
--   4. 根据推出方向修正速度
-- ============================================================================
local playerConfig = require("config.player_config")
local EventBus = require("core.event_bus")

local CollisionChecker = {}

--- 解析所有平台碰撞（每帧调用一次，在位置积分之后）
---@param player table
---@param platforms table[]
function CollisionChecker.resolvePlatforms(player, platforms)
    local wasGrounded = player.isGrounded
    player.isGrounded = false

    local halfW = player.width * 0.5

    for _, platform in ipairs(platforms) do
        -- 玩家 AABB
        local pLeft = player.position.x - halfW
        local pRight = player.position.x + halfW
        local pBottom = player.position.y
        local pTop = player.position.y + player.height

        -- 平台 AABB
        local platLeft = platform.x
        local platRight = platform.x + platform.w
        local platBottom = platform.y
        local platTop = platform.y + platform.h

        -- AABB 重叠检测
        local overlapX = pRight > platLeft and pLeft < platRight
        local overlapY = pTop > platBottom and pBottom < platTop

        if overlapX and overlapY then
            -- 计算四个方向的穿透深度
            local penetrateFromTop = pTop - platBottom      -- 玩家头顶穿入平台底部
            local penetrateFromBottom = platTop - pBottom   -- 玩家脚底穿入平台顶部（落地）
            local penetrateFromLeft = pRight - platLeft     -- 玩家右侧穿入平台左侧
            local penetrateFromRight = platRight - pLeft    -- 玩家左侧穿入平台右侧

            -- 找最小穿透方向（推出距离最短的方向）
            local minPen = penetrateFromBottom
            local resolveDir = "bottom"  -- 从平台顶部推出（落地）

            if penetrateFromTop < minPen then
                minPen = penetrateFromTop
                resolveDir = "top"  -- 从平台底部推出（顶头）
            end
            if penetrateFromLeft < minPen then
                minPen = penetrateFromLeft
                resolveDir = "left"  -- 从平台左侧推出
            end
            if penetrateFromRight < minPen then
                minPen = penetrateFromRight
                resolveDir = "right"  -- 从平台右侧推出
            end

            -- 根据方向修正位置和速度
            if resolveDir == "bottom" then
                -- 落地：推到平台顶部
                player.position.y = platTop
                if player.velocity.y < 0 then
                    player.velocity.y = 0
                end
                player.isGrounded = true
                player.airShotsUsed = 0
                if not wasGrounded then
                    EventBus.emit("player_land", { platformId = platform.id })
                end

            elseif resolveDir == "top" then
                -- 顶头：推到平台底部下方
                player.position.y = platBottom - player.height
                if player.velocity.y > 0 then
                    player.velocity.y = 0
                end

            elseif resolveDir == "left" then
                -- 撞平台左侧：推到平台左边
                player.position.x = platLeft - halfW
                if player.velocity.x > 0 then
                    player.velocity.x = 0
                end

            elseif resolveDir == "right" then
                -- 撞平台右侧：推到平台右边
                player.position.x = platRight + halfW
                if player.velocity.x < 0 then
                    player.velocity.x = 0
                end
            end
        end
    end

    -- 持续站立检测（防止浮点误差导致站着的玩家突然脱离平台）
    -- 仅在：上帧站着 + 本帧没检测到落地 + 没有向上速度 时触发
    if wasGrounded and not player.isGrounded and player.velocity.y <= 0 then
        for _, platform in ipairs(platforms) do
            local platTop = platform.y + platform.h
            local pLeft = player.position.x - halfW
            local pRight = player.position.x + halfW

            local onTop = math.abs(player.position.y - platTop) < 4
            local hOverlap = pRight > platform.x and pLeft < (platform.x + platform.w)

            if onTop and hOverlap then
                player.position.y = platTop
                player.velocity.y = 0
                player.isGrounded = true
                player.airShotsUsed = 0
                return
            end
        end
    end
end

return CollisionChecker
