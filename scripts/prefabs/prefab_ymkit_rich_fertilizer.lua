-- 高效肥料（ymkit_rich_fertilizer）
-- 使用原版肥料的部署、研究、漂浮和熄灭机制；数值与配方由统一属性表配置。

local data = require('util/ymkit_item_stats').rich_fertilizer
local config = TUNING.YMKIT_CONFIG

local assets = {
    Asset('ANIM', 'anim/fertilizer.zip'),
    Asset('ATLAS', data.recipe_atlas),
    Asset('IMAGE', 'images/inventoryimages/' .. data.recipe_image),
}

local function get_fertilizer_key(inst)
    return inst.prefab
end

local function fertilizer_research_fn(inst)
    return inst:GetFertilizerKey()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, 'small', 0.2, 0.95)
    MakeDeployableFertilizerPristine(inst)

    inst.AnimState:SetBank('fertilizer')
    inst.AnimState:SetBuild('fertilizer')
    inst.AnimState:PlayAnimation('idle')

    inst:AddTag('fertilizerresearchable')
    inst.GetFertilizerKey = get_fertilizer_key

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inspectable')

    inst:AddComponent('inventoryitem')
    inst.components.inventoryitem.imagename = data.recipe_image:gsub('%.tex$', '')
    inst.components.inventoryitem.atlasname = data.recipe_atlas

    inst:AddComponent('fertilizerresearchable')
    inst.components.fertilizerresearchable:SetResearchFn(fertilizer_research_fn)

    inst:AddComponent('fertilizer')
    inst.components.fertilizer.fertilizervalue = TUNING.POOP_FERTILIZE
    inst.components.fertilizer.soil_cycles = TUNING.POOP_SOILCYCLES
    inst.components.fertilizer.withered_cycles = TUNING.POOP_WITHEREDCYCLES
    inst.components.fertilizer:SetNutrients(
        config.rich_fertilizer_nutrients,
        config.rich_fertilizer_nutrients,
        config.rich_fertilizer_nutrients
    )

    if config.rich_fertilizer_uses then
        inst:AddComponent('finiteuses')
        inst.components.finiteuses:SetMaxUses(config.rich_fertilizer_uses)
        inst.components.finiteuses:SetUses(config.rich_fertilizer_uses)
        inst.components.finiteuses:SetOnFinished(inst.Remove)
    else
        -- 不添加 finiteuses 时，原版 OnApplied 会在第一次施肥后删除物品。
        inst.components.fertilizer.OnApplied = function()
        end
    end

    inst:AddComponent('smotherer')

    MakeDeployableFertilizer(inst)
    MakeHauntableLaunch(inst)

    return inst
end

return Prefab('common/inventory/' .. data.prefab_id, fn, assets)
