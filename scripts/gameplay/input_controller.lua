-- ============================================================================
-- 输入控制器
-- 统一 PC/手机输入，输出标准化结构：
--   moveAxis     : -1（左）/ 0（停）/ 1（右）
--   aimDir       : {x, y} 归一化瞄准方向（枪口指向）
--   firePressed  : boolean 本帧是否按下开火
--   slowMotionHeld: boolean 是否按住慢动作
--   respawnPressed: boolean 本帧是否按下重开
--
-- 后续接入手机虚拟摇杆时，只需修改此文件的 read() 函数
-- ============================================================================
local Viewport = require("core.viewport")
local inputConfig = require("config.input_config")

local InputController = {}

--- 读取当前帧输入
---@param player table 玩家状态（用于计算瞄准方向的参考中心点）
---@return table {moveAxis, aimDir, firePressed, slowMotionHeld, respawnPressed}
function InputController.read(player)
    local moveAxis = 0
    local aimDir = { x = 0, y = -1 }   -- 默认向下（开火会向上飞）
    local firePressed = false
    local slowMotionHeld = false
    local respawnPressed = false

    -- ===== 水平移动（键位来自 input_config）=====
    if input:GetKeyDown(inputConfig.moveLeft) then
        moveAxis = moveAxis - 1
    end
    if input:GetKeyDown(inputConfig.moveRight) then
        moveAxis = moveAxis + 1
    end

    -- ===== 重新开始（键位来自 input_config）=====
    if input:GetKeyPress(inputConfig.restart) then
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

    -- ===== 开火（键位来自 input_config，仅检测按下瞬间） =====
    if input:GetMouseButtonPress(inputConfig.fireMouse) then
        firePressed = true
    end

    -- ===== 慢动作（右键按住） =====
    if input:GetMouseButtonDown(inputConfig.slowMotionMouse) then
        slowMotionHeld = true
    end

    return {
        moveAxis = moveAxis,
        aimDir = aimDir,
        firePressed = firePressed,
        slowMotionHeld = slowMotionHeld,
        respawnPressed = respawnPressed,
    }
end

return InputController
