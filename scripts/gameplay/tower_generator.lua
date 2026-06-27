-- ============================================================================
-- 无限爬塔：程序化平台生成器
--
-- 职责：
--   - 根据玩家高度动态生成新平台（向上）
--   - 删除已经远低于相机的旧平台（节省内存）
--   - 难度随高度递增（平台变窄、间距变大）
--   - 保证每个平台都可达（不生成不可能跳到的位置）
--
-- 使用方式：
--   TowerGenerator.init(towerConfig)
--   TowerGenerator.update(cameraTopY)  -- 每帧调用
--   TowerGenerator.getPlatforms()      -- 获取当前活跃平台列表
--   TowerGenerator.getMaxHeight()      -- 获取玩家到达过的最大高度
--   TowerGenerator.reset()
-- ============================================================================

local TowerGenerator = {}

local config = nil       -- tower 配置
local platforms = {}     -- 当前活跃平台列表
local nextY = 0          -- 下一个待生成平台的 Y 坐标
local platformId = 0     -- 平台计数器
local maxHeight = 0      -- 玩家到达的最大高度
local canvasW = 960      -- 画布宽度

--- 初始化（进入爬塔关时调用）
---@param towerCfg table level_tower_config.tower
---@param cw number 画布宽度
function TowerGenerator.init(towerCfg, cw)
    config = towerCfg
    canvasW = cw or 960
    platforms = {}
    platformId = 0
    maxHeight = 0
    nextY = config.startPlatformY

    -- 生成起始平台（宽，安全）
    TowerGenerator._addPlatform(canvasW * 0.5 - 120, config.startPlatformY, 240)

    -- 预生成一屏的平台
    TowerGenerator._generateUpTo(config.startPlatformY + 800)
end

--- 每帧更新（传入相机可见区域的顶部 Y）
---@param cameraTopY number 相机顶部的世界 Y 坐标
---@param cameraBottomY number 相机底部的世界 Y 坐标
function TowerGenerator.update(cameraTopY, cameraBottomY)
    -- 向上生成新平台
    local targetY = cameraTopY + config.generateAheadDistance
    TowerGenerator._generateUpTo(targetY)

    -- 删除低于相机太远的旧平台
    local removeThreshold = cameraBottomY - config.removeBelow
    local i = 1
    while i <= #platforms do
        if platforms[i].y + platforms[i].h < removeThreshold then
            table.remove(platforms, i)
        else
            i = i + 1
        end
    end
end

--- 更新玩家最大高度
---@param playerY number
function TowerGenerator.updateMaxHeight(playerY)
    if playerY > maxHeight then
        maxHeight = playerY
    end
end

--- 获取当前活跃平台列表
function TowerGenerator.getPlatforms()
    return platforms
end

--- 获取最大到达高度
function TowerGenerator.getMaxHeight()
    return maxHeight
end

--- 重置
function TowerGenerator.reset()
    platforms = {}
    platformId = 0
    maxHeight = 0
    nextY = 0
end

-- ============================================================================
-- 内部方法
-- ============================================================================

--- 生成平台直到目标 Y
function TowerGenerator._generateUpTo(targetY)
    while nextY < targetY do
        -- 根据高度计算难度（0~1，越高越难）
        local difficulty = math.min(1, nextY * config.difficultyPerMeter)

        -- 垂直间距：随难度增大
        local gapY = config.minGapY + (config.maxGapY - config.minGapY) * difficulty
        -- 加一点随机（±20%）
        gapY = gapY * (0.8 + math.random() * 0.4)

        nextY = nextY + gapY

        -- 平台宽度：随难度减小
        local platW = config.maxPlatformW - (config.maxPlatformW - config.minPlatformW) * difficulty
        -- 加一点随机（±15%）
        platW = platW * (0.85 + math.random() * 0.3)
        platW = math.max(config.minPlatformW, math.floor(platW))

        -- X 位置：随机但保证在画布内，且和上一个平台的水平距离可达
        local margin = 40
        local platX = margin + math.random() * (canvasW - platW - margin * 2)

        TowerGenerator._addPlatform(platX, nextY, platW)
    end
end

--- 添加一个平台
function TowerGenerator._addPlatform(x, y, w)
    platformId = platformId + 1
    table.insert(platforms, {
        id = "tower_" .. platformId,
        x = x,
        y = y,
        w = w,
        h = 20,
        type = "static",
    })
end

return TowerGenerator
