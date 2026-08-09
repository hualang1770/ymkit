local data = require('util/ymkit_item_stats').battleaxe
local prefab_id = data.prefab_id
local config = TUNING.YMKIT_CONFIG

local assets = {
    Asset('ANIM', 'anim/' .. data.bank .. '.zip'),
    Asset('ANIM', 'anim/swap_' .. data.bank .. '.zip'),
    Asset('ATLAS', 'images/inventoryimages/' .. data.image .. '.xml'),
}

local harvest_must_tags = {'pickable'}
local harvest_cant_tags = {'INLIMBO', 'FX', 'intense'}
local miasma_must_tags = {'miasma'}
local miasma_clear_radius = 6
local miasma_clear_interval = 1

local function clear_nearby_miasma(inst)
    local inventoryitem = inst.components.inventoryitem
    local owner = inventoryitem ~= nil and inventoryitem.owner or nil
    if owner == nil
        or not owner:IsValid()
        or owner.components.inventory == nil
        or owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= inst then
        return
    end
    if TheWorld.GetMiasmaCloudCount == nil
        or TheWorld:GetMiasmaCloudCount() == 0 then
        return
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local clouds = TheSim:FindEntities(x, y, z, miasma_clear_radius, miasma_must_tags)
    for _, cloud in ipairs(clouds) do
        if cloud:IsValid()
            and not cloud.force_killed
            and cloud.ForceKillMiasma ~= nil then
            cloud:ForceKillMiasma()
        end
    end
end

local function start_clearing_miasma(inst)
    if inst._miasma_clear_task ~= nil then
        inst._miasma_clear_task:Cancel()
    end
    clear_nearby_miasma(inst)
    inst._miasma_clear_task = inst:DoPeriodicTask(
        miasma_clear_interval,
        clear_nearby_miasma
    )
end

local function stop_clearing_miasma(inst)
    if inst._miasma_clear_task ~= nil then
        inst._miasma_clear_task:Cancel()
        inst._miasma_clear_task = nil
    end
end

local function harvest_pickable(_, entity, doer)
    local pickable = entity.components.pickable
    if pickable.picksound ~= nil then
        doer.SoundEmitter:PlaySound(pickable.picksound)
    end

    local success, loot = pickable:Pick(TheWorld)
    if loot ~= nil then
        for _, item in ipairs(loot) do
            Launch(item, doer, 1.5)
        end
    end
    return success
end

local function is_entity_in_front(_, entity, doer_rotation, doer_position)
    local facing = Vector3(
        math.cos(-doer_rotation / RADIANS),
        0,
        math.sin(-doer_rotation / RADIANS)
    )
    return IsWithinAngle(
        doer_position,
        facing,
        TUNING.VOIDCLOTH_SCYTHE_HARVEST_ANGLE_WIDTH,
        entity:GetPosition()
    )
end

local function do_scythe(inst, target, doer)
    if target.components.pickable == nil then
        return
    end

    local doer_position = doer:GetPosition()
    local x, y, z = doer_position:Get()
    local doer_rotation = doer.Transform:GetRotation()
    local harvested_count = 0
    local entities = TheSim:FindEntities(
        x,
        y,
        z,
        TUNING.VOIDCLOTH_SCYTHE_HARVEST_RADIUS,
        harvest_must_tags,
        harvest_cant_tags,
        HARVESTABLE_PLANT_TARGET_TAGS
    )

    for _, entity in pairs(entities) do
        if entity:IsValid()
            and entity.components.pickable ~= nil
            and inst:IsEntityInFront(entity, doer_rotation, doer_position)
            and inst:HarvestPickable(entity, doer) then
            harvested_count = harvested_count + 1
        end
    end

    if harvested_count > 0 then
        doer:PushEvent('picksomethingfromaoe', {harvestedcount = harvested_count})
    end
end

local function remove_finished_stump(target, doer)
    local workable = target:IsValid() and target.components.workable or nil
    if doer ~= nil
        and doer:IsValid()
        and target:HasTag('stump')
        and workable ~= nil
        and workable:CanBeWorked()
        and workable:GetWorkAction() == ACTIONS.DIG then
        workable:WorkedBy(doer, 1)
    end
end

local function on_finished_work(doer, event)
    if event == nil
        or event.action ~= ACTIONS.CHOP and event.action ~= ACTIONS.DIG then
        return
    end

    local weapon = doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local tool = weapon ~= nil and weapon.components.tool or nil
    local target = event.target
    local workable = target ~= nil and target:IsValid() and target.components.workable or nil
    if weapon == nil
        or weapon.prefab ~= prefab_id
        or tool == nil
        or not tool:CanDoAction(ACTIONS.CHOP)
        or target == nil
        or not target:IsValid()
        or not target:HasTag('stump')
        or workable == nil
        or workable:GetWorkAction() ~= ACTIONS.DIG then
        return
    end

    local animation_length = target.AnimState ~= nil
        and target.AnimState:GetCurrentAnimationLength()
        or 0
    target:DoTaskInTime(
        animation_length,
        remove_finished_stump,
        doer
    )
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol('swap_object', 'swap_' .. data.bank, 'swap_' .. data.bank)
    owner.AnimState:Show('ARM_carry')
    owner.AnimState:Hide('ARM_normal')
    inst.Light:Enable(true)
    start_clearing_miasma(inst)
    owner:RemoveEventCallback('finishedwork', on_finished_work)
    owner:ListenForEvent('finishedwork', on_finished_work)
end

local function onunequip(inst, owner)
    owner.AnimState:Hide('ARM_carry')
    owner.AnimState:Show('ARM_normal')
    inst.Light:Enable(false)
    stop_clearing_miasma(inst)
    owner:RemoveEventCallback('finishedwork', on_finished_work)
end

local function set_tool_mode(inst, dig_mode)
    local tool = inst.components.tool
    local use_dig = config.dig and (not config.harvest or dig_mode)

    for _, definition in ipairs(data.tools) do
        local action = ACTIONS[definition.action]
        tool.actions[action] = nil
        inst:RemoveTag(action.id .. '_tool')
    end

    for _, definition in ipairs(data.tools) do
        local enabled = config[definition.config]
            and (definition.mode == nil
                or definition.mode == 'dig' and use_dig
                or definition.mode == 'harvest' and not use_dig)
        if enabled then
            tool:SetAction(ACTIONS[definition.action], definition.effectiveness)
        end
    end

    if use_dig then
        inst:AddTag(data.dig_mode_tag)
    else
        inst:RemoveTag(data.dig_mode_tag)
    end
end

local function onsave(inst, saved)
    saved.dig_mode = inst:HasTag(data.dig_mode_tag)
end

local function onload(inst, saved)
    inst:SetToolMode(saved ~= nil and saved.dig_mode == true)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()
    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(data.bank)
    inst.AnimState:SetBuild(data.bank)
    inst.AnimState:PlayAnimation('idle', true)

    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(0.8)
    inst.Light:SetRadius(TUNING.WORMLIGHT_RADIUS)
    inst.Light:SetColour(128 / 255, 20 / 255, 128 / 255)
    inst.Light:Enable(false)

    inst:AddTag('nosteal')
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inspectable')
    inst:AddComponent('inventoryitem')
    inst.components.inventoryitem.imagename = data.image
    inst.components.inventoryitem.atlasname = 'images/inventoryimages/' .. data.image .. '.xml'

    inst:AddComponent('equippable')
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = data.walkspeedmult

    inst:AddComponent('weapon')
    inst.components.weapon:SetDamage(data.damage)
    inst.components.weapon:SetRange(data.range, data.range)

    inst:AddComponent('tool')
    inst.components.tool:EnableToughWork(true)
    inst.SetToolMode = set_tool_mode
    inst:SetToolMode(false)

    local planardamage = inst:AddComponent('planardamage')
    planardamage:SetBaseDamage(data.planardmg)

    if config.harvest then
        inst.DoScythe = do_scythe
        inst.IsEntityInFront = is_entity_in_front
        inst.HarvestPickable = harvest_pickable
    end
    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab('common/inventory/' .. prefab_id, fn, assets)
