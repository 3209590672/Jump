-- ============================================================================
-- HUD 文案配置
-- 所有玩家可见的文本集中在此，方便策划修改和后续本地化
-- ============================================================================
return {
    -- 操作提示（底部）
    controlsHint = "A/D 移动 | 鼠标瞄准 | 左键开火 | R 重新开始",

    -- 通关面板
    finishTitle = "校准完成",
    finishTimeLabel = "用时：%.2f 秒",
    finishDeathsLabel = "死亡：%d 次",
    finishComment = "你已获得被后坐力伤害的资格。",
    finishRetryHint = "按 R 重新挑战",
    finishRetryButton = "再来一次",

    -- HUD 标签
    timeLabel = "用时：%.2fs",
    deathsLabel = "死亡：%d",
    airShotsLabel = "开枪机会：%d/%d",
}
