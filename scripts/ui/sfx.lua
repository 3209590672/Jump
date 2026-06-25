-- ============================================================================
-- 音效管理模块
-- 通过 EventBus 事件自动播放音效，不侵入玩法逻辑
--
-- 使用方式：
--   SFX.init()  -- Start 中调用，注册事件监听
-- ============================================================================
local EventBus = require("core.event_bus")

local SFX = {}

-- 音效节点（引擎需要 Node 来挂载 SoundSource）
local sfxNode = nil

--- 播放一个音效
---@param path string 资源路径
---@param volume number|nil 音量 0~1（默认 0.6）
local function playSound(path, volume)
    if not sfxNode then return end
    local sound = cache:GetResource("Sound", path)
    if not sound then
        print("[SFX] Sound not found: " .. path)
        return
    end
    local source = sfxNode:GetOrCreateComponent("SoundSource")
    source.soundType = SOUND_EFFECT
    source:Play(sound)
    source.gain = volume or 0.6
end

--- 初始化：创建音效节点 + 注册事件
function SFX.init()
    -- 创建全局音效场景（不依赖游戏场景）
    local audioScene = Scene()
    sfxNode = audioScene:CreateChild("SFX")

    -- 保持场景存活
    SFX._scene = audioScene

    -- 注册事件
    EventBus.on("player_fire", function(data)
        playSound("audio/sfx/fire_pistol.ogg", 0.5)
    end)

    EventBus.on("player_land", function(data)
        playSound("audio/sfx/land_thud.ogg", 0.4)
    end)

    EventBus.on("player_respawn", function(data)
        if data.count and data.count > 0 then
            playSound("audio/sfx/respawn_whoosh.ogg", 0.5)
        end
    end)

    print("[SFX] Sound system initialized")
end

return SFX
