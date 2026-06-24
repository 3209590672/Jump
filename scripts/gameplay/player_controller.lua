-- ============================================================================
-- 玩家控制器
-- 负责纯运动学计算，不处理输入、碰撞或游戏状态
-- 职责：水平移动、重力、速度限制、位置积分
--
-- 设计原则：
--   - 分离上升/下落重力：上升轻盈，下落扎实
--   - 地面有加速+摩擦，空中只有微弱控制
--   - 速度上限防止反冲叠加后过快
-- ============================================================================
local playerConfig = require("config.player_config")

local PlayerController = {}

--- 更新开火冷却计时器
---@param player table
---@param dt number 帧间隔（秒）
function PlayerController.updateCooldown(player, dt)
    if player.fireCooldownLeft > 0 then
        player.fireCooldownLeft = player.fireCooldownLeft - dt
        if player.fireCooldownLeft < 0 then
            player.fireCooldownLeft = 0
        end
    end
end

--- 保存上一帧位置（碰撞穿越判定需要比较两帧位置）
---@param player table
function PlayerController.savePreviousPosition(player)
    player.previousPosition.x = player.position.x
    player.previousPosition.y = player.position.y
end

--- 地面/空中水平移动
-- 地面：目标速度加速 + 松手摩擦
-- 空中：微弱加速度调整（不能完全控制方向）
---@param player table
---@param moveAxis number -1/0/1
---@param dt number
function PlayerController.applyGroundMove(player, moveAxis, dt)
    if player.isGrounded then
        -- 地面移动：加速到目标速度
        local targetVx = moveAxis * playerConfig.moveSpeed
        player.velocity.x = PlayerController.moveTowards(
            player.velocity.x, targetVx,
            playerConfig.groundAcceleration * dt
        )
        -- 松手时施加摩擦使角色停下
        if math.abs(moveAxis) < 0.01 then
            player.velocity.x = PlayerController.moveTowards(
                player.velocity.x, 0,
                playerConfig.groundFriction * dt
            )
        end
    else
        -- 空中：只有微弱调整能力，无法急停或反向
        player.velocity.x = player.velocity.x + moveAxis * playerConfig.airControlAcceleration * dt
    end
end

--- 施加重力
-- 上升时用较小重力（飞得远），下落时用较大重力（落得快）
---@param player table
---@param dt number
function PlayerController.applyGravity(player, dt)
    local g = player.velocity.y > 0 and playerConfig.gravity or playerConfig.fallGravity
    player.velocity.y = player.velocity.y - g * dt
end

--- 限制速度在安全范围内
-- 防止反冲叠加或极端情况导致速度过大
---@param player table
function PlayerController.clampVelocity(player)
    -- 水平限速
    player.velocity.x = PlayerController.clamp(
        player.velocity.x,
        -playerConfig.maxHorizontalSpeed,
        playerConfig.maxHorizontalSpeed
    )
    -- 下落限速（防止高速穿透平台）
    player.velocity.y = math.max(player.velocity.y, -playerConfig.maxFallSpeed)
end

--- 速度积分到位置（欧拉积分 position += velocity * dt）
---@param player table
---@param dt number
function PlayerController.integrate(player, dt)
    player.position.x = player.position.x + player.velocity.x * dt
    player.position.y = player.position.y + player.velocity.y * dt
end

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 将 current 值向 target 线性趋近，最大变化量 maxDelta
function PlayerController.moveTowards(current, target, maxDelta)
    if math.abs(target - current) <= maxDelta then
        return target
    end
    if target > current then
        return current + maxDelta
    else
        return current - maxDelta
    end
end

--- 将 value 钳制在 [minVal, maxVal] 范围内
function PlayerController.clamp(value, minVal, maxVal)
    if value < minVal then return minVal end
    if value > maxVal then return maxVal end
    return value
end

return PlayerController
