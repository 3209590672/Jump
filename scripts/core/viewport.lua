-- ============================================================================
-- 视口转换模块
-- 负责逻辑坐标（960×720，Y向上）与屏幕坐标（Y向下）之间的转换
--
-- 工作原理：
--   物理屏幕可能是任意尺寸（如 1920×1080），本模块计算一个等比缩放 + 居中偏移，
--   使 960×720 的逻辑画布总是完整显示在屏幕中央（letterbox/pillarbox）。
--
-- 调用时机：
--   每帧开头调用 Viewport.update(screenW, screenH)
--   绘制时用 Viewport.worldToScreen(x, y) 转换坐标
--   鼠标输入时用 Viewport.screenToWorld(sx, sy) 反算逻辑坐标
-- ============================================================================
local Viewport = {
    canvasW = 960,     -- 逻辑画布宽度
    canvasH = 720,     -- 逻辑画布高度
    scale = 1,         -- 当前帧的缩放比（逻辑px → 屏幕px）
    offsetX = 0,       -- 水平居中偏移（屏幕像素）
    offsetY = 0,       -- 垂直居中偏移（屏幕像素）
}

--- 根据当前屏幕尺寸更新缩放和偏移（每帧调用一次）
---@param screenW number 物理屏幕宽度
---@param screenH number 物理屏幕高度
function Viewport.update(screenW, screenH)
    local scaleX = screenW / Viewport.canvasW
    local scaleY = screenH / Viewport.canvasH
    Viewport.scale = math.min(scaleX, scaleY)  -- 等比缩放，取较小值保证完整显示
    Viewport.offsetX = (screenW - Viewport.canvasW * Viewport.scale) * 0.5
    Viewport.offsetY = (screenH - Viewport.canvasH * Viewport.scale) * 0.5
end

--- 逻辑世界坐标 → 屏幕坐标（NanoVG 绘制用）
-- 逻辑坐标 Y 向上，屏幕坐标 Y 向下，此处做翻转
---@param x number 逻辑 X（左下角为 0）
---@param y number 逻辑 Y（向上为正）
---@return number, number 屏幕 sx, sy
function Viewport.worldToScreen(x, y)
    local sx = Viewport.offsetX + x * Viewport.scale
    -- canvasH - y：将 Y 轴翻转（逻辑 Y↑ → 屏幕 Y↓）
    local sy = Viewport.offsetY + (Viewport.canvasH - y) * Viewport.scale
    return sx, sy
end

--- 屏幕坐标 → 逻辑世界坐标（鼠标输入用）
---@param sx number 屏幕 X
---@param sy number 屏幕 Y
---@return number, number 逻辑 x, y
function Viewport.screenToWorld(sx, sy)
    local x = (sx - Viewport.offsetX) / Viewport.scale
    local y = Viewport.canvasH - ((sy - Viewport.offsetY) / Viewport.scale)
    return x, y
end

--- 将逻辑尺寸转换为屏幕像素尺寸（用于绘制宽高）
---@param size number 逻辑尺寸（px）
---@return number 屏幕尺寸（px）
function Viewport.scaleSize(size)
    return size * Viewport.scale
end

return Viewport
