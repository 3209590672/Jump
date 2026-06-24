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

    local timeText = string.format("Time: %.2fs", levelState.elapsedTime)
    nvgText(vg, 16, 16, timeText, nil)

    local deathText = string.format("Deaths: %d", player.respawnCount)
    nvgText(vg, 16, 42, deathText, nil)

    -- ===== 空中补枪状态（仅空中时显示） =====
    local weapon = weaponConfig.calibratePistol
    local airShotsLeft = weapon.maxAirShots - player.airShotsUsed
    if not player.isGrounded then
        -- 绿色=有弹，红色=已用完
        local shotColor = airShotsLeft > 0
            and nvgRGBA(100, 255, 100, 200)
            or nvgRGBA(255, 80, 80, 200)
        nvgFillColor(vg, shotColor)
        local shotText = string.format("Air: %d/%d", airShotsLeft, weapon.maxAirShots)
        nvgText(vg, 16, 68, shotText, nil)
    end

    -- ===== 底部中央：操作提示 =====
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 150))
    nvgText(vg, screenW * 0.5, screenH - 12,
        "A/D Move | Mouse Aim | LMB Fire | R Restart", nil)

    -- ===== 通关面板 =====
    if levelState.finished then
        D1Hud.drawFinishPanel(vg, player, levelState, screenW, screenH)
    end
end

--- 通关面板：半透明遮罩 + 居中成绩卡片
function D1Hud.drawFinishPanel(vg, player, levelState, screenW, screenH)
    -- 全屏半透明遮罩（强制玩家视线聚焦到面板）
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
    nvgFill(vg)

    -- 面板背景（居中圆角矩形）
    local panelW = 360
    local panelH = 200
    local px = (screenW - panelW) * 0.5
    local py = (screenH - panelH) * 0.5

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, panelW, panelH, 12)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 200, 50, 200))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题
    nvgFontFaceId(vg, fontId)
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 80, 255))
    nvgText(vg, screenW * 0.5, py + 40, "Calibration Complete", nil)

    -- 用时
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    local resultTime = string.format("Time: %.2f s", levelState.elapsedTime)
    nvgText(vg, screenW * 0.5, py + 80, resultTime, nil)

    -- 事故次数
    local resultDeaths = string.format("Accidents: %d", player.respawnCount)
    nvgText(vg, screenW * 0.5, py + 110, resultDeaths, nil)

    -- 小评语
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, screenW * 0.5, py + 150,
        "You are now qualified to be hurt by recoil.", nil)

    -- 重新开始提示
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 220))
    nvgText(vg, screenW * 0.5, py + 180, "Press R to retry", nil)
end

return D1Hud
