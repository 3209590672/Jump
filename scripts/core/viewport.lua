-- ============================================================================
-- 视口转换模块（支持相机跟随）
-- 负责逻辑坐标（Y向上）与屏幕坐标（Y向下）之间的转换
--
-- 工作原理：
--   关卡地图可以比屏幕大。viewW × viewH 是"相机可见区域"大小（固定 960×720），
--   相机中心跟随玩家移动，clamp 在地图边界内。
--   屏幕始终显示 viewW × viewH 这么大的区域。
--
-- 调用时机：
--   启动时调用 Viewport.init(mapW, mapH)
--   每帧调用 Viewport.update(screenW, screenH)
--   每帧调用 Viewport.follow(targetX, targetY) 让相机跟随玩家
--   绘制时用 Viewport.worldToScreen(x, y) 转换坐标
--   鼠标输入时用 Viewport.screenToWorld(sx, sy) 反算逻辑坐标
-- ============================================================================
local Viewport = {
    -- 地图总尺寸（关卡可以很大）
    mapW = 960,
    mapH = 720,

    -- 相机可见区域尺寸（固定，等同于旧 canvasW/canvasH）
    viewW = 960,
    viewH = 720,

    -- 相机左下角在世界中的位置（由 follow 更新）
    camX = 0,
    camY = 0,

    -- 屏幕适配参数
    scale = 1,
    offsetX = 0,
    offsetY = 0,

    -- 兼容旧接口
    canvasW = 960,
    canvasH = 720,
}

--- 初始化地图尺寸
---@param mapW number 地图总宽度（逻辑像素）
---@param mapH number 地图总高度（逻辑像素）
---@param viewW number|nil 可见区域宽度（默认 960）
---@param viewH number|nil 可见区域高度（默认 720）
function Viewport.init(mapW, mapH, viewW, viewH)
    Viewport.mapW = mapW
    Viewport.mapH = mapH
    Viewport.viewW = viewW or 960
    Viewport.viewH = viewH or 720
    -- 兼容旧代码
    Viewport.canvasW = Viewport.viewW
    Viewport.canvasH = Viewport.viewH
    -- 相机初始位置
    Viewport.camX = 0
    Viewport.camY = 0
end

--- 根据屏幕尺寸更新缩放（每帧调用）
---@param screenW number
---@param screenH number
function Viewport.update(screenW, screenH)
    local scaleX = screenW / Viewport.viewW
    local scaleY = screenH / Viewport.viewH
    Viewport.scale = math.min(scaleX, scaleY)
    Viewport.offsetX = (screenW - Viewport.viewW * Viewport.scale) * 0.5
    Viewport.offsetY = (screenH - Viewport.viewH * Viewport.scale) * 0.5
end

--- 相机跟随目标（每帧在 update 之后调用）
-- 将相机中心对准目标，clamp 在地图边界内
---@param targetX number 跟随目标的 X（逻辑坐标）
---@param targetY number 跟随目标的 Y（逻辑坐标）
function Viewport.follow(targetX, targetY)
    -- 相机中心 = 目标位置
    local cx = targetX - Viewport.viewW * 0.5
    local cy = targetY - Viewport.viewH * 0.5

    -- Clamp：不超出地图边界
    cx = math.max(0, math.min(cx, Viewport.mapW - Viewport.viewW))
    cy = math.max(0, math.min(cy, Viewport.mapH - Viewport.viewH))

    Viewport.camX = cx
    Viewport.camY = cy
end

--- 逻辑世界坐标 → 屏幕坐标（NanoVG 绘制用）
---@param x number 逻辑 X
---@param y number 逻辑 Y（向上为正）
---@return number, number 屏幕 sx, sy
function Viewport.worldToScreen(x, y)
    -- 先减去相机偏移，得到相对于视口的坐标
    local relX = x - Viewport.camX
    local relY = y - Viewport.camY

    local sx = Viewport.offsetX + relX * Viewport.scale
    -- Y 翻转：视口内 Y 向上 → 屏幕 Y 向下
    local sy = Viewport.offsetY + (Viewport.viewH - relY) * Viewport.scale
    return sx, sy
end

--- 屏幕坐标 → 逻辑世界坐标（鼠标输入用）
---@param sx number 屏幕 X
---@param sy number 屏幕 Y
---@return number, number 逻辑 x, y
function Viewport.screenToWorld(sx, sy)
    local relX = (sx - Viewport.offsetX) / Viewport.scale
    local relY = Viewport.viewH - ((sy - Viewport.offsetY) / Viewport.scale)
    -- 加上相机偏移还原到世界坐标
    return relX + Viewport.camX, relY + Viewport.camY
end

--- 将逻辑尺寸转换为屏幕像素尺寸
---@param size number
---@return number
function Viewport.scaleSize(size)
    return size * Viewport.scale
end

return Viewport
