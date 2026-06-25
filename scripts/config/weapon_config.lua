-- ============================================================================
-- 武器配置
-- 所有武器走同一套字段结构，recoil_system 不写 if weapon == ... 的分支
--
-- 字段说明：
--   recoilPower          : 反冲冲量大小（px/s）
--   cooldown             : 开火冷却（秒）
--   maxAirShots          : 空中最大补枪次数
--   maxSpeedAfterRecoil  : 反冲后速度上限（px/s）
--   trajectoryPreview    : 轨迹预览模式 "full" / "partial" / "directionOnly" / "none"
--   allowAirRetarget     : 空中补枪是否可以重新瞄准（true=自由瞄准，false=只能补同方向）
--   chargeMode           : 蓄力模式 "none" / "hold" / "tap"
--
-- trajectory 子表：控制该武器的轨迹预览视觉表现
--   mode         : 与 trajectoryPreview 对应（冗余以便单独覆盖）
--   previewTime  : 预测时长（秒）
--   sampleCount  : 采样点数量
--   color        : {R, G, B, A} 轨迹点颜色
-- ============================================================================
return {
    -- D1 教学武器：校准手枪
    calibratePistol = {
        recoilPower = 700,
        cooldown = 0.32,
        maxAirShots = 1,
        maxSpeedAfterRecoil = 1100,
        trajectoryPreview = "full",
        allowAirRetarget = true,
        chargeMode = "none",
        trajectory = {
            mode = "full",
            previewTime = 1.2,
            sampleCount = 20,
            color = { 100, 200, 255, 150 },
        },
    },

    -- 预留：霰弹枪（散射 + 短距高冲量）
    -- shotgun = {
    --     recoilPower = 900,
    --     cooldown = 0.8,
    --     maxAirShots = 0,
    --     maxSpeedAfterRecoil = 1300,
    --     trajectoryPreview = "partial",
    --     allowAirRetarget = false,
    --     chargeMode = "none",
    --     trajectory = {
    --         mode = "partial",
    --         previewTime = 0.5,
    --         sampleCount = 10,
    --         color = { 255, 180, 80, 120 },
    --     },
    -- },

    -- 预留：三连发（快速三次弱冲量）
    -- burstPistol = {
    --     recoilPower = 320,
    --     cooldown = 0.12,
    --     maxAirShots = 3,
    --     maxSpeedAfterRecoil = 1000,
    --     trajectoryPreview = "directionOnly",
    --     allowAirRetarget = true,
    --     chargeMode = "none",
    --     trajectory = {
    --         mode = "directionOnly",
    --         previewTime = 0,
    --         sampleCount = 0,
    --         color = { 200, 100, 255, 100 },
    --     },
    -- },

    -- 预留：火箭筒（蓄力 + 超高冲量）
    -- rocketLauncher = {
    --     recoilPower = 1400,
    --     cooldown = 1.5,
    --     maxAirShots = 0,
    --     maxSpeedAfterRecoil = 1600,
    --     trajectoryPreview = "directionOnly",
    --     allowAirRetarget = false,
    --     chargeMode = "hold",
    --     trajectory = {
    --         mode = "directionOnly",
    --         previewTime = 0,
    --         sampleCount = 0,
    --         color = { 255, 80, 60, 140 },
    --     },
    -- },
}
