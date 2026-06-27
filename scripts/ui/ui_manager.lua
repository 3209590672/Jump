-- ============================================================================
-- UI 管理层
-- 负责 UI 系统初始化、多页面状态切换、根节点管理
--
-- 页面状态：
--   "title"       → 游戏开始展示界面
--   "levelSelect" → 关卡选择界面
--   "playing"     → 游戏中 HUD
--   "result"      → 关卡结束数据展示
--
-- 流转：
--   title → levelSelect → playing → result
--                ↑            ↑        │
--                └────────────┘────────┘
-- ============================================================================
local UI = require("urhox-libs/UI")
local EventBus = require("core.event_bus")
local textConfig = require("config.ui_text_config")
local weaponConfig = require("config.weapon_config")

local UIManager = {}

local currentScreen = "none"

-- 各页面的控件引用
local screens = {}

--- 初始化 UI 系统
function UIManager.init()
    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })
    print("[UIManager] UI system initialized")
end

--- 清理 UI
function UIManager.shutdown()
    UI.Shutdown()
end

-- ============================================================================
-- 页面 1：开始展示界面
-- ============================================================================

function UIManager.showTitle()
    currentScreen = "title"

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 20, 22, 30, 255 },
        children = {
            UI.Panel {
                alignItems = "center",
                gap = 24,
                children = {
                    -- 游戏标题
                    UI.Label {
                        text = "不许！跳！",
                        fontSize = 48,
                        fontWeight = "bold",
                        color = { 255, 230, 80, 255 },
                    },
                    -- 副标题
                    UI.Label {
                        text = "用后坐力飞行的平台跳跃",
                        fontSize = 16,
                        color = { 180, 180, 200, 200 },
                    },
                    -- 开始按钮
                    UI.Button {
                        text = "接受校准",
                        variant = "primary",
                        width = 180,
                        height = 48,
                        marginTop = 32,
                        onClick = function(self)
                            EventBus.emit("ui_goto_level_select", {})
                        end,
                    },
                },
            },
        },
    }

    UI.SetRoot(root, true)
end

-- ============================================================================
-- 页面 2：关卡选择界面
-- ============================================================================

function UIManager.showLevelSelect(levels)
    currentScreen = "levelSelect"

    -- 构建关卡按钮列表
    local levelButtons = {}
    for i, level in ipairs(levels) do
        table.insert(levelButtons, UI.Panel {
            width = 280,
            height = 72,
            borderRadius = 8,
            backgroundColor = { 50, 55, 70, 255 },
            borderWidth = 1,
            borderColor = { 80, 90, 110, 255 },
            flexDirection = "row",
            alignItems = "center",
            padding = 16,
            gap = 12,
            cursor = "pointer",
            onClick = function(self)
                EventBus.emit("ui_start_level", { index = i, id = level.id })
            end,
            children = {
                -- 关卡编号
                UI.Panel {
                    width = 40,
                    height = 40,
                    borderRadius = 20,
                    backgroundColor = level.unlocked and { 80, 160, 255, 255 } or { 60, 60, 70, 255 },
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = tostring(i),
                            fontSize = 18,
                            fontWeight = "bold",
                            color = { 255, 255, 255, 255 },
                        },
                    },
                },
                -- 关卡信息
                UI.Panel {
                    flexShrink = 1,
                    gap = 4,
                    children = {
                        UI.Label {
                            text = level.name,
                            fontSize = 16,
                            fontWeight = "bold",
                            color = { 255, 255, 255, 230 },
                        },
                        UI.Label {
                            text = level.bestTime and string.format("最佳：%.2f秒", level.bestTime) or "未通关",
                            fontSize = 13,
                            color = level.bestTime and { 100, 255, 150, 200 } or { 150, 150, 160, 150 },
                        },
                    },
                },
            },
        })
    end

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 20, 22, 30, 255 },
        alignItems = "center",
        paddingTop = 60,
        gap = 20,
        children = {
            -- 标题
            UI.Label {
                text = "选择关卡",
                fontSize = 28,
                fontWeight = "bold",
                color = { 255, 255, 255, 240 },
            },
            -- 关卡列表
            UI.Panel {
                alignItems = "center",
                gap = 12,
                marginTop = 20,
                children = levelButtons,
            },
            -- 返回按钮
            UI.Button {
                text = "返回",
                variant = "ghost",
                marginTop = 24,
                onClick = function(self)
                    EventBus.emit("ui_goto_title", {})
                end,
            },
        },
    }

    UI.SetRoot(root, true)
end

-- ============================================================================
-- 页面 3：游戏中 HUD
-- ============================================================================

function UIManager.showPlayingHud()
    currentScreen = "playing"

    screens.timeLabel = UI.Label {
        text = string.format(textConfig.timeLabel, 0),
        fontSize = 18,
        color = { 255, 255, 255, 220 },
    }

    screens.deathsLabel = UI.Label {
        text = string.format(textConfig.deathsLabel, 0),
        fontSize = 18,
        color = { 255, 255, 255, 220 },
    }

    screens.airShotsLabel = UI.Label {
        text = "",
        fontSize = 16,
        color = { 100, 255, 100, 200 },
    }

    screens.weaponLabel = UI.Label {
        text = "",
        fontSize = 14,
        color = { 255, 200, 80, 180 },
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        children = {
            -- 左上角 HUD
            UI.Panel {
                position = "absolute",
                left = 16,
                top = 16,
                gap = 4,
                children = {
                    screens.timeLabel,
                    screens.deathsLabel,
                    screens.airShotsLabel,
                    screens.weaponLabel,
                },
            },
            -- 底部操作提示
            UI.Panel {
                position = "absolute",
                bottom = 12,
                left = 0,
                width = "100%",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = textConfig.controlsHint,
                        fontSize = 13,
                        color = { 200, 200, 200, 150 },
                    },
                },
            },
        },
    }

    UI.SetRoot(root, true)
end

--- 每帧更新 HUD 数据
---@param player table
---@param levelState table
function UIManager.updateHud(player, levelState)
    if currentScreen ~= "playing" then return end

    if screens.timeLabel then
        screens.timeLabel:SetText(string.format(textConfig.timeLabel, levelState.elapsedTime))
    end
    if screens.deathsLabel then
        screens.deathsLabel:SetText(string.format(textConfig.deathsLabel, player.respawnCount))
    end
    if screens.weaponLabel then
        local weapon = player.currentWeapon
        if weapon and player.hasGun then
            local name = weapon.recoilPower >= 1000 and "霰弹枪" or "校准手枪"
            screens.weaponLabel:SetText(name)
        else
            screens.weaponLabel:SetText("")
        end
    end
    if screens.airShotsLabel then
        if not player.isGrounded then
            local weapon = player.currentWeapon or weaponConfig.calibratePistol
            local airLeft = weapon.maxAirShots - player.airShotsUsed
            screens.airShotsLabel:SetText(string.format(textConfig.airShotsLabel, airLeft, weapon.maxAirShots))
            if airLeft > 0 then
                screens.airShotsLabel:SetStyle({ color = { 100, 255, 100, 200 } })
            else
                screens.airShotsLabel:SetStyle({ color = { 255, 80, 80, 200 } })
            end
        else
            screens.airShotsLabel:SetText("")
        end
    end
end

-- ============================================================================
-- 页面 4：关卡结束数据展示
-- ============================================================================

function UIManager.showResult(player, levelState, levelName)
    currentScreen = "result"

    -- 评价等级
    local rating = "S"
    local time = levelState.elapsedTime
    local deaths = player.respawnCount
    if time > 30 or deaths > 10 then
        rating = "C"
    elseif time > 20 or deaths > 5 then
        rating = "B"
    elseif time > 12 or deaths > 2 then
        rating = "A"
    end

    local ratingColor = {
        S = { 255, 230, 80, 255 },
        A = { 100, 255, 150, 255 },
        B = { 100, 200, 255, 255 },
        C = { 200, 200, 200, 255 },
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 20, 22, 30, 240 },
        children = {
            UI.Panel {
                width = 380,
                borderRadius = 12,
                backgroundColor = { 35, 38, 50, 255 },
                borderWidth = 1,
                borderColor = { 70, 75, 90, 255 },
                alignItems = "center",
                padding = 32,
                gap = 16,
                children = {
                    -- 标题
                    UI.Label {
                        text = textConfig.finishTitle,
                        fontSize = 24,
                        fontWeight = "bold",
                        color = { 255, 230, 80, 255 },
                    },
                    -- 关卡名
                    UI.Label {
                        text = levelName or "D1 校准",
                        fontSize = 14,
                        color = { 150, 150, 170, 200 },
                    },
                    -- 评价
                    UI.Label {
                        text = rating,
                        fontSize = 56,
                        fontWeight = "bold",
                        color = ratingColor[rating],
                        marginTop = 8,
                    },
                    -- 数据行
                    UI.Panel {
                        width = "100%",
                        gap = 8,
                        marginTop = 8,
                        children = {
                            UIManager._statRow("用时", string.format("%.2f 秒", time)),
                            UIManager._statRow("死亡", string.format("%d 次", deaths)),
                        },
                    },
                    -- 按钮组
                    UI.Panel {
                        flexDirection = "row",
                        gap = 12,
                        marginTop = 20,
                        children = {
                            UI.Button {
                                text = "再来一次",
                                variant = "primary",
                                width = 120,
                                onClick = function(self)
                                    EventBus.emit("ui_retry_level", {})
                                end,
                            },
                            UI.Button {
                                text = "选择关卡",
                                variant = "outline",
                                width = 120,
                                onClick = function(self)
                                    EventBus.emit("ui_goto_level_select", {})
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    UI.SetRoot(root, true)
end

--- 数据行辅助（左标签 + 右数值）
function UIManager._statRow(label, value)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        paddingLeft = 16,
        paddingRight = 16,
        paddingTop = 4,
        paddingBottom = 4,
        children = {
            UI.Label {
                text = label,
                fontSize = 16,
                color = { 180, 180, 200, 200 },
            },
            UI.Label {
                text = value,
                fontSize = 16,
                fontWeight = "bold",
                color = { 255, 255, 255, 230 },
            },
        },
    }
end

-- ============================================================================
-- 隐藏 HUD（进入非游戏页面时清空，防止残留）
-- ============================================================================

function UIManager.hideFinish()
    -- 兼容旧调用，现在通过 showPlayingHud 重建
    if currentScreen == "result" then
        UIManager.showPlayingHud()
    end
end

--- 获取当前页面状态
function UIManager.getScreen()
    return currentScreen
end

return UIManager
