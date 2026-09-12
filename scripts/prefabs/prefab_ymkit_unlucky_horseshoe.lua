-- 不幸马蹄铁：-1 幸运值，背包右键可与超幸运马蹄铁互相转换。

local data = require('util/ymkit_item_stats').unlucky_horseshoe

local assets = {
    Asset('ANIM', 'anim/' .. data.bank .. '.zip'),
    Asset('ATLAS', data.recipe_atlas),
    Asset('IMAGE', 'images/inventoryimages/' .. data.recipe_image),
}

local function DoShine(inst)
    inst.shinetask = nil
    if not inst.AnimState:IsCurrentAnimation('sparkle') then
        inst.AnimState:PlayAnimation('sparkle')
        inst.AnimState:PushAnimation('idle', false)
    end
    if not inst:IsAsleep() then
        inst.shinetask = inst:DoTaskInTime(4 + math.random() * 5, DoShine)
    end
end

local function OnEntityWake(inst)
    if inst.shinetask == nil then
        inst.shinetask = inst:DoTaskInTime(4 + math.random() * 5, DoShine)
    end
end

local function GetLuckFn(inst, owner)
    return -1
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(data.bank)
    inst.AnimState:SetBuild(data.bank)
    inst.AnimState:PlayAnimation('idle')

    inst.pickupsound = 'metal'

    inst:AddTag('unluckyitem')
    inst:AddTag(data.prefab_id)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inspectable')

    inst:AddComponent('inventoryitem')
    inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem.imagename = data.image
    inst.components.inventoryitem.atlasname = data.recipe_atlas

    inst:AddComponent('stackable')
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    inst:AddComponent('luckitem')
    inst.components.luckitem:SetLuck(GetLuckFn)

    inst:AddComponent('ymkit_horseshoe_transform')
    inst.components.ymkit_horseshoe_transform.lucky = false

    MakeHauntableLaunch(inst)

    DoShine(inst)
    inst.OnEntityWake = OnEntityWake

    return inst
end

return Prefab(data.prefab_id, fn, assets)
