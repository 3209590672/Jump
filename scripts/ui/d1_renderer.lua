-- ============================================================================
-- D1 白盒渲染器
-- 使用 NanoVG 绘制所有游戏世界可视元素（不含 HUD）
--
-- 绘制层级顺序（从后到前）：
--   1. 背景（深色 + 画布边界）
--   2. 掉落危险区（红色半透明）
--   3. 平台（灰色矩形 + 顶部高亮线）
--   4. 终点（黄色半透明区域）
--   5. 玩家（蓝色圆角矩形 + 眼睛）
--   6. 瞄准线（红色枪口方向 + 淡蓝反冲方向）
--
-- 所有坐标通过 Viewport.worldToScreen() 从逻辑坐标转为屏幕坐标
-- ============================================================================
local Viewport = require("core.viewport")
local levelConfig = require("config.level_d1_config")

local D1Renderer = {}

--- 绘制整个场景（每帧在 NanoVGRender 事件中调用）
---@param vg userdata NanoVG 上下文
---@param player table 玩家状态
---@param levelState table 关卡状态
---@param inputState table 输入状态（含 aimDir）
function D1Renderer.draw(vg, player, levelState, inputState)
    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    D1Renderer.drawBackground(vg, screenW, screenH)
    D1Renderer.drawFallZone(vg)
    D1Renderer.drawPlatforms(vg)
    D1Renderer.drawFinish(vg)
    D1Renderer.drawPlayer(vg, player)

    -- 通关后不显示瞄准线（冻结状态）
    if not levelState.finished then
        D1Renderer.drawAimLine(vg, player, inputState.aimDir)
    end
end

--- 背景：深色填充 + 画布边界框（帮助开发时确认适配区域）
function D1Renderer.drawBackground(vg, screenW, screenH)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(30, 32, 40, 255))
    nvgFill(vg)

    -- 960×720 画布边界（浅色虚线框）
    local x1, y1 = Viewport.worldToScreen(0, levelConfig.canvas.h)
    local x2, y2 = Viewport.worldToScreen(levelConfig.canvas.w, 0)
    nvgBeginPath(vg)
    nvgRect(vg, x1, y1, x2 - x1, y2 - y1)
    nvgStrokeColor(vg, nvgRGBA(60, 65, 80, 255))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
end

--- 掉落危险区：画布底部以下的红色半透明标记
function D1Renderer.drawFallZone(vg)
    local x1, y1 = Viewport.worldToScreen(0, 40)
    local x2, y2 = Viewport.worldToScreen(levelConfig.canvas.w, levelConfig.fallY)
    nvgBeginPath(vg)
    nvgRect(vg, x1, y1, x2 - x1, y2 - y1)
    nvgFillColor(vg, nvgRGBA(180, 40, 40, 60))
    nvgFill(vg)
end

--- 平台：灰色矩形 + 顶部白色高亮线（表示可着陆面）
function D1Renderer.drawPlatforms(vg)
    for _, p in ipairs(levelConfig.platforms) do
        -- 平台左上角屏幕坐标（worldToScreen 传入逻辑左上角 = x, y+h）
        local sx, sy = Viewport.worldToScreen(p.x, p.y + p.h)
        local sw = Viewport.scaleSize(p.w)
        local sh = Viewport.scaleSize(p.h)

        -- 平台本体
        nvgBeginPath(vg)
        nvgRect(vg, sx, sy, sw, sh)
        nvgFillColor(vg, nvgRGBA(100, 110, 130, 255))
        nvgFill(vg)

        -- 顶部高亮线（视觉提示着陆面）
        nvgBeginPath(vg)
        nvgMoveTo(vg, sx, sy)
        nvgLineTo(vg, sx + sw, sy)
        nvgStrokeColor(vg, nvgRGBA(180, 190, 210, 255))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end
end

--- 终点区域：黄色半透明填充 + 黄色边框
function D1Renderer.drawFinish(vg)
    local f = levelConfig.finish
    local sx, sy = Viewport.worldToScreen(f.x, f.y + f.h)
    local sw = Viewport.scaleSize(f.w)
    local sh = Viewport.scaleSize(f.h)

    nvgBeginPath(vg)
    nvgRect(vg, sx, sy, sw, sh)
    nvgFillColor(vg, nvgRGBA(220, 200, 50, 120))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 230, 80, 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
end

--- 玩家：蓝色圆角矩形 + 白色小眼睛
-- position.x = 水平中心，position.y = 底部
function D1Renderer.drawPlayer(vg, player)
    -- 计算屏幕坐标（左上角）
    local sx, sy = Viewport.worldToScreen(
        player.position.x - player.width * 0.5,   -- 逻辑左边缘
        player.position.y + player.height          -- 逻辑顶部
    )
    local sw = Viewport.scaleSize(player.width)
    local sh = Viewport.scaleSize(player.height)

    -- 身体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, sx, sy, sw, sh, 4)
    nvgFillColor(vg, nvgRGBA(80, 160, 255, 255))
    nvgFill(vg)

    -- 小眼睛（帮助判断朝向，后续可根据 aimDir 偏移）
    local eyeR = Viewport.scaleSize(4)
    local eyeX = sx + sw * 0.5
    local eyeY = sy + sh * 0.25
    nvgBeginPath(vg)
    nvgCircle(vg, eyeX, eyeY, eyeR)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
end

--- 瞄准线：红色实线（枪口方向）+ 淡蓝圆点（反冲方向）
-- 让玩家直观看到"开火后会朝哪飞"
function D1Renderer.drawAimLine(vg, player, aimDir)
    -- 玩家中心（逻辑坐标）
    local cx = player.position.x
    local cy = player.position.y + player.height * 0.5

    -- ===== 红色线：枪口方向（瞄准方向）=====
    local aimLen = 80  -- 瞄准线长度（逻辑像素）
    local endX = cx + aimDir.x * aimLen
    local endY = cy + aimDir.y * aimLen

    local sx1, sy1 = Viewport.worldToScreen(cx, cy)
    local sx2, sy2 = Viewport.worldToScreen(endX, endY)

    nvgBeginPath(vg)
    nvgMoveTo(vg, sx1, sy1)
    nvgLineTo(vg, sx2, sy2)
    nvgStrokeColor(vg, nvgRGBA(255, 80, 80, 200))
    nvgStrokeWidth(vg, 2.5)
    nvgStroke(vg)

    -- ===== 淡蓝线 + 圆点：反冲方向（玩家将飞向的方向）=====
    local recoilLen = 50
    local rEndX = cx - aimDir.x * recoilLen
    local rEndY = cy - aimDir.y * recoilLen
    local rsx, rsy = Viewport.worldToScreen(rEndX, rEndY)

    nvgBeginPath(vg)
    nvgMoveTo(vg, sx1, sy1)
    nvgLineTo(vg, rsx, rsy)
    nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 120))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 圆点终端（视觉锚点，表示"你会飞到这里附近"）
    local arrowSize = Viewport.scaleSize(8)
    nvgBeginPath(vg)
    nvgCircle(vg, rsx, rsy, arrowSize * 0.5)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 150))
    nvgFill(vg)
end

return D1Renderer
