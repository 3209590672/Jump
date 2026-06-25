-- ============================================================================
-- 重生系统
-- 两种重生模式：
--   1. 掉落重生：不重置计时，事故次数+1（惩罚轻，鼓励重试）
--   2. R键重开：清零一切，完全重新挑战
--
-- 验收要求（Harness C-003, R-001, R-002）：
--   - 掉落后立即回到起点，无延迟
--   - 掉落不重置计时（保持紧迫感）
--   - R键重置计时和事故（提供"完美挑战"的选择）
--   - 重生后速度归零，补枪次数归零
-- ============================================================================
local EventBus = require("core.event_bus")

local RespawnSystem = {}

--- 重置玩家位置和运动状态（内部方法）
-- 将玩家传送回出生点，清除所有运动学状态
---@param player table
---@param level table 关卡配置
function RespawnSystem.resetPlayerTransform(player, level)
    player.position.x = level.spawn.x
    player.position.y = level.spawn.y
    player.previousPosition.x = level.spawn.x
    player.previousPosition.y = level.spawn.y
    player.velocity.x = 0
    player.velocity.y = 0
    player.isGrounded = false      -- 下一帧会自动检测到平台并设为 true
    player.airShotsUsed = 0
    player.fireCooldownLeft = 0.15 -- 重生后短冷却，防止输入缓冲导致立即开火
    player.finished = false
end

--- 掉落后重生（不重置计时，增加事故次数）
---@param player table
---@param level table
function RespawnSystem.respawnAfterFall(player, level)
    RespawnSystem.resetPlayerTransform(player, level)
    player.respawnCount = player.respawnCount + 1
    EventBus.emit("player_respawn", { count = player.respawnCount })
    print("[Respawn] Fall respawn, deaths: " .. player.respawnCount)
end

--- R键重开（重置计时和事故次数，完全重新开始）
---@param player table
---@param level table
---@param levelState table
function RespawnSystem.restartRun(player, level, levelState)
    RespawnSystem.resetPlayerTransform(player, level)
    player.respawnCount = 0
    if levelState then
        levelState.elapsedTime = 0
        levelState.finished = false
    end
    EventBus.emit("player_respawn", { count = 0 })
    print("[Respawn] Full restart")
end

--- 每帧检测是否掉落到判定线以下
---@param player table
---@param level table
---@param levelState table
function RespawnSystem.update(player, level, levelState)
    if player.position.y < level.fallY then
        RespawnSystem.respawnAfterFall(player, level)
    end
end

return RespawnSystem
