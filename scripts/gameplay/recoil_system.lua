-- ============================================================================
-- 反冲系统
-- 本游戏的核心机制：玩家通过开枪的反作用力移动
--
-- 核心公式：
--   recoilVelocity = -normalize(aimDir) * recoilPower
--   即：枪口朝哪打，玩家就往反方向飞
--
-- 开火条件：
--   1. 冷却结束（防连点）
--   2. 如果在空中，补枪次数未用完（maxAirShots=1）
--   3. 地面开火不消耗补枪次数
-- ============================================================================
local EventBus = require("core.event_bus")

local RecoilSystem = {}

--- 尝试开火
-- 成功时修改 player.velocity 并消耗资源
-- 从 player.currentWeapon 读取武器参数（不硬编码具体武器）
---@param player table 玩家状态
---@param aimDir table {x, y} 瞄准方向（枪口指向，归一化）
---@return boolean 是否成功开火
function RecoilSystem.tryFire(player, aimDir)
    local weapon = player.currentWeapon
    if not weapon then return false end

    -- 条件 1：冷却检查
    if player.fireCooldownLeft > 0 then
        return false
    end

    -- 条件 2：空中补枪次数检查
    if not player.isGrounded and player.airShotsUsed >= weapon.maxAirShots then
        return false
    end

    -- 归一化瞄准方向（防止零向量导致 NaN）
    local dx, dy = aimDir.x, aimDir.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        dx, dy = 0, -1  -- 零向量时默认向下开枪 → 玩家向上飞
    else
        dx, dy = dx / len, dy / len
    end

    -- ===== 核心：施加反冲冲量 =====
    -- velocity += (-aimDir) * recoilPower
    -- 不是"替换"速度，而是"叠加"，这样空中补枪可以修正轨迹
    player.velocity.x = player.velocity.x - dx * weapon.recoilPower
    player.velocity.y = player.velocity.y - dy * weapon.recoilPower

    -- 反冲后限速（防止多次叠加导致速度爆炸）
    local speed = math.sqrt(player.velocity.x ^ 2 + player.velocity.y ^ 2)
    if speed > weapon.maxSpeedAfterRecoil then
        local ratio = weapon.maxSpeedAfterRecoil / speed
        player.velocity.x = player.velocity.x * ratio
        player.velocity.y = player.velocity.y * ratio
    end

    -- 设置冷却计时器
    player.fireCooldownLeft = weapon.cooldown

    -- 消耗空中补枪次数（地面开火不消耗）
    if not player.isGrounded then
        player.airShotsUsed = player.airShotsUsed + 1
    end

    -- 广播开火事件（供音效、粒子等模块监听）
    -- weaponId 用于区分音效/VFX
    local weaponId = "pistol"
    if weapon.recoilPower >= 1000 then weaponId = "shotgun" end
    EventBus.emit("player_fire", {
        x = player.position.x,
        y = player.position.y,
        aimX = dx,
        aimY = dy,
        weaponId = weaponId,
    })

    return true
end

return RecoilSystem
