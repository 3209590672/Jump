-- ============================================================================
-- 视觉表现配置
-- 颜色、线长、尺寸集中管理，美术调整时只改此文件
-- 颜色格式：{R, G, B, A}（0-255）
-- ============================================================================
return {
    -- 背景
    background = { 30, 32, 40, 255 },
    canvasBorder = { 60, 65, 80, 255 },

    -- 平台
    platformFill = { 100, 110, 130, 255 },
    platformTopLine = { 180, 190, 210, 255 },
    platformTopLineWidth = 2,

    -- 终点区域
    finishFill = { 220, 200, 50, 120 },
    finishStroke = { 255, 230, 80, 255 },
    finishStrokeWidth = 2,

    -- 掉落危险区
    dangerZone = { 180, 40, 40, 60 },

    -- 玩家
    playerFill = { 80, 160, 255, 255 },
    playerCornerRadius = 4,
    playerEyeColor = { 255, 255, 255, 255 },
    playerEyeRadius = 4,

    -- 瞄准线
    aimLineColor = { 255, 80, 80, 200 },
    aimLineWidth = 2,
    aimLineLength = 50,            -- 红色枪口方向线长度（逻辑像素）

    -- 通关面板
    finishPanelBg = { 40, 45, 60, 240 },
    finishPanelBorder = { 220, 200, 50, 200 },
    finishPanelWidth = 360,
    finishPanelHeight = 200,
    finishOverlay = { 0, 0, 0, 140 },
}
