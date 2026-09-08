-- 力量魔杖（ymkit_powerstaff）
-- 基于更多物品 mone_orangestaff，无耐久、无限使用；
-- 沃尔夫冈肌肉保留可配置（dumbbell 标签，原版 Mightiness:DoDec 检测）

local data = require('util/ymkit_item_stats').powerstaff
local config = TUNING.YMKIT_CONFIG

local assets = {
    Asset('ANIM', 'anim/staffs.zip'),
    Asset('ANIM', 'anim/swap_staffs.zip'),
    Asset('ATLAS', 'images/inventoryimages/ymkit_powerstaff.xml'),
    Asset('IMAGE', 'images/inventoryimages/ymkit_powerstaff.tex'),
}

local function onblink(staff, pos, caster)
    if staff.components.rechargeable then
        -- 原版 rechargeable 组件的正确用法：使用后 Discharge(冷却秒数) 开始充能
        staff.components.rechargeable:Discharge(data.recharge_time)
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsGroundTargetBlocked(pt)
end

local BLINKFOCUS_MUST_TAGS = {'blinkfocus'}

local function blinkstaff_reticuletargetfn()
    local player = ThePlayer
    local rotation = player.Transform:GetRotation()
    local pos = player:GetPosition()
    local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, TUNING.CONTROLLER_BLINKFOCUS_DISTANCE, BLINKFOCUS_MUST_TAGS)
    for _, v in ipairs(ents) do
        local epos = v:GetPosition()
        if distsq(pos, epos) > TUNING.CONTROLLER_BLINKFOCUS_DISTANCESQ_MIN then
            local angletoepos = player:GetAngleToPoint(epos)
            local angleto = math.abs(anglediff(rotation, angletoepos))
            if angleto < TUNING.CONTROLLER_BLINKFOCUS_ANGLE then
                return epos
            end
        end
    end
    rotation = rotation * DEGREES
    for r = 13, 1, -1 do
        local numtries = 2 * PI * r
        local offset = FindWalkableOffset(pos, rotation, r, numtries, false, true, NoHoles)
        if offset ~= nil then
            pos.x = pos.x + offset.x
            pos.y = 0
            pos.z = pos.z + offset.z
            return pos
        end
    end
end

local function onunequip(inst, owner)
    owner.AnimState:Hide('ARM_carry')
    owner.AnimState:Show('ARM_normal')
    if inst:GetSkinName() ~= nil then
        owner:PushEvent('unequipskinneditem', inst:GetSkinName())
    end
    -- 恢复肌肉流失（仅“完全停止”模式装备过时才需要）
    if inst._ymkit_stop_muscle then
        inst._ymkit_stop_muscle = nil
        local mightiness = owner.components.mightiness
        if mightiness ~= nil and mightiness.ratemodifiers ~= nil then
            mightiness.ratemodifiers:RemoveModifier(inst, 'ymkit_powerstaff')
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank('staffs')
    inst.AnimState:SetBuild('staffs')
    inst.AnimState:PlayAnimation('orangestaff')

    inst:AddTag('weapon')
    inst:AddTag('shadowlevel')
    -- 沃尔夫冈肌肉：dumbbell 标签（原版机制，移动时延缓流失）
    -- 配置为“完全停止”时由装备逻辑通过原版倍率表暂停流失
    inst:AddTag('dumbbell')

    local floater_swap_data = {
        sym_build = 'swap_staffs',
        sym_name = 'swap_orangestaff',
        bank = 'staffs',
        anim = 'orangestaff',
    }
    MakeInventoryFloatable(inst, 'med', 0.1, {0.9, 0.4, 0.9}, true, -13, floater_swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inspectable')

    inst:AddComponent('inventoryitem')
    inst.components.inventoryitem.imagename = 'orangestaff'
    -- 图集走默认解析：无皮肤时显示原版懒人魔杖图标，有皮肤时由皮肤系统自动切换图标
    -- （皮肤图标在原版 inventoryimages 图集里，模组自带给图集只用于配方栏）

    inst:AddComponent('tradable')

    inst:AddComponent('equippable')
    inst.components.equippable:SetOnEquip(function(inst, owner)
        local skin_build = inst:GetSkinBuild()
        if skin_build ~= nil then
            owner:PushEvent('equipskinneditem', inst:GetSkinName())
            owner.AnimState:OverrideItemSkinSymbol('swap_object', skin_build, 'swap_orangestaff', inst.GUID, 'swap_staffs')
        else
            owner.AnimState:OverrideSymbol('swap_object', 'swap_staffs', 'swap_orangestaff')
        end
        owner.AnimState:Show('ARM_carry')
        owner.AnimState:Hide('ARM_normal')
        -- 沃尔夫冈肌肉“完全停止”模式：用原版倍率表暂停流失（哑铃标签只是延缓）
        if config.wolfgang_muscle == 'stop' then
            local mightiness = owner.components.mightiness
            if mightiness ~= nil and mightiness.ratemodifiers ~= nil then
                mightiness.ratemodifiers:SetModifier(inst, 0, 'ymkit_powerstaff')
                inst._ymkit_stop_muscle = true
            end
        end
    end)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent('reticule')
    inst.components.reticule.targetfn = blinkstaff_reticuletargetfn
    inst.components.reticule.ease = true

    inst.fxcolour = {1, 145 / 255, 0}
    inst.castsound = 'dontstarve/common/staffteleport'

    inst:AddComponent('blinkstaff')
    inst.components.blinkstaff:SetFX('sand_puff_large_front', 'sand_puff_large_back')
    inst.components.blinkstaff.onblinkfn = onblink

    -- 充能冷却：完成前不能再次传送（时长由统一属性表配置）
    local old_Blink = inst.components.blinkstaff.Blink
    function inst.components.blinkstaff:Blink(pt, caster, ...)
        local rechargeable = self.inst.components.rechargeable
        if rechargeable ~= nil and not rechargeable:IsCharged() then
            return false
        end
        if old_Blink then
            return old_Blink(self, pt, caster, ...)
        end
    end

    inst:AddComponent('weapon')
    inst.components.weapon:SetDamage(data.damage)

    inst.components.equippable.walkspeedmult = data.walkspeedmult

    inst:AddComponent('shadowlevel')
    inst.components.shadowlevel:SetDefaultLevel(data.shadowlevel)

    inst:AddComponent('rechargeable')
    inst.components.rechargeable:SetChargeTime(data.recharge_time)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab('common/inventory/' .. data.prefab_id, fn, assets)
