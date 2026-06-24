-- ============================================================================
-- 极简事件总线
-- 用于模块间解耦通信，避免模块之间直接 require 互相引用
--
-- 用法：
--   EventBus.on("player_fire", function(data) ... end)
--   EventBus.emit("player_fire", { x = 100, y = 200 })
--   EventBus.clear()  -- 清空所有监听（场景切换时调用）
--
-- 当前已注册事件：
--   "player_fire"    → 开火时触发，data = {x, y, aimX, aimY}
--   "player_land"    → 落地时触发，data = {platformId}
--   "player_respawn" → 重生时触发，data = {count}
--   "level_finish"   → 通关时触发，data = {time, respawnCount}
-- ============================================================================
local EventBus = {}

---@type table<string, function[]>
local listeners = {}

--- 注册事件监听
---@param eventName string 事件名
---@param callback function 回调函数，参数为 data table
function EventBus.on(eventName, callback)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], callback)
end

--- 触发事件，通知所有监听者
---@param eventName string 事件名
---@param data table|nil 附带数据
function EventBus.emit(eventName, data)
    local cbs = listeners[eventName]
    if not cbs then return end
    for i = 1, #cbs do
        cbs[i](data)
    end
end

--- 清空所有监听（切换场景或重置时调用）
function EventBus.clear()
    listeners = {}
end

return EventBus
