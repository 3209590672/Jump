-- ============================================================================
-- D1 HUD（抬头显示）
-- 使用 NanoVG 文本绘制游戏状态信息
--
-- 显示内容：
--   左上角：计时 + 事故次数 + 空中补枪状态
--   底部中央：操作提示
--   通关时：全屏遮罩 + 成绩面板
--
-- D1 验收要求（Harness U-001 ~ U-006）：
--   - 能看到当前用时
--   - 掉落后事故数字增加
--   - 能看到基础操作说明
--   - 通关后显示成绩
--   - 能明确看到枪口方向（在 d1_renderer 中实现）
-- ============================================================================
local Viewport = require("core.viewport")
local weaponConfig = require("config.weapon_config")
local textConfig = require("config.ui_text_config")
local visualConfig = require("config.visual_config")

local D1Hud = {}

local fontId = -1  -- 字体句柄，initFont 时赋值

--- 初始化字体（Start 时调用一次，不要每帧调用）
---@param vg userdata NanoVG 上下文
function D1Hud.initFont(vg)
    fontId = nvgCreateFont(vg, "hud", "Fonts/MiSans-Regular.ttf")
    if fontId == -1 then
        print("[HUD] ERROR: Failed to load font")
    else
        print("[HUD] Font loaded, id=" .. fontId)
    end
end

--- 绘制 HUD（每帧在 NanoVGRender 中调用，在场景绘制之后）
---@param vg userdata
---@param player table
---@param levelState table
function D1Hud.draw(vg, player, levelState)
    if fontId == -1 then return end

    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    nvgFontFaceId(vg, fontId)

    -- ===== 左上角：计时 + 事故次数 =====
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))

    local timeText = string.format(textConfig.timeLabel, levelState.elapsedTime)
    nvgText(vg, 16, 16, timeText, nil)

    local deathText = string.format(textConfig.deathsLabel, player.respawnCount)
    nvgText(vg, 16, 42, deathText, nil)

    -- ===== 空中补枪状态（仅空中时显示） =====
    local weapon = weaponConfig.calibratePistol
    local airShotsLeft = weapon.maxAirShots - player.airShotsUsed
    if not player.isGrounded then
        local shotColor = airShotsLeft > 0
            and nvgRGBA(100, 255, 100, 200)
            or nvgRGBA(255, 80, 80, 200)
        nvgFillColor(vg, shotColor)
        local shotText = string.format(textConfig.airShotsLabel, airShotsLeft, weapon.maxAirShots)
        nvgText(vg, 16, 68, shotText, nil)
    end

    -- ===== 底部中央：操作提示 =====
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 150))
    nvgText(vg, screenW * 0.5, screenH - 12, textConfig.controlsHint, nil)

    -- ===== 通关面板 =====
    if levelState.finished then
        D1Hud.drawFinishPanel(vg, player, levelState, screenW, screenH)
    end
end

--- 通关面板：半透明遮罩 + 居中成绩卡片
function D1Hud.drawFinishPanel(vg, player, levelState, screenW, screenH)
    local vc = visualConfig

    -- 全屏半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    local ov = vc.finishOverlay
    nvgFillColor(vg, nvgRGBA(ov[1], ov[2], ov[3], ov[4]))
    nvgFill(vg)

    -- 面板背景
    local panelW = vc.finishPanelWidth
    local panelH = vc.finishPanelHeight
    local px = (screenW - panelW) * 0.5
    local py = (screenH - panelH) * 0.5

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, panelW, panelH, 12)
    local bg = vc.finishPanelBg
    nvgFillColor(vg, nvgRGBA(bg[1], bg[2], bg[3], bg[4]))
    nvgFill(vg)
    local bd = vc.finishPanelBorder
    nvgStrokeColor(vg, nvgRGBA(bd[1], bd[2], bd[3], bd[4]))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题
    nvgFontFaceId(vg, fontId)
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 80, 255))
    nvgText(vg, screenW * 0.5, py + 40, textConfig.finishTitle, nil)

    -- 用时
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, screenW * 0.5, py + 80,
        string.format(textConfig.finishTimeLabel, levelState.elapsedTime), nil)

    -- 事故次数
    nvgText(vg, screenW * 0.5, py + 110,
        string.format(textConfig.finishDeathsLabel, player.respawnCount), nil)

    -- 小评语
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, screenW * 0.5, py + 150, textConfig.finishComment, nil)

    -- 重新开始提示
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 220))
    nvgText(vg, screenW * 0.5, py + 180, textConfig.finishRetryHint, nil)
end

return D1Hud
