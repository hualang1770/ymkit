local YmkitDismantle = Class(function(self, inst)
    self.inst = inst
end)

local function spawn_loot(prefab, receiver, pt)
    local loot = SpawnPrefab(prefab)
    if loot ~= nil then
        local given = false
        if receiver ~= nil then
            given = receiver:GiveItem(loot, nil, pt) ~= nil
        end
        if not given and pt ~= nil then
            loot.Transform:SetPosition(pt:Get())
        end
    end
end

local function is_no_deconstruction(recipe, target)
    local flag = recipe ~= nil and recipe.no_deconstruction or nil
    if flag == nil then
        return false
    end
    if type(flag) == 'function' then
        return flag(target)
    end
    return flag
end

function YmkitDismantle:CanDismantle(target, doer)
    if target.components.rechargeable ~= nil
        and target.components.rechargeable.IsCharged ~= nil
        and not target.components.rechargeable:IsCharged() then
        return false, 'ONCOOLDOWN'
    end
    local recipe = AllRecipes[target.prefab]
    if recipe == nil or is_no_deconstruction(recipe, target) then
        return false
    end

    return true
end

function YmkitDismantle:Dismantle(target, doer)
    local recipe = AllRecipes[target.prefab]
    if recipe == nil or is_no_deconstruction(recipe, target) then
        return
    end

    -- 原版规则：按当前耐久比例返还材料，无耐久门槛，随时可拆
    local ingredient_percent =
        (   (target.components.finiteuses ~= nil and not FunctionOrValue(recipe.decon_ignores_finiteuses, target) and target.components.finiteuses:GetPercent()) or
            (target.components.fueled ~= nil and target.components.inventoryitem ~= nil and target.components.fueled:GetPercent()) or
            (target.components.armor ~= nil and target.components.inventoryitem ~= nil and target.components.armor:GetPercent()) or
            1
        ) / (recipe.numtogive or 1)

    local is_item = target.components.inventoryitem ~= nil
    local receiver = nil
    local pt
    local count = 1

    if is_item then
        local owner = target.components.inventoryitem:GetGrandOwner()
        receiver = owner ~= nil and not owner:HasTag('pocketdimension_container') and (owner.components.inventory or owner.components.container) or nil

        -- 地面物品：材料优先放进玩家背包
        if receiver == nil and doer.components.inventory ~= nil then
            receiver = doer.components.inventory
        end

        -- 批量拆解：堆叠物品整堆拆解
        local stackable = target.components.stackable
        if stackable ~= nil
            and stackable.IsStack ~= nil and stackable:IsStack()
            and stackable.StackSize ~= nil then
            count = stackable:StackSize()
        end
    else
        -- 建筑：没有耐久概念，材料优先放进玩家背包
        if doer.components.inventory ~= nil then
            receiver = doer.components.inventory
        end
    end

    pt = target:GetPosition()

    -- 原版：拆解前先清空容器/库存内容，避免物品丢失
    if target.components.inventory ~= nil then
        target.components.inventory:DropEverything()
    end
    if target.components.container ~= nil then
        target.components.container:DropEverything(nil, true)
    end

    target:Remove()

    for _ = 1, count do
        for _, ingredient in ipairs(recipe.ingredients) do
            local item_type = ingredient.type
            -- 原版：普通宝石不返还，preciousgem（彩虹宝石）返还
            if string.sub(item_type, -3) ~= 'gem' or string.sub(item_type, -11, -4) == 'precious' then
                local amt = ingredient.amount == 0 and 0 or math.max(1, math.ceil(ingredient.amount * ingredient_percent))
                for _ = 1, amt do
                    spawn_loot(item_type, receiver, pt)
                end
            end
        end
    end

    -- 原版分解音效
    if doer.SoundEmitter ~= nil then
        doer.SoundEmitter:PlaySound('dontstarve/common/staff_dissassemble')
    end

    -- 在拆解后生成破损工具特效
    local fx = SpawnPrefab('brokentool')
    if fx ~= nil then
        fx.Transform:SetPosition(doer.Transform:GetWorldPosition())
    end
end

return YmkitDismantle
