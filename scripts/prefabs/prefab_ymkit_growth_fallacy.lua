-- 万物生长：催熟逻辑属于物品自身，动作注册统一放在 ymkit_actions.lua。

local data = require('util/ymkit_item_stats').growth_fallacy

local assets = {
    Asset('ANIM', 'anim/' .. data.bank .. '.zip'),
    Asset('ATLAS', data.recipe_atlas),
    Asset('IMAGE', 'images/inventoryimages/' .. data.recipe_image),
}

local function is_valid_world_entity(inst)
    return inst ~= nil and inst:IsValid() and not inst:IsInLimbo()
end

local function process_plant(inst)
    if not is_valid_world_entity(inst)
        or (inst.components.witherable ~= nil and inst.components.witherable:IsWithered()) then
        return false
    end

    local used = false
    local farmplantstress = inst.components.farmplantstress
    if farmplantstress ~= nil then
        local tendable = inst.components.farmplanttendable
        if tendable ~= nil then
            tendable:TendTo()
        end

        inst.magic_tending = true
        if TheWorld ~= nil and TheWorld.Map ~= nil and TheWorld.components.farming_manager ~= nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            local tile_x, tile_z = TheWorld.Map:GetTileCoordsAtPoint(x, y, z)
            TheWorld.components.farming_manager:AddTileNutrients(tile_x, tile_z, 100, 100, 100)
            TheWorld.components.farming_manager:AddSoilMoistureAtPoint(tile_x, 0, tile_z, 100)
        end
        used = true
    end

    local sleeper = inst.components.sleeper
    if inst:HasTag('leif') and sleeper ~= nil then
        sleeper:GoToSleep(1000)
        used = true
    end

    local growable = inst.components.growable
    if growable ~= nil
        and (growable.magicgrowable
            or ((inst:HasTag('tree')
                or inst:HasTag('boulder')
                or inst:HasTag('plant')
                or inst:HasTag('siving_derivant')
                or inst:HasTag('peachtree')
                or inst:HasTag('winter_tree'))
                and not inst:HasTag('stump'))) then
        local simplemagicgrower = inst.components.simplemagicgrower
        if simplemagicgrower ~= nil then
            simplemagicgrower:StartGrowing()
        elseif growable.domagicgrowthfn ~= nil then
            inst.magic_growth_delay = 2
            if farmplantstress ~= nil then
                inst.force_oversized = true
            end
            growable:DoMagicGrowth()
        else
            growable:DoGrowth()
        end
        used = true
    end

    -- 生长函数可能替换源实体，后续处理前必须重新确认它仍然有效。
    if not is_valid_world_entity(inst) then
        return used
    end

    local pickable = inst.components.pickable
    if pickable ~= nil and not (pickable:CanBePicked() and pickable.caninteractwith) then
        if inst.prefab == 'red_mushroom' or inst.prefab == 'green_mushroom' or inst.prefab == 'blue_mushroom' then
            if inst.rain ~= nil and inst.rain > 0 then
                inst.rain = 0
                pickable:Regen()
                used = true
            end
        elseif not pickable:CanBePicked() and pickable:FinishGrowing() then
            if is_valid_world_entity(inst) and inst.components.pickable == pickable then
                pickable:ConsumeCycles(1)
                used = true
            end
        end
    end

    if not is_valid_world_entity(inst) then
        return used
    end

    local crop = inst.components.crop
    if crop ~= nil and (crop.rate or 0) > 0 then
        crop:DoGrow(1 / crop.rate, true)
        used = true
    end

    if not is_valid_world_entity(inst) then
        return used
    end

    local harvestable = inst.components.harvestable
    if harvestable ~= nil and harvestable:CanBeHarvested() and inst:HasTag('mushroom_farm') then
        if harvestable:IsMagicGrowable() then
            harvestable:DoMagicGrowth()
        else
            harvestable:Grow()
        end
        used = true
    end

    if not is_valid_world_entity(inst) then
        return used
    end

    local timer = inst.components.timer
    if timer ~= nil
        and type(inst.prefab) == 'string'
        and ((string.match(inst.prefab, '_sapling') and inst.growprefab ~= nil)
            or inst.prefab == 'rock_avocado_fruit_sprout_sapling')
        and timer:TimerExists('grow') then
        inst:PushEvent('timerdone', { name = 'grow' })
        used = true
    end

    if not is_valid_world_entity(inst) then
        return used
    end

    if inst:HasTag('underwater_salvageable') then
        local inventory = inst.components.inventory
        local seed = inventory ~= nil and inventory.itemslots[1] or nil
        local seedtimer = seed ~= nil and seed:IsValid() and seed.components.timer or nil
        if seedtimer ~= nil then
            if seedtimer:TimerExists('grow') then
                seed:PushEvent('timerdone', { name = 'grow' })
            else
                seedtimer:StartTimer('grow', TUNING.OCEANTREENUT_GROW_TIME + math.random() * TUNING.OCEANTREENUT_GROW_TIME_VARIANCE)
                seed:PushEvent('timerdone', { name = 'grow' })
            end
            used = true
        end
    end

    if not is_valid_world_entity(inst) then
        return used
    end

    timer = inst.components.timer
    if inst.prefab == 'oceantree' and timer ~= nil and timer:TimerExists('enriched_cooldown') then
        inst:PushEvent('timerdone', { name = 'enriched_cooldown' })
        used = true
    end

    return used
end

local function do_growth_fallacy(inst, doer)
    if doer == nil or not doer:IsValid() then
        return false
    end

    local x, y, z = doer.Transform:GetWorldPosition()
    local targets = TheSim:FindEntities(x, y, z, data.range, nil, { 'stump', 'withered', 'barren', 'INLIMBO' })

    -- 万物书的三种特殊树桩兼容。
    local stumps = TheSim:FindEntities(x, y, z, data.range, { 'stump' })
    for _, stump in pairs(stumps) do
        if stump.prefab == 'tbat_plant_crimson_maple_tree'
            or stump.prefab == 'tbat_plant_cherry_blossom_tree'
            or stump.prefab == 'tbat_plant_pear_blossom_tree' then
            table.insert(targets, stump)
        end
    end

    local used = false
    for _, target in pairs(targets) do
        if process_plant(target) then
            used = true
        end
    end

    if used then
        inst.components.finiteuses:Use(1)
    elseif doer.components.talker ~= nil then
        doer.components.talker:Say('没有可催熟的植物')
    end

    return true
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(data.bank)
    inst.AnimState:SetBuild(data.bank)
    inst.AnimState:PlayAnimation('idle')

    inst:AddTag('book')
    inst:AddTag('bookcabinet_item')
    inst:AddTag(data.prefab_id)

    MakeInventoryFloatable(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inspectable')

    inst:AddComponent('inventoryitem')
    inst.components.inventoryitem.imagename = data.image
    inst.components.inventoryitem.atlasname = data.recipe_atlas

    inst:AddComponent('finiteuses')
    inst.components.finiteuses:SetMaxUses(data.uses)
    inst.components.finiteuses:SetUses(data.uses)
    inst.components.finiteuses:SetOnFinished(inst.Remove)

    inst.DoGrowthFallacy = do_growth_fallacy

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab(data.prefab_id, fn, assets)
