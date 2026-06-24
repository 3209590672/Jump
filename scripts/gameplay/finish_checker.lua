-- ============================================================================
-- 终点检测器
-- 检测玩家是否进入终点区域，触发通关冻结
--
-- 验收要求（Harness F-001）：
--   - 角色冻结，停止接受玩法输入
--   - 计时停止
--   - 显示完成时间和事故次数
--   - 开火无效，R 可以重新开始
--   - 不重复触发（finished 标记防止闪烁）
-- ============================================================================
local EventBus = require("core.event_bus")

local FinishChecker = {}

--- 检测玩家是否到达终点（每帧调用）
-- 使用 AABB 矩形重叠判定
---@param player table
---@param finish table {x, y, w, h} 终点区域
---@param levelState table
function FinishChecker.update(player, finish, levelState)
    -- 已通关则不再检测（防止重复触发）
    if levelState.finished then return end

    -- 计算玩家 AABB（position.y 为底部，position.x 为中心）
    local halfW = player.width * 0.5
    local playerLeft = player.position.x - halfW
    local playerRight = player.position.x + halfW
    local playerBottom = player.position.y
    local playerTop = player.position.y + player.height

    -- 终点 AABB
    local finishLeft = finish.x
    local finishRight = finish.x + finish.w
    local finishBottom = finish.y
    local finishTop = finish.y + finish.h

    -- 两个矩形是否重叠
    local overlapX = playerRight > finishLeft and playerLeft < finishRight
    local overlapY = playerTop > finishBottom and playerBottom < finishTop

    if overlapX and overlapY then
        -- 标记通关（main.lua 会据此冻结玩法输入）
        levelState.finished = true
        player.finished = true
        EventBus.emit("level_finish", {
            time = levelState.elapsedTime,
            respawnCount = player.respawnCount,
        })
        print(string.format("[Finish] Time: %.2fs, Deaths: %d", levelState.elapsedTime, player.respawnCount))
    end
end

return FinishChecker
