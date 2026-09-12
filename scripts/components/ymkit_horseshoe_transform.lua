-- 马蹄铁转换：背包右键把超幸运马蹄铁与不幸马蹄铁互相转换，保留堆叠数量。
local HorseshoeTransform = Class(function(self, inst)
    self.inst = inst
    self.lucky = true
    self.lucky_transformitem = 'ymkit_lucky_horseshoe'
    self.unlucky_transformitem = 'ymkit_unlucky_horseshoe'
end)

function HorseshoeTransform:Do()
    local inst = self.inst
    if inst == nil or not inst:IsValid() then
        return false
    end

    local target = SpawnPrefab(self.lucky and self.unlucky_transformitem or self.lucky_transformitem)
    if target == nil then
        return false
    end

    local stack_size = inst.components.stackable ~= nil and inst.components.stackable.stacksize or 1

    local container = inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetContainer() or nil
    if container ~= nil then
        local slot = inst.components.inventoryitem:GetSlotNum()
        inst:Remove()
        if target.components.stackable ~= nil then
            target.components.stackable:SetStackSize(stack_size)
        end
        container:GiveItem(target, slot)
    else
        local x, y, z = inst.Transform:GetWorldPosition()
        inst:Remove()
        if target.components.stackable ~= nil then
            target.components.stackable:SetStackSize(stack_size)
        end
        target.Transform:SetPosition(x, y, z)
    end
    return true
end

return HorseshoeTransform
