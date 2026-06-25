-- ============================================================================
-- 触发区域系统
-- 玩家走到某个位置时触发一次性事件（对话、拾取、开门等）
--
-- 使用方式：
--   TriggerSystem.load(triggers)          -- 加载关卡触发点列表
--   TriggerSystem.update(player)          -- 每帧检测
--   TriggerSystem.reset()                 -- 重置所有触发（重开时）
--
-- 触发点格式：
--   { id = "pickup_gun", x = 300, y = 60, w = 60, h = 80, once = true }
-- ============================================================================
local EventBus = require("core.event_bus")

local TriggerSystem = {}

local triggers = {}       -- 当前关卡的触发点列表
local triggered = {}      -- 已触发的 id 集合

--- 加载触发点（切换关卡时调用）
---@param list table[] 触发点列表
function TriggerSystem.load(list)
    triggers = list or {}
    triggered = {}
end

--- 重置所有触发状态（重开时调用）
function TriggerSystem.reset()
    triggered = {}
end

--- 每帧检测玩家是否进入触发区域
---@param player table
function TriggerSystem.update(player)
    local halfW = player.width * 0.5
    local pLeft = player.position.x - halfW
    local pRight = player.position.x + halfW
    local pBottom = player.position.y
    local pTop = player.position.y + player.height

    for _, t in ipairs(triggers) do
        -- 跳过已触发的一次性触发点
        if t.once and triggered[t.id] then
            goto continue
        end

        -- AABB 重叠检测
        local tRight = t.x + t.w
        local tTop = t.y + t.h
        local overlap = pRight > t.x and pLeft < tRight and pTop > t.y and pBottom < tTop

        if overlap then
            triggered[t.id] = true
            EventBus.emit("trigger_enter", { id = t.id })
        end

        ::continue::
    end
end

return TriggerSystem
