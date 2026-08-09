local data = require('util/ymkit_item_stats').jiandao
local prefab_id = data.prefab_id
local hammer_mode_tag = data.hammer_mode_tag
local config = TUNING.YMKIT_CONFIG
local TrueDamage = require 'util/ymkit_true_damage'

local assets = {
    Asset('ANIM', 'anim/dajiandao.zip'),
    Asset('ANIM', 'anim/swap_gwenshears.zip'),
    Asset('ATLAS', 'images/inventoryimages/gwen_jiandao.xml'),
    Asset('IMAGE', 'images/inventoryimages/gwen_jiandao.tex'),
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol('swap_object', 'swap_gwenshears', 'swap_shears')
    owner.AnimState:Show('ARM_carry')
    owner.AnimState:Hide('ARM_normal')
    TrueDamage.Enable(owner)
end

local function onunequip(inst, owner)
    owner.AnimState:Hide('ARM_carry')
    owner.AnimState:Show('ARM_normal')
    TrueDamage.Disable(owner)
end

local function set_mode(inst, hammer_mode)
    local tool = inst.components.tool
    tool.actions[ACTIONS.HAMMER] = nil
    -- 官方工具动作按标签 HAMMER_tool 提供（componentactions.lua EQUIPPED/tool），
    -- 切回分解形态时必须同时移除标签，否则锤子交互仍会显示；
    -- 且 DoToolWork 读 GetEffectiveness 返回 0，执行后就是 0 伤害。
    inst:RemoveTag(ACTIONS.HAMMER.id .. '_tool')
    if hammer_mode then
        tool:SetAction(ACTIONS.HAMMER, data.tools[1].effectiveness)
        inst:AddTag(hammer_mode_tag)
    else
        inst:RemoveTag(hammer_mode_tag)
    end
end

local function onsave(inst, saved)
    saved.hammer_mode = inst:HasTag(hammer_mode_tag)
end

local function onload(inst, saved)
    inst:SetMode(saved ~= nil and saved.hammer_mode == true and config.hammer or false)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddFollower()
    inst.entity:AddSoundEmitter()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, 'med', 0.07, 0.71)

    inst.AnimState:SetBank('dajiandao')
    inst.AnimState:SetBuild('dajiandao')
    inst.AnimState:PlayAnimation('idle')
    inst:AddTag('sharp')
    inst:AddTag('pointy')
    inst:AddTag('jiandao')
    inst:AddTag('weapon')
    inst:AddTag('nosteal')
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inventoryitem')
    inst.components.inventoryitem.imagename = 'gwen_jiandao'
    inst.components.inventoryitem.atlasname = 'images/inventoryimages/gwen_jiandao.xml'

    inst:AddComponent('inspectable')

    inst:AddComponent('ymkit_dismantle')

    inst:AddComponent('planardamage')
    inst.components.planardamage:SetBaseDamage(data.planardmg)

    inst:AddComponent('weapon')
    inst.components.weapon:SetDamage(config.jiandao_damage)
    inst.components.weapon:SetRange(data.range, 2)

    inst:AddComponent('tool')
    inst.SetMode = set_mode
    inst:SetMode(false)

    inst:AddComponent('equippable')
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = data.walkspeedmult
    inst.components.equippable.insulated = true

    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab('common/inventory/' .. prefab_id, fn, assets)
