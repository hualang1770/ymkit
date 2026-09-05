-- ============================================================================
--  青年的工具 · 交互动作统一注册
--  ---------------------------------------------------------------------------
--  所有工具的右键/左键/隔空/队列交互都从这里注册。公共逻辑在 ymkit_core.lua，
--  工具数据在 ymkit_item_stats.lua，本文件只负责“每个工具注册什么”。
-- ============================================================================

-- ymkit_core.lua 需要模组环境函数（AddAction 等），必须用 modimport 加载
modimport('scripts/util/ymkit_core.lua')
local core = TUNING.YMKIT_CORE
local stats = require 'util/ymkit_item_stats'
local config = TUNING.YMKIT_CONFIG

local axe = stats.battleaxe
local jiandao = stats.jiandao
local powerstaff = stats.powerstaff
local axe_actions = {}
local jiandao_actions = {}
local fast_pick = nil
local can_fast_pick = nil
local fast_harvest = nil
local can_fast_harvest = nil

----------------------------------------------------------------------------
-- 一、黑曜石战斧
----------------------------------------------------------------------------
do
    local prefab_id = axe.prefab_id
    local dig_mode_tag = axe.dig_mode_tag

    -- 右键切换挖掘/收割形态（仅两个形态都开启时有意义）
    axe_actions.toggle_mode = core.make_toggle_action('YMKIT_TOGGLE_MODE', '切换为挖掘形态', {
        prefab_id = prefab_id,
        setter = 'SetToolMode',
        mode_tag = dig_mode_tag,
        off_label = '切换为挖掘形态',
        on_label = '切换为收割形态',
        can_toggle = function()
            return config.dig and config.harvest
        end,
    })

    -- 快速采集：独立于形态与开关，手持战斧即可对可采集物快速采集
    local official_pick = ACTIONS.PICK
    fast_pick = core.make_fast_action('YMKIT_FAST_PICK', official_pick, 1)

    can_fast_pick = function(weapon, doer, target, right)
        return not right
            and (core.is_equipped_by(weapon, doer, axe.prefab_id)
                or core.is_equipped_by(weapon, doer, powerstaff.prefab_id))
            and target ~= nil
            and not target:HasAnyTag('INLIMBO', 'fire', 'intense')
            and target:HasAnyTag('pickable', 'searchable')
    end
    fast_pick.validfn = function(action)
        return can_fast_pick(action.invobject, action.doer, action.target, false)
            and (official_pick.validfn == nil or official_pick.validfn(action))
    end
    axe_actions.fast_pick = fast_pick
    axe_actions.can_fast_pick = can_fast_pick

    -- 快速收获：力量魔杖保持原有收获范围；战斧只额外兼容已完成烹饪的锅。
    local official_harvest = ACTIONS.HARVEST
    fast_harvest = core.make_fast_action('YMKIT_FAST_HARVEST', official_harvest, 1)
    local harvest_tags = {
        'readyforharvest',
        'withered',
        'dried',
        'harvestable',
        'occupied',
        'tapped_harvestable',
        'donecooking',
    }
    can_fast_harvest = function(weapon, doer, target, right)
        if right
            or target == nil
            or target:HasAnyTag('INLIMBO', 'fire', 'intense') then
            return false
        end

        if core.is_equipped_by(weapon, doer, powerstaff.prefab_id) then
            return target:HasAnyTag(unpack(harvest_tags))
        end
        return core.is_equipped_by(weapon, doer, axe.prefab_id)
            and target:HasTag('donecooking')
            and not target:HasTag('burnt')
    end
    fast_harvest.validfn = function(action)
        return can_fast_harvest(action.invobject, action.doer, action.target, false)
            and (official_harvest.validfn == nil or official_harvest.validfn(action))
    end

    -- 快速捕虫（动画替换为快速挥击，避免手持战斧出现捕虫网模型）
    local fast_net = nil
    local can_fast_net = nil
    if config.net then
        local official_net = ACTIONS.NET
        local net_string = type(official_net.str) == 'table'
            and official_net.str.GENERIC
            or official_net.str
        if type(net_string) ~= 'string' then
            net_string = '捕虫'
        end

        fast_net = AddAction(
            'YMKIT_FAST_NET',
            net_string,
            function(action)
                return official_net.fn(action)
            end
        )
        fast_net.canforce = official_net.canforce
        fast_net.mount_valid = official_net.mount_valid
        fast_net.rangecheckfn = official_net.rangecheckfn
        fast_net.extra_arrive_dist = official_net.extra_arrive_dist
        fast_net.priority = 99
        fast_net.theme_music_fn = official_net.theme_music_fn
        fast_net.stroverridefn = function(action)
            return GetActionString(
                official_net.id,
                official_net.strfn ~= nil and official_net.strfn(action) or nil
            )
        end

        can_fast_net = function(weapon, doer, target, right)
            if right
                or not core.is_equipped_by(weapon, doer, prefab_id)
                or target == nil
                or target:HasAnyTag('INLIMBO', 'fire', 'intense') then
                return false
            end
            if target:HasTag('NET_workable') then
                return true
            end
            -- 服务端兜底：直接检查可工作组件的工作动作是否为捕虫
            local workable = target.components ~= nil and target.components.workable or nil
            return workable ~= nil
                and workable.GetWorkAction ~= nil
                and workable:GetWorkAction() == ACTIONS.NET
        end
        fast_net.validfn = function(action)
            -- 与官方捕虫一致：目标需可被捕捉才显示动作
            return can_fast_net(action.invobject, action.doer, action.target, false)
        end

        core.add_handler('wilson', ActionHandler(fast_net, 'dojostleaction'))
        core.add_handler('wilson_client', ActionHandler(fast_net, 'dojostleaction'))

        local function can_queue_fast_net(target)
            local player = ThePlayer
            return player ~= nil
                and can_fast_net(core.get_equipped_weapon(player), player, target, false)
        end

        core.add_queuer_postinit(function(self)
            if self.AddAction == nil then
                return
            end
            self.AddAction('leftclick', fast_net, can_queue_fast_net)
            self.AddAction('allclick', fast_net, can_queue_fast_net)
            self.AddAction('autocollect', fast_net, can_queue_fast_net)
        end)
        core.add_queuer_action('leftclick', fast_net, can_queue_fast_net)
        core.add_queuer_action('allclick', fast_net, can_queue_fast_net)
        core.add_queuer_action('autocollect', fast_net, can_queue_fast_net)
    end
    axe_actions.fast_net = fast_net
    axe_actions.can_fast_net = can_fast_net

    -- 隔空工具（铲/矿/砍）
    axe_actions.remote_tools = {}
    for _, definition in ipairs(axe.tools) do
        if config.remote and definition.remote and config[definition.config] then
            local entry = core.create_remote_tool(definition, {
                prefix = 'YMKIT_REMOTE_',
                prefab_id = prefab_id,
                require_tag = definition.action .. '_tool',
            })
            table.insert(axe_actions.remote_tools, entry)
        end
    end

    -- 快速采集：状态与队列（与形态无关，始终注册，由 can_fast_pick 把关）
    core.add_handler('wilson', ActionHandler(fast_pick, 'dojostleaction'))
    core.add_handler('wilson_client', ActionHandler(fast_pick, 'dojostleaction'))
    core.add_handler('wilson', ActionHandler(fast_harvest, 'dojostleaction'))
    core.add_handler('wilson_client', ActionHandler(fast_harvest, 'dojostleaction'))

    local function can_queue_fast_pick(target)
        local player = ThePlayer
        return player ~= nil
            and can_fast_pick(core.get_equipped_weapon(player), player, target, false)
    end

    local function can_queue_fast_harvest(target)
        local player = ThePlayer
        return player ~= nil
            and can_fast_harvest(core.get_equipped_weapon(player), player, target, false)
    end

    core.add_queuer_postinit(function(self)
        if self.AddAction == nil then
            return
        end
        self.AddAction('leftclick', fast_pick, can_queue_fast_pick)
        self.AddAction('autocollect', fast_pick, can_queue_fast_pick)
        self.AddAction('leftclick', fast_harvest, can_queue_fast_harvest)
        self.AddAction('autocollect', fast_harvest, can_queue_fast_harvest)
    end)
    core.add_queuer_action('leftclick', fast_pick, can_queue_fast_pick)
    core.add_queuer_action('autocollect', fast_pick, can_queue_fast_pick)
    core.add_queuer_action('leftclick', fast_harvest, can_queue_fast_harvest)
    core.add_queuer_action('autocollect', fast_harvest, can_queue_fast_harvest)

    -- 空格键（动作键）映射：采集/捕虫改为快速动作，隔空工具不占用空格
    core.add_postinit('playercontroller', function(self)
        local get_action_button_action = self.GetActionButtonAction
        self.GetActionButtonAction = function(controller, ...)
            local action = get_action_button_action(controller, ...)
            if action == nil or action.action == nil then
                return action
            end

            local weapon = core.get_equipped_weapon(controller.inst)
            if weapon ~= nil
                and (weapon.prefab == axe.prefab_id or weapon.prefab == powerstaff.prefab_id) then
                local target = action.target
                if action.action == ACTIONS.PICK
                    and can_fast_pick(weapon, controller.inst, target, false) then
                    return BufferedAction(controller.inst, target, fast_pick, weapon)
                elseif action.action == ACTIONS.HARVEST
                    and can_fast_harvest(weapon, controller.inst, target, false) then
                    return BufferedAction(controller.inst, target, fast_harvest, weapon)
                elseif weapon.prefab == axe.prefab_id
                    and action.action == ACTIONS.NET
                    and fast_net ~= nil
                    and can_fast_net(weapon, controller.inst, target, false) then
                    return BufferedAction(controller.inst, target, fast_net, weapon)
                end
            end
            return action
        end
    end)

    -- 隔空工具注册：状态、处理器、队列
    for _, entry in ipairs(axe_actions.remote_tools) do
        core.register_remote_tool(entry)
    end

    if #axe_actions.remote_tools > 0 then
        local function make_queue_test(entry, category)
            return function(target)
                local weapon = core.get_equipped_weapon(ThePlayer)
                if not core.can_remote_tool(
                    entry,
                    weapon,
                    ThePlayer,
                    target,
                    entry.official.rmb == true
                ) then
                    return false
                end

                return category ~= 'noworkdelay'
                    or entry.official ~= ACTIONS.NET
                    or ThePlayer.components.locomotor == nil
                    or not target:HasTag('butterfly')
            end
        end

        core.register_queuer(
            axe_actions.remote_tools,
            function(entry)
                return entry.definition.queue
            end,
            make_queue_test
        )

        -- RB3 4.3 只对原版 CHOP 动作隔离高树。战斧使用自定义隔空砍树动作，
        -- 第二次点击高树时临时映射回 CHOP，让 RB3 复用其高树筛选分支。
        local remote_chop = nil
        for _, entry in ipairs(axe_actions.remote_tools) do
            if entry.official == ACTIONS.CHOP then
                remote_chop = entry.remote
                break
            end
        end
        if remote_chop ~= nil then
            local tall_tree_prefabs = {
                evergreen = true,
                evergreen_sparse = true,
                deciduoustree = true,
                moon_tree = true,
                twiggytree = true,
                palmconetree = true,
            }
            core.add_queuer_postinit(function(self)
                if self.CherryPick == nil then
                    return
                end
                local cherry_pick = self.CherryPick
                self.CherryPick = function(queuer, rightclick)
                    local last = queuer.last_click
                    if last ~= nil
                        and last.action == remote_chop
                        and tall_tree_prefabs[last.prefab]
                        and last.AnimState ~= nil
                        and (last.AnimState:IsCurrentAnimation('sway1_loop_tall')
                            or last.AnimState:IsCurrentAnimation('sway2_loop_tall')) then
                        last.action = ACTIONS.CHOP
                    end
                    return cherry_pick(queuer, rightclick)
                end
            end)
        end
    end
end

----------------------------------------------------------------------------
-- 二、魔法剪刀
----------------------------------------------------------------------------
do
    local prefab_id = jiandao.prefab_id
    local hammer_mode_tag = jiandao.hammer_mode_tag

    if config.jiandao then
        -- 右键切换分解/锤子形态
        if config.hammer then
            jiandao_actions.toggle_mode = core.make_toggle_action('YMKIT_JIANDAO_TOGGLE_MODE', '切换为锤子形态', {
                prefab_id = prefab_id,
                setter = 'SetMode',
                mode_tag = hammer_mode_tag,
                off_label = '切换为锤子形态',
                on_label = '切换为分解形态',
            })
        end

        -- 剪刀剪开（拆解物品返还材料）
        local dismantle = AddAction(
            'YMKIT_DISMANTLE',
            '剪刀剪开',
            function(act)
                local target = act.target
                local invobject = act.invobject
                local doer = act.doer
                if invobject == nil then
                    return true
                end
                if target ~= nil then
                    local can_dismantle, reason = invobject.components.ymkit_dismantle:CanDismantle(target, doer)
                    if can_dismantle then
                        invobject.components.ymkit_dismantle:Dismantle(target, doer)
                    end
                    return can_dismantle, reason
                end
            end
        )
        dismantle.priority = 99
        if config.jiandao_remote then
            dismantle.distance = math.huge
            dismantle.do_not_locomote = true
        else
            dismantle.distance = 3
        end

        local function recipe_blocked(target)
            local recipe = AllRecipes[target.prefab]
            if recipe == nil then
                return true
            end
            local flag = recipe.no_deconstruction
            if flag == nil then
                return false
            end
            if type(flag) == 'function' then
                return flag(target)
            end
            return flag
        end

        local function can_dismantle_target(inst, target, right)
            if target == nil
                or target:HasTag('player')
                or target:HasTag('nomagic')
                or inst.prefab ~= prefab_id
                or inst:HasTag(hammer_mode_tag)
                or recipe_blocked(target) then
                return false
            end
            return right
        end

        AddComponentAction('USEITEM', 'inventoryitem', function(inst, doer, target, actions, right)
            if can_dismantle_target(inst, target, right) then
                table.insert(actions, ACTIONS.YMKIT_DISMANTLE)
            end
        end)

        AddComponentAction('EQUIPPED', 'inventoryitem', function(inst, doer, target, actions, right)
            if can_dismantle_target(inst, target, right) then
                table.insert(actions, ACTIONS.YMKIT_DISMANTLE)
            end
        end)

        -- 拆解快速动作状态
        local dismantle_fast = {
            name = 'ymkit_jiandao_fast_dismantle',
            animation = 'atk',
            pretag = 'predismantle',
            worktag = 'dismantling',
            work_frame = 2,
            end_frame = 4,
        }
        core.add_fast_action_states(dismantle_fast)
        core.add_handler('wilson', ActionHandler(ACTIONS.YMKIT_DISMANTLE, dismantle_fast.name))
        core.add_handler('wilson_client', ActionHandler(ACTIONS.YMKIT_DISMANTLE, dismantle_fast.name))

        -- ActionQueue RB3 兼容：按住列队键 + 右键/双击右键批量拆解
        local function can_queue_dismantle(target)
            local player = ThePlayer
            if player == nil or player.replica.inventory == nil or target == nil or not target:IsValid() then
                return false
            end
            local jiandao_inst
            local active = player.replica.inventory:GetActiveItem()
            local equipped = player.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if active ~= nil and active.prefab == prefab_id then
                jiandao_inst = active
            elseif equipped ~= nil and equipped.prefab == prefab_id then
                jiandao_inst = equipped
            end
            if jiandao_inst == nil or jiandao_inst:HasTag(hammer_mode_tag) then
                return false
            end
            if target:HasTag('player') or target:HasTag('nomagic') then
                return false
            end
            return not recipe_blocked(target)
        end

        core.add_queuer_postinit(function(self)
            if self.AddAction == nil then
                return
            end
            self.AddAction('rightclick', ACTIONS.YMKIT_DISMANTLE, can_queue_dismantle)
        end)
        core.add_queuer_action('rightclick', ACTIONS.YMKIT_DISMANTLE, can_queue_dismantle)

        -- 隔空锤子
        jiandao_actions.remote_tools = {}
        for _, definition in ipairs(jiandao.tools) do
            if config.jiandao_remote and definition.remote and config[definition.config] then
                local entry = core.create_remote_tool(definition, {
                    prefix = 'YMKIT_JIANDAO_REMOTE_',
                    prefab_id = prefab_id,
                    require_tag = hammer_mode_tag,
                })
                table.insert(jiandao_actions.remote_tools, entry)
            end
        end

        -- 使用剪刀动作时不自动装备到手上，方便连续使用
        local no_autoequip_actions = {[ACTIONS.YMKIT_DISMANTLE] = true}
        if #jiandao_actions.remote_tools > 0 then
            for _, entry in ipairs(jiandao_actions.remote_tools) do
                core.register_remote_tool(entry)
                no_autoequip_actions[entry.remote] = true
            end

            local function make_queue_test(entry)
                return function(target)
                    local weapon = core.get_equipped_weapon(ThePlayer)
                    return core.can_remote_tool(
                        entry,
                        weapon,
                        ThePlayer,
                        target,
                        entry.definition.rmb or entry.official.rmb == true
                    )
                end
            end

            core.register_queuer(
                jiandao_actions.remote_tools,
                function(entry)
                    return entry.definition.queue
                end,
                function(entry, category)
                    return make_queue_test(entry)
                end
            )
        end

        core.add_postinit('playercontroller', function(self)
            local DoActionAutoEquip = self.DoActionAutoEquip
            function self:DoActionAutoEquip(buffaction)
                if buffaction ~= nil and no_autoequip_actions[buffaction.action] then
                    return
                end
                DoActionAutoEquip(self, buffaction)
            end
        end)
    end
end

----------------------------------------------------------------------------
-- 三、力量魔杖：快速采集（与战斧共用 fast_pick 动作，同更多物品橙杖机制）
do
    local prefab_id = powerstaff.prefab_id

    -- 快速拿取：与快速采集同机制，对齐更多物品橙杖的快速交互
    local fast_takeitem = core.make_fast_action('YMKIT_FAST_TAKEITEM', ACTIONS.TAKEITEM, 1)

    core.add_handler('wilson', ActionHandler(fast_takeitem, 'dojostleaction'))
    core.add_handler('wilson_client', ActionHandler(fast_takeitem, 'dojostleaction'))

    -- 拿取合法性：与官方 TAKEITEM 的提供条件一致（标签判定）
    local function can_fast_takeitem(weapon, doer, target, right)
        return not right
            and core.is_equipped_by(weapon, doer, prefab_id)
            and target ~= nil
            and not target:HasAnyTag('INLIMBO', 'fire', 'intense')
            and (target:HasTag('inventoryitemholder_take') or target:HasTag('takeshelfitem'))
    end
    fast_takeitem.validfn = function(action)
        return can_fast_takeitem(action.invobject, action.doer, action.target, false)
    end

    -- 力量魔杖没有 tool 组件，通过武器组件提供左键快速采集/收获/拿取入口
    AddComponentAction('EQUIPPED', 'weapon', function(inst, doer, target, actions, right)
        if inst.prefab == prefab_id and not right and target ~= nil then
            if can_fast_pick(inst, doer, target, right) then
                table.insert(actions, fast_pick)
            elseif can_fast_harvest(inst, doer, target, right) then
                table.insert(actions, fast_harvest)
            elseif can_fast_takeitem(inst, doer, target, right) then
                table.insert(actions, fast_takeitem)
            end
        end
    end)

    -- 动作键映射：收获与采集已在战斧段统一映射，这里只处理拿取。
    core.add_postinit('playercontroller', function(self)
        local get_action_button_action = self.GetActionButtonAction
        self.GetActionButtonAction = function(controller, ...)
            local action = get_action_button_action(controller, ...)
            if action == nil or action.action == nil then
                return action
            end

            local weapon = core.get_equipped_weapon(controller.inst)
            if weapon ~= nil and weapon.prefab == prefab_id then
                local target = action.target
                if action.action == ACTIONS.TAKEITEM
                    and can_fast_takeitem(weapon, controller.inst, target, false) then
                    return BufferedAction(controller.inst, target, fast_takeitem, weapon)
                end
            end
            return action
        end
    end)
end

-- 四、统一组件动作分发
-- 同一 (动作类型, 组件) 只注册一次，按 prefab 分发到对应工具的动作
----------------------------------------------------------------------------
AddComponentAction('INVENTORY', 'equippable', function(inst, doer, actions)
    if inst.prefab == axe.prefab_id and core.is_equipped_by(inst, doer, axe.prefab_id) then
        table.insert(actions, axe_actions.toggle_mode)
    elseif jiandao_actions.toggle_mode ~= nil
        and inst.prefab == jiandao.prefab_id
        and core.is_equipped_by(inst, doer, jiandao.prefab_id) then
        table.insert(actions, jiandao_actions.toggle_mode)
    end
end)

AddComponentAction('INVENTORY', 'inventoryitem', function(inst, doer, actions)
    if inst.prefab == axe.prefab_id and core.is_equipped_by(inst, doer, axe.prefab_id) then
        table.insert(actions, axe_actions.toggle_mode)
    elseif jiandao_actions.toggle_mode ~= nil
        and inst.prefab == jiandao.prefab_id
        and core.is_equipped_by(inst, doer, jiandao.prefab_id) then
        table.insert(actions, jiandao_actions.toggle_mode)
    end
end)

AddComponentAction('EQUIPPED', 'tool', function(inst, doer, target, actions, right)
    if inst.prefab == axe.prefab_id then
        if axe_actions.can_fast_pick(inst, doer, target, right) then
            table.insert(actions, axe_actions.fast_pick)
            return
        end
        if can_fast_harvest(inst, doer, target, right) then
            table.insert(actions, fast_harvest)
            return
        end
        if axe_actions.fast_net ~= nil and axe_actions.can_fast_net(inst, doer, target, right) then
            table.insert(actions, axe_actions.fast_net)
            return
        end
        for _, entry in ipairs(axe_actions.remote_tools) do
            if core.can_remote_tool(entry, inst, doer, target, right) then
                table.insert(actions, entry.remote)
                return
            end
        end
    elseif inst.prefab == jiandao.prefab_id then
        for _, entry in ipairs(jiandao_actions.remote_tools) do
            if right and core.can_remote_tool(entry, inst, doer, target, right) then
                table.insert(actions, entry.remote)
                return
            end
        end
    end
end)

----------------------------------------------------------------------------
-- 四、万物生长：读书催熟
----------------------------------------------------------------------------
do
    local growth_fallacy = stats.growth_fallacy
    local growth_action = AddAction(
        'YMKIT_GROWTH_FALLACY',
        '读',
        function(act)
            local inst = act.invobject
            local doer = act.doer
            local inventoryitem = inst ~= nil and inst.components.inventoryitem or nil

            if inst == nil
                or not inst:IsValid()
                or doer == nil
                or not doer:IsValid()
                or inventoryitem == nil
                or inventoryitem:GetGrandOwner() ~= doer
                or inst.components.finiteuses == nil
                or inst.DoGrowthFallacy == nil then
                return false
            end

            return inst:DoGrowthFallacy(doer)
        end
    )
    growth_action.priority = 99
    growth_action.mount_valid = true

    core.add_handler('wilson', ActionHandler(growth_action, 'book'))
    core.add_handler('wilson_client', ActionHandler(growth_action, 'book'))

    AddComponentAction('INVENTORY', 'inventoryitem', function(inst, doer, actions)
        if inst.prefab == growth_fallacy.prefab_id
            and doer ~= nil
            and doer:HasTag('player') then
            table.insert(actions, growth_action)
        end
    end)
end
