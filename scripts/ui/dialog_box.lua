-- ============================================================================
-- 对话框系统
-- 游戏中弹出文本对话框，点击或按任意键继续
--
-- 使用方式：
--   DialogBox.show("对话内容", function() 关闭后回调 end)
--   DialogBox.update(dt)  -- 每帧调用
--   DialogBox.draw(vg)    -- NanoVG 渲染中调用
--   DialogBox.isActive()  -- 是否正在显示（用于冻结玩法输入）
-- ============================================================================
local Viewport = require("core.viewport")

local DialogBox = {}

local state = {
    active = false,
    text = "",
    onClose = nil,
    -- 打字机效果
    charIndex = 0,
    charTimer = 0,
    charInterval = 0.03,  -- 每个字出现的间隔（秒）
    fullTextShown = false,
    -- 字体
    fontId = -1,
}

--- 初始化字体（在 Start 中调用一次）
---@param vg userdata
function DialogBox.initFont(vg)
    state.fontId = nvgCreateFont(vg, "dialog", "Fonts/MiSans-Regular.ttf")
end

--- 弹出对话框
---@param text string 对话内容
---@param onClose function|nil 关闭后回调
function DialogBox.show(text, onClose)
    state.active = true
    state.text = text
    state.onClose = onClose
    state.charIndex = 0
    state.charTimer = 0
    state.fullTextShown = false
end

--- 是否正在显示
function DialogBox.isActive()
    return state.active
end

--- 每帧更新（打字机效果 + 输入检测）
---@param dt number
function DialogBox.update(dt)
    if not state.active then return end

    -- 打字机效果
    if not state.fullTextShown then
        state.charTimer = state.charTimer + dt
        if state.charTimer >= state.charInterval then
            state.charTimer = 0
            state.charIndex = state.charIndex + 1
            if state.charIndex >= utf8.len(state.text) then
                state.fullTextShown = true
            end
        end
    end

    -- 点击或按空格/回车：全部显示 → 关闭
    local clicked = input:GetMouseButtonPress(MOUSEB_LEFT)
    local keyPressed = input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN)

    if clicked or keyPressed then
        if not state.fullTextShown then
            -- 第一次点击：立即显示全部文字
            state.fullTextShown = true
            state.charIndex = utf8.len(state.text)
        else
            -- 第二次点击：关闭对话框
            state.active = false
            if state.onClose then
                state.onClose()
            end
        end
    end
end

--- 绘制对话框（在 NanoVG 帧内调用）
---@param vg userdata
function DialogBox.draw(vg)
    if not state.active then return end
    if state.fontId == -1 then return end

    local g = GetGraphics()
    local screenW = g:GetWidth()
    local screenH = g:GetHeight()

    -- 对话框参数
    local boxW = screenW * 0.75
    local boxH = 120
    local boxX = (screenW - boxW) * 0.5
    local boxY = screenH - boxH - 40  -- 底部偏上

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 10)
    nvgFillColor(vg, nvgRGBA(20, 22, 30, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 120, 160, 180))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 文字内容（打字机效果：只显示前 charIndex 个字）
    nvgFontFaceId(vg, state.fontId)
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(240, 240, 250, 255))

    local displayText = state.text
    if not state.fullTextShown and state.charIndex < utf8.len(state.text) then
        displayText = string.sub(state.text, 1, utf8.offset(state.text, state.charIndex + 1) - 1)
    end

    -- 自动换行绘制
    nvgTextBox(vg, boxX + 20, boxY + 20, boxW - 40, displayText, nil)

    -- 底部提示
    if state.fullTextShown then
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(150, 160, 180, 180))
        nvgText(vg, boxX + boxW - 16, boxY + boxH - 10, "点击继续 ▶", nil)
    end
end

return DialogBox
