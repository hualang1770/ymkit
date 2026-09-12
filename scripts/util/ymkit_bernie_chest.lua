-- ============================================================================
--  青年的工具 · 小熊箱
--  ---------------------------------------------------------------------------
--  小熊箱本身就是一个普通的 6x6 容器，唯一的特殊处理是薇洛的以太余烬：
--  原版的以太余烬只能放进玩家的口袋（inventoryitem.canonlygoinpocket），
--  从客户端点击到服务端真正入箱，一共被拦两处：
--    scripts/components/container.lua         服务端判断（RPC 入箱时）
--    scripts/components/container_replica.lua 客户端判断（不过的话点击没反应）
--  这里只对“物品是以太余烬 且 目标是小熊箱”放行，其余判断原样交给原版。
--  container_replica 是副本类，不走 inst:AddComponent，收不到 AddComponentPostInit，
--  必须用 AddClassPostConstruct 直接套在类上。
--
--  另外原版把余烬放进容器时会当成“放进口袋”去刷新薇洛的技能书
--  （owner.components.skilltreeupdater），建筑上没有这个组件会直接报错。
--  会踩到的入口不止 container:GiveItem：从超叠堆里拆出来的新余烬会继承原
--  余烬的 owner（箱子），SpawnPrefab 出来立刻就 OnPutInInventory，同样会爆。
--  所以统一拦在 inventoryitem.OnPutInInventory：归属者没有 skilltreeupdater
--  （即刷新注定报错）时先把归属指成归属者，让原版跳过那段只对玩家有意义
--  的刷新；余烬自己不消失（persists / 取消消失计时）仍由原版回调照常处理。
--
--  最后是进出的手感：原版“只能放进口袋”的物品不允许在容器之间转移，
--  余烬放在身上或熊箱里，Shift+左键都会没反应。这里只对余烬放开这一条，
--  存入和取出都交给原版 TradeItem 里的 FindBestContainer 按各容器的
--  CanTakeItemInSlot 挑目标——普通容器照旧不收余烬，所以实际只会进/出熊箱。
-- ============================================================================

local data = require('util/ymkit_item_stats').bernie_chest

local EMBER_TAG = 'willow_ember'

local function is_ember(item)
    return item ~= nil and item:HasTag(EMBER_TAG)
end

local function is_chest_ember(inst, item)
    return inst ~= nil
        and inst.prefab == data.prefab_id
        and is_ember(item)
end

----------------------------------------------------------------------------
-- 服务端容器：放行以太余烬入箱
----------------------------------------------------------------------------

AddComponentPostInit('container', function(container, inst)
    local can_take_item_in_slot = container.CanTakeItemInSlot
    if can_take_item_in_slot ~= nil then
        container.CanTakeItemInSlot = function(self, item, slot)
            local inventoryitem = item ~= nil and item.components.inventoryitem or nil
            if not is_chest_ember(self.inst, item)
                or inventoryitem == nil
                or not inventoryitem.canonlygoinpocket then
                return can_take_item_in_slot(self, item, slot)
            end
            -- 只绕开“只能放进口袋”这一条：只读容器、锁定格、itemtestfn 等照旧
            inventoryitem.canonlygoinpocket = false
            local can_take = can_take_item_in_slot(self, item, slot)
            inventoryitem.canonlygoinpocket = true
            return can_take
        end
    end
end)

----------------------------------------------------------------------------
-- 以太余烬：进容器前先标记归属，拦住原版那段只对玩家有意义的技能刷新
----------------------------------------------------------------------------

AddComponentPostInit('inventoryitem', function(inventoryitem, inst)
    if not is_ember(inst) then
        return
    end

    local on_put_in_inventory = inventoryitem.OnPutInInventory
    if on_put_in_inventory == nil then
        return
    end

    inventoryitem.OnPutInInventory = function(self, owner)
        -- item._owner 是原版余烬记录“归属玩家”的字段。归属者不是玩家口袋
        -- （箱子等建筑没有 skilltreeupdater）时先指成归属者，原版就会跳过刷新。
        if owner ~= nil and owner.components.skilltreeupdater == nil then
            self.inst._owner = owner
        end
        return on_put_in_inventory(self, owner)
    end
end)

----------------------------------------------------------------------------
-- 客户端容器副本：和服务端保持一致的放行判断
----------------------------------------------------------------------------

AddClassPostConstruct('components/container_replica', function(replica, inst)
    local can_take_item_in_slot = replica.CanTakeItemInSlot
    if can_take_item_in_slot == nil then
        return
    end

    replica.CanTakeItemInSlot = function(self, item, slot)
        local inventoryitem = item ~= nil and item.replica.inventoryitem or nil
        if not is_chest_ember(self.inst, item)
            or inventoryitem == nil
            or not inventoryitem:CanOnlyGoInPocket() then
            return can_take_item_in_slot(self, item, slot)
        end
        -- 副本里的“只能放进口袋”是网络变量，这里临时盖掉，跑完再还原
        local can_only_go_in_pocket = inventoryitem.CanOnlyGoInPocket
        inventoryitem.CanOnlyGoInPocket = function() return false end
        local can_take = can_take_item_in_slot(self, item, slot)
        inventoryitem.CanOnlyGoInPocket = can_only_go_in_pocket
        return can_take
    end
end)

----------------------------------------------------------------------------
-- 客户端格子：允许 Shift+左键搬运余烬（存入 / 取出）
----------------------------------------------------------------------------

AddClassPostConstruct('widgets/invslot', function(slot)
    local can_trade_item = slot.CanTradeItem
    if can_trade_item == nil then
        return
    end

    slot.CanTradeItem = function(self, stack_mod)
        if can_trade_item(self, stack_mod) then
            return true
        end
        -- 余烬方向：原版对“只能放进口袋”的物品一律禁止容器间转移，
        -- 这里放行，存入（余烬在身上）和取出（余烬在熊箱里）都能走通。
        -- 搬到哪去由原版 TradeItem 里的 FindBestContainer 按各容器的
        -- CanTakeItemInSlot 挑：普通容器依然不收余烬，所以只会进/出熊箱。
        local container = self.container
        local item = container ~= nil and container:GetItemInSlot(self.num) or nil
        local inventoryitem = item ~= nil and item.replica.inventoryitem or nil
        return is_ember(item)
            and inventoryitem ~= nil
            and inventoryitem:CanOnlyGoInPocket()
            and not inventoryitem:IsLockedInSlot()
    end
end)
