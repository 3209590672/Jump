-- ============================================================================
-- 输入控制器
-- 统一 PC/手机输入，输出标准化结构：
--   moveAxis     : -1（左）/ 0（停）/ 1（右）
--   aimDir       : {x, y} 归一化瞄准方向（枪口指向）
--   firePressed  : boolean 本帧是否按下开火
--   respawnPressed: boolean 本帧是否按下重开
--
-- 后续接入手机虚拟摇杆时，只需修改此文件的 read() 函数
-- ============================================================================
local Viewport = require("core.viewport")

local InputController = {}

--- 读取当前帧输入
---@param player table 玩家状态（用于计算瞄准方向的参考中心点）
---@return table {moveAxis, aimDir, firePressed, respawnPressed}
function InputController.read(player)
    local moveAxis = 0
    local aimDir = { x = 0, y = -1 }   -- 默认向下（开火会向上飞）
    local firePressed = false
    local respawnPressed = false

    -- ===== 水平移动：A/D 键 =====
    if input:GetKeyDown(KEY_A) then
        moveAxis = moveAxis - 1
    end
    if input:GetKeyDown(KEY_D) then
        moveAxis = moveAxis + 1
    end

    -- ===== R 键：重新开始 =====
    if input:GetKeyPress(KEY_R) then
        respawnPressed = true
    end

    -- ===== 鼠标瞄准方向 =====
    -- 1. 获取鼠标屏幕坐标
    local mouseScreenX = input.mousePosition.x
    local mouseScreenY = input.mousePosition.y

    -- 2. 转换为逻辑世界坐标（Y 向上）
    local mouseWorldX, mouseWorldY = Viewport.screenToWorld(mouseScreenX, mouseScreenY)

    -- 3. 计算从玩家中心到鼠标的方向向量
    local cx = player.position.x                     -- 玩家水平中心
    local cy = player.position.y + player.height * 0.5  -- 玩家垂直中心

    local dx = mouseWorldX - cx
    local dy = mouseWorldY - cy
    local len = math.sqrt(dx * dx + dy * dy)

    -- 4. 归一化（鼠标太近时使用默认方向）
    if len > 1 then
        aimDir.x = dx / len
        aimDir.y = dy / len
    else
        aimDir.x = 0
        aimDir.y = -1  -- 鼠标在玩家正中心，默认向下开枪 → 向上飞
    end

    -- ===== 左键开火（仅检测按下瞬间，不是持续按住） =====
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        firePressed = true
    end

    return {
        moveAxis = moveAxis,
        aimDir = aimDir,
        firePressed = firePressed,
        respawnPressed = respawnPressed,
    }
end

return InputController
