-- ============================================================================
-- 轨迹预测显示配置
-- 控制是否启用轨迹预测以及视觉表现参数
-- 设为 enabled = false 即可完全关闭此功能，不影响其他模块
-- ============================================================================
return {
    enabled = true,               -- 是否启用轨迹预测（总开关）

    -- 模拟参数
    simDt = 0.02,                 -- 模拟步长（秒），越小越精确但越费性能
    totalSteps = 60,              -- 最多模拟步数（60 步 × 0.02s = 1.2 秒）
    dotInterval = 3,              -- 每隔几步画一个点（控制点密度）

    -- 视觉参数
    dotRadius = 3,                -- 轨迹点半径（逻辑像素）
    dotColorR = 100,              -- 轨迹点颜色 R
    dotColorG = 200,              -- 轨迹点颜色 G
    dotColorB = 255,              -- 轨迹点颜色 B
    alphaStart = 200,             -- 起始透明度
    alphaDecay = 3,               -- 每步透明度衰减量
    alphaMin = 40,                -- 最低透明度

    -- 落点标记
    landingDotRadius = 5,         -- 落点圆点半径（逻辑像素）
    landingColorR = 100,          -- 落点颜色 R
    landingColorG = 255,          -- 落点颜色 G
    landingColorB = 150,          -- 落点颜色 B
    landingAlpha = 180,           -- 落点透明度

    -- 平台碰撞检测容差
    platformHitTolerance = 8,     -- 判定落到平台的垂直容差（px）
}
