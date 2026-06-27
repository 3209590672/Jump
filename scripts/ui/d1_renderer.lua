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
local visualConfig = require("config.visual_config")
local TrajectoryPreview = require("ui.trajectory_preview")

local D1Renderer = {}

-- 当前关卡数据（由外部通过 setLevel 注入，不再硬编码）
local levelConfig = nil

--- 设置当前关卡数据（切换关卡时调用）
---@param config table 关卡配置（需包含 canvas, platforms, finish, fallY）
function D1Renderer.setLevel(config)
    levelConfig = config
end

--- 绘制整个场景（每帧在 NanoVGRender 事件中调用）
---@param vg userdata NanoVG 上下文
---@param player table 玩家状态
---@param levelState table 关卡状态
---@param inputState table 输入状态（含 aimDir）
---@param opts table|nil {platforms = table[]|nil}
function D1Renderer.draw(vg, player, levelState, inputState, opts)
    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    D1Renderer.drawBackground(vg, screenW, screenH)
    D1Renderer.drawFallZone(vg)
    D1Renderer.drawPlatforms(vg, opts and opts.platforms or nil)
    D1Renderer.drawPickups(vg, player)
    D1Renderer.drawFinish(vg)
    D1Renderer.drawPlayer(vg, player)

    -- 通关后不显示瞄准线（冻结状态）
    if not levelState.finished and player.hasGun then
        local platforms = (opts and opts.platforms) or (levelConfig and levelConfig.platforms) or {}
        D1Renderer.drawAimLine(vg, player, inputState.aimDir, platforms)
    end
end

--- 背景：深色填充 + 画布边界框（帮助开发时确认适配区域）
function D1Renderer.drawBackground(vg, screenW, screenH)
    local bg = visualConfig.background
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(bg[1], bg[2], bg[3], bg[4]))
    nvgFill(vg)

    -- 画布边界
    local x1, y1 = Viewport.worldToScreen(0, levelConfig.canvas.h)
    local x2, y2 = Viewport.worldToScreen(levelConfig.canvas.w, 0)
    local cb = visualConfig.canvasBorder
    nvgBeginPath(vg)
    nvgRect(vg, x1, y1, x2 - x1, y2 - y1)
    nvgStrokeColor(vg, nvgRGBA(cb[1], cb[2], cb[3], cb[4]))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
end

--- 掉落危险区：画布底部以下的红色半透明标记
function D1Renderer.drawFallZone(vg)
    local dz = visualConfig.dangerZone
    local x1, y1 = Viewport.worldToScreen(0, 40)
    local x2, y2 = Viewport.worldToScreen(levelConfig.canvas.w, levelConfig.fallY)
    nvgBeginPath(vg)
    nvgRect(vg, x1, y1, x2 - x1, y2 - y1)
    nvgFillColor(vg, nvgRGBA(dz[1], dz[2], dz[3], dz[4]))
    nvgFill(vg)
end

--- 平台：矩形 + 顶部高亮线（表示可着陆面）
-- 支持传入外部平台列表（爬塔模式）
function D1Renderer.drawPlatforms(vg, overridePlatforms)
    local pf = visualConfig.platformFill
    local pt = visualConfig.platformTopLine
    local platformList = overridePlatforms or (levelConfig and levelConfig.platforms) or {}
    for _, p in ipairs(platformList) do
        local sx, sy = Viewport.worldToScreen(p.x, p.y + p.h)
        local sw = Viewport.scaleSize(p.w)
        local sh = Viewport.scaleSize(p.h)

        nvgBeginPath(vg)
        nvgRect(vg, sx, sy, sw, sh)
        nvgFillColor(vg, nvgRGBA(pf[1], pf[2], pf[3], pf[4]))
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgMoveTo(vg, sx, sy)
        nvgLineTo(vg, sx + sw, sy)
        nvgStrokeColor(vg, nvgRGBA(pt[1], pt[2], pt[3], pt[4]))
        nvgStrokeWidth(vg, visualConfig.platformTopLineWidth)
        nvgStroke(vg)
    end
end

--- 终点区域
function D1Renderer.drawFinish(vg)
    local f = levelConfig.finish
    local ff = visualConfig.finishFill
    local fs = visualConfig.finishStroke
    local sx, sy = Viewport.worldToScreen(f.x, f.y + f.h)
    local sw = Viewport.scaleSize(f.w)
    local sh = Viewport.scaleSize(f.h)

    nvgBeginPath(vg)
    nvgRect(vg, sx, sy, sw, sh)
    nvgFillColor(vg, nvgRGBA(ff[1], ff[2], ff[3], ff[4]))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(fs[1], fs[2], fs[3], fs[4]))
    nvgStrokeWidth(vg, visualConfig.finishStrokeWidth)
    nvgStroke(vg)
end

--- 玩家：圆角矩形 + 小眼睛 + 空中补枪状态光环
-- position.x = 水平中心，position.y = 底部
function D1Renderer.drawPlayer(vg, player)
    local pc = visualConfig.playerFill
    local ec = visualConfig.playerEyeColor
    local sx, sy = Viewport.worldToScreen(
        player.position.x - player.width * 0.5,
        player.position.y + player.height
    )
    local sw = Viewport.scaleSize(player.width)
    local sh = Viewport.scaleSize(player.height)

    -- 空中补枪状态光环（只在空中显示）
    if not player.isGrounded then
        local weapon = player.currentWeapon
        if not weapon then return end
        local airLeft = weapon.maxAirShots - player.airShotsUsed
        local glowColor
        if airLeft > 0 then
            -- 有枪可补：亮青色光环
            glowColor = nvgRGBA(80, 220, 255, 100)
        else
            -- 补枪用完：暗红色光环
            glowColor = nvgRGBA(255, 60, 60, 70)
        end
        local glowExpand = Viewport.scaleSize(4)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx - glowExpand, sy - glowExpand,
            sw + glowExpand * 2, sh + glowExpand * 2,
            visualConfig.playerCornerRadius + 2)
        nvgStrokeColor(vg, glowColor)
        nvgStrokeWidth(vg, Viewport.scaleSize(2))
        nvgStroke(vg)
    end

    -- 角色本体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, sx, sy, sw, sh, visualConfig.playerCornerRadius)
    nvgFillColor(vg, nvgRGBA(pc[1], pc[2], pc[3], pc[4]))
    nvgFill(vg)

    -- 小眼睛
    local eyeR = Viewport.scaleSize(visualConfig.playerEyeRadius)
    local eyeX = sx + sw * 0.5
    local eyeY = sy + sh * 0.25
    nvgBeginPath(vg)
    nvgCircle(vg, eyeX, eyeY, eyeR)
    nvgFillColor(vg, nvgRGBA(ec[1], ec[2], ec[3], ec[4]))
    nvgFill(vg)
end

--- 瞄准指示器：渐变箭头（从粗到细 + 三角箭头尖端）
function D1Renderer.drawAimLine(vg, player, aimDir, platforms)
    local ac = visualConfig.aimLineColor
    local cx = player.position.x
    local cy = player.position.y + player.height * 0.5

    local aimLen = visualConfig.aimLineLength

    -- 起点和终点（逻辑坐标）
    local startX = cx + aimDir.x * 12   -- 从玩家中心偏移一点，不贴身
    local startY = cy + aimDir.y * 12
    local endX = cx + aimDir.x * aimLen
    local endY = cy + aimDir.y * aimLen

    local sx1, sy1 = Viewport.worldToScreen(startX, startY)
    local sx2, sy2 = Viewport.worldToScreen(endX, endY)

    -- 方向向量（屏幕坐标系）
    local dx = sx2 - sx1
    local dy = sy2 - sy1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then
        TrajectoryPreview.draw(vg, player, aimDir, platforms)
        return
    end
    local nx = dx / len  -- 单位方向
    local ny = dy / len
    -- 垂直方向（用于画宽度）
    local px = -ny
    local py = nx

    -- ===== 渐变锥形线体（从粗到细）=====
    local widthStart = Viewport.scaleSize(4)   -- 起点宽度
    local widthEnd = Viewport.scaleSize(1.2)   -- 末端宽度（箭头前）

    -- 箭头体截止点（留出箭头三角的空间）
    local arrowHeadLen = Viewport.scaleSize(10)
    local bodyEndX = sx2 - nx * arrowHeadLen
    local bodyEndY = sy2 - ny * arrowHeadLen

    -- 画梯形线体（四个顶点）
    nvgBeginPath(vg)
    nvgMoveTo(vg, sx1 + px * widthStart * 0.5, sy1 + py * widthStart * 0.5)
    nvgLineTo(vg, sx1 - px * widthStart * 0.5, sy1 - py * widthStart * 0.5)
    nvgLineTo(vg, bodyEndX - px * widthEnd * 0.5, bodyEndY - py * widthEnd * 0.5)
    nvgLineTo(vg, bodyEndX + px * widthEnd * 0.5, bodyEndY + py * widthEnd * 0.5)
    nvgClosePath(vg)

    -- 渐变填充（起点亮，末端暗）
    local paint = nvgLinearGradient(vg, sx1, sy1, bodyEndX, bodyEndY,
        nvgRGBA(ac[1], ac[2], ac[3], ac[4]),
        nvgRGBA(ac[1], ac[2], ac[3], math.floor(ac[4] * 0.4))
    )
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    -- ===== 三角箭头尖端 =====
    local arrowWidth = Viewport.scaleSize(6)

    nvgBeginPath(vg)
    nvgMoveTo(vg, sx2, sy2)  -- 尖端
    nvgLineTo(vg, bodyEndX + px * arrowWidth, bodyEndY + py * arrowWidth)
    nvgLineTo(vg, bodyEndX - px * arrowWidth, bodyEndY - py * arrowWidth)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], math.floor(ac[4] * 0.7)))
    nvgFill(vg)

    -- 轨迹预测（独立模块）
    TrajectoryPreview.draw(vg, player, aimDir, platforms)
end

--- 绘制拾取物（枪械等）— 拾取后不再显示
function D1Renderer.drawPickups(vg, player)
    if not levelConfig or not levelConfig.pickups then return end

    for _, pickup in ipairs(levelConfig.pickups) do
        -- 已拾取的不画
        if pickup.type == "gun" and player.hasGun then goto continue end
        if pickup.type == "shotgun" and player.currentWeapon and player.currentWeapon.recoilPower >= 1000 then goto continue end

        local sx, sy = Viewport.worldToScreen(pickup.x, pickup.y + pickup.h)
        local sw = Viewport.scaleSize(pickup.w)
        local sh = Viewport.scaleSize(pickup.h)

        -- 闪烁光环
        local pulse = math.sin(os.clock() * 4) * 0.3 + 0.7
        local glowAlpha = math.floor(80 * pulse)

        if pickup.type == "gun" then
            -- 手枪：橙色
            nvgBeginPath(vg)
            nvgRoundedRect(vg, sx, sy, sw, sh, 3)
            nvgFillColor(vg, nvgRGBA(255, 160, 40, 240))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, sx - 4, sy - 4, sw + 8, sh + 8, 6)
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, glowAlpha))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        elseif pickup.type == "shotgun" then
            -- 霰弹枪：红橙色，更大
            nvgBeginPath(vg)
            nvgRoundedRect(vg, sx, sy, sw, sh, 4)
            nvgFillColor(vg, nvgRGBA(255, 80, 40, 240))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, sx - 4, sy - 4, sw + 8, sh + 8, 7)
            nvgStrokeColor(vg, nvgRGBA(255, 120, 60, glowAlpha))
            nvgStrokeWidth(vg, 2.5)
            nvgStroke(vg)
        end

        ::continue::
    end
end

return D1Renderer
