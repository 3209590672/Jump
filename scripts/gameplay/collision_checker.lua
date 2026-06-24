-- ============================================================================
-- 碰撞检测器
-- 使用 previousPosition 做穿越判定，只处理"从上往下落到平台顶"的情况
--
-- 设计决策：
--   - 不使用 Box2D，自写简单物理更可控
--   - 只处理顶部碰撞（单向平台），侧面和底部不阻挡
--   - 用两帧位置差做"穿越检测"，避免高速下落穿透
--
-- 碰撞体示意：
--   玩家：position.y = 底部 Y，宽 32px，高 48px
--   平台：{x, y, w, h}，y 为底部，platformTop = y + h
-- ============================================================================
local playerConfig = require("config.player_config")
local EventBus = require("core.event_bus")

local CollisionChecker = {}

--- 判断玩家本帧是否落到某个平台上
-- 核心逻辑：上一帧脚底在平台顶之上，当前帧脚底穿过平台顶
---@param player table
---@param platform table {x, y, w, h}
---@return boolean
function CollisionChecker.isLandingOnPlatform(player, platform)
    -- 玩家脚底 = position.y（position.y 定义为底部 Y）
    local prevBottom = player.previousPosition.y
    local currBottom = player.position.y
    local platformTop = platform.y + platform.h

    -- 水平重叠检测（带宽容量，让"差一点踩到边缘"也能落地）
    local halfW = player.width * 0.5
    local playerLeft = player.position.x - halfW
    local playerRight = player.position.x + halfW

    local grace = playerConfig.landingGraceWidth
    local platformLeft = platform.x - grace
    local platformRight = platform.x + platform.w + grace

    -- 穿越判定三条件：
    -- 1. 上一帧脚底在平台顶附近或之上（带 graceHeight 回溯容差）
    -- 2. 当前帧脚底在平台顶或之下（穿过去了）
    -- 3. 玩家正在下落（velocity.y <= 0）
    local crossedTop = prevBottom >= (platformTop - playerConfig.landingGraceHeight)
        and currBottom <= platformTop
    local falling = player.velocity.y <= 0
    local horizontalOverlap = playerRight > platformLeft and playerLeft < platformRight

    return crossedTop and falling and horizontalOverlap
end

--- 解析所有平台碰撞（每帧调用一次）
-- 先做穿越判定（主要落地检测），再做持续站立检测（防止站着突然掉下去）
---@param player table
---@param platforms table[]
function CollisionChecker.resolvePlatforms(player, platforms)
    local wasGrounded = player.isGrounded
    player.isGrounded = false

    -- ===== 阶段 1：穿越落地判定 =====
    for _, platform in ipairs(platforms) do
        if CollisionChecker.isLandingOnPlatform(player, platform) then
            -- 修正位置：把脚底吸附到平台顶部
            player.position.y = platform.y + platform.h
            -- 垂直速度归零（着陆）
            player.velocity.y = 0
            player.isGrounded = true
            -- 落地恢复空中补枪次数
            player.airShotsUsed = 0

            if not wasGrounded then
                EventBus.emit("player_land", { platformId = platform.id })
            end
            return
        end
    end

    -- ===== 阶段 2：持续站立检测 =====
    -- 场景：上一帧站在平台上，本帧因浮点误差脚底偏离了一点点
    -- 关键：如果玩家正在向上飞（刚开火反冲），跳过此检查！
    --        否则会把刚起飞的玩家吸回平台，表现为"飞不起来"
    if wasGrounded and not player.isGrounded and player.velocity.y <= 0 then
        for _, platform in ipairs(platforms) do
            local platformTop = platform.y + platform.h
            local halfW = player.width * 0.5
            local playerLeft = player.position.x - halfW
            local playerRight = player.position.x + halfW

            -- 脚底和平台顶差距小于 4px → 视为仍站在上面
            local onTop = math.abs(player.position.y - platformTop) < 4
            local horizontalOverlap = playerRight > platform.x and playerLeft < (platform.x + platform.w)

            if onTop and horizontalOverlap then
                player.position.y = platformTop
                player.velocity.y = 0
                player.isGrounded = true
                player.airShotsUsed = 0
                return
            end
        end
    end
end

return CollisionChecker
