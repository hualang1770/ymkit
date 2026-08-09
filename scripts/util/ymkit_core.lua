-- ============================================================================
--  青年的工具 · 公共工具库
--  ---------------------------------------------------------------------------
--  所有工具共享的辅助逻辑都集中在这里：装备判断、注册辅助、
--  快速动作状态、隔空工具工厂。动作注册文件只负责“描述”，不重复实现。
-- ============================================================================

local core = {}

----------------------------------------------------------------------------
-- 手持装备判断
----------------------------------------------------------------------------

function core.get_equipped_weapon(doer)
    local inventory = doer ~= nil and doer.replica ~= nil and doer.replica.inventory or nil
    return inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
end

function core.is_equipped_by(weapon, doer, prefab_id)
    if weapon == nil or doer == nil or prefab_id == nil or weapon.prefab ~= prefab_id then
        return false
    end

    local inventoryitem = weapon.components.inventoryitem
    local equippable = weapon.components.equippable
    if inventoryitem ~= nil and equippable ~= nil then
        return equippable:IsEquipped() and inventoryitem.owner == doer
    end

    return core.get_equipped_weapon(doer) == weapon
end

----------------------------------------------------------------------------
-- 动作状态与组件后置注册
----------------------------------------------------------------------------

function core.add_state(stategraph, state)
    AddStategraphState(stategraph, state)
end

function core.add_handler(stategraph, handler)
    AddStategraphActionHandler(stategraph, handler)
end

function core.add_postinit(component, fn)
    AddComponentPostInit(component, fn)
end

-- 同时覆盖两种正常启动顺序：RB3 已加载时写入全局白名单，RB3 稍后创建
-- actionqueuer 组件时再写入实例。AddAction 按动作对象覆盖，重复写入安全。
function core.add_queuer_postinit(fn)
    AddComponentPostInit('actionqueuer', fn)
end

function core.add_queuer_action(category, action, testfn)
    if AddActionQueuerAction == nil then
        return
    end
    AddActionQueuerAction(category, action, testfn)
end

----------------------------------------------------------------------------
-- 快速动作状态（提前执行、缩短动画），所有工具共用
----------------------------------------------------------------------------

function core.get_fast_animation(inst, fast)
    return fast.woodcutter_animation ~= nil and inst:HasTag('woodcutter')
        and fast.woodcutter_animation
        or fast.animation
end

function core.finish_fast_animation(inst, fast)
    if fast.post_animation ~= nil then
        inst.AnimState:PlayAnimation(fast.post_animation)
    end
    inst.sg:GoToState('idle', fast.post_animation ~= nil)
end

function core.make_fast_server_state(fast)
    return State {
        name = fast.name,
        tags = {fast.pretag, fast.worktag, 'working'},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation(core.get_fast_animation(inst, fast))
            inst:AddTag(fast.pretag)
        end,

        timeline = {
            FrameEvent(fast.work_frame, function(inst)
                local action = inst.sg.statemem.action
                local target = action ~= nil and action.target or nil
                if fast.mining_fx
                    and target ~= nil
                    and target:IsValid()
                    and PlayMiningFX ~= nil then
                    PlayMiningFX(inst, target)
                end
                if fast.recoilstate ~= nil then
                    inst.sg.statemem.recoilstate = fast.recoilstate
                end
                if fast.sound ~= nil then
                    inst.SoundEmitter:PlaySound(fast.sound)
                end

                inst.sg:RemoveStateTag(fast.pretag)
                inst:RemoveTag(fast.pretag)
                inst:PerformBufferedAction()
            end),
            FrameEvent(fast.end_frame, function(inst)
                core.finish_fast_animation(inst, fast)
            end),
        },

        events = {
            EventHandler('unequip', function(inst)
                inst.sg:GoToState('idle')
            end),
        },

        onexit = function(inst)
            inst:RemoveTag(fast.pretag)
        end,
    }
end

function core.make_fast_client_state(fast)
    return State {
        name = fast.name,
        tags = {fast.pretag, 'working'},
        server_states = {fast.name},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            if not inst.sg:ServerStateMatches() then
                inst.AnimState:PlayAnimation(core.get_fast_animation(inst, fast))
            end
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(2)
        end,

        onupdate = function(inst)
            if inst.sg:ServerStateMatches() then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState('idle', 'noanim')
                end
            elseif inst.bufferedaction == nil then
                core.finish_fast_animation(inst, fast)
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            core.finish_fast_animation(inst, fast)
        end,
    }
end

function core.add_fast_action_states(fast)
    core.add_state('wilson', core.make_fast_server_state(fast))
    core.add_state('wilson_client', core.make_fast_client_state(fast))
end

----------------------------------------------------------------------------
-- 形态切换动作（右键切换），战斧/剪刀共用
----------------------------------------------------------------------------

-- opts: prefab_id / setter('SetToolMode'|'SetMode') / mode_tag /
--       off_label / on_label / can_toggle(可选，weapon, doer 判断是否显示)
function core.make_toggle_action(id, str, opts)
    local action = AddAction(
        id,
        str,
        function(action)
            local weapon = action.invobject
            if core.is_equipped_by(weapon, action.doer, opts.prefab_id)
                and weapon[opts.setter] ~= nil then
                weapon[opts.setter](weapon, not weapon:HasTag(opts.mode_tag))
                return true
            end
            return false
        end
    )

    action.rmb = true
    action.instant = true
    action.mount_valid = true
    action.priority = 4
    action.invalid_hold_action = true
    action.validfn = function(action)
        if not core.is_equipped_by(action.invobject, action.doer, opts.prefab_id) then
            return false
        end
        return opts.can_toggle == nil or opts.can_toggle(action.invobject, action.doer)
    end
    action.stroverridefn = function(action)
        local weapon = action.invobject
        return weapon ~= nil and weapon:HasTag(opts.mode_tag) and opts.on_label or opts.off_label
    end

    return action
end

----------------------------------------------------------------------------
-- 快速动作工厂：包装官方动作，改用快速挥击动画
----------------------------------------------------------------------------

function core.make_fast_action(id, official, priority)
    local str = type(official.str) == 'table' and official.str.GENERIC or official.str
    if type(str) ~= 'string' then
        str = official.id
    end

    local action = AddAction(
        id,
        str,
        function(action)
            return official.fn(action)
        end
    )
    action.canforce = official.canforce
    action.mount_valid = official.mount_valid
    action.rangecheckfn = official.rangecheckfn
    action.extra_arrive_dist = official.extra_arrive_dist
    action.priority = priority or 1
    action.theme_music_fn = official.theme_music_fn
    action.stroverridefn = function(action)
        return GetActionString(
            official.id,
            official.strfn ~= nil and official.strfn(action) or nil
        )
    end
    return action
end

----------------------------------------------------------------------------
-- 隔空工具工厂（远距离执行官方工具动作）
----------------------------------------------------------------------------

-- opts: prefix(动作ID前缀) / prefab_id / require_tag(需要持有的形态/工具标签)
function core.create_remote_tool(definition, opts)
    local official = ACTIONS[definition.action]
    local rmb = definition.rmb or official.rmb == true
    local remote = AddAction(
        (opts.prefix or 'YMKIT_REMOTE_') .. definition.action,
        official.str,
        function(action)
            return official.fn(action)
        end
    )

    remote.rmb = rmb
    remote.canforce = official.canforce
    remote.distance = math.huge
    remote.do_not_locomote = true
    remote.invalid_hold_action = true
    remote.priority = 4
    remote.theme_music_fn = official.theme_music_fn
    remote.validfn = function(action)
        local weapon = action.invobject
        local target = action.target
        return core.is_equipped_by(weapon, action.doer, opts.prefab_id)
            and (opts.require_tag == nil or weapon:HasTag(opts.require_tag))
            and target ~= nil
            and not target:HasTag('INLIMBO')
            and target:IsActionValid(official, rmb)
            and (official.validfn == nil or official.validfn(action))
    end

    return {
        definition = definition,
        official = official,
        remote = remote,
        prefab_id = opts.prefab_id,
        require_tag = opts.require_tag,
    }
end

function core.can_remote_tool(entry, weapon, doer, target, right)
    return core.is_equipped_by(weapon, doer, entry.prefab_id)
        and (entry.require_tag == nil or weapon:HasTag(entry.require_tag))
        and target ~= nil
        and not target:HasTag('INLIMBO')
        and target:IsActionValid(entry.official, right)
end

function core.make_state_handler(entry, client)
    local state = entry.definition.state
    local fast = entry.definition.fast
    return function(inst)
        if inst.sg:HasStateTag(state[1]) or client and inst:HasTag(state[1]) then
            return nil
        end
        if fast ~= nil then
            return fast.name
        end
        return inst.sg:HasStateTag(state[2]) and state[4] or state[3]
    end
end

function core.register_remote_tool(entry)
    local fast = entry.definition.fast
    if fast ~= nil then
        core.add_fast_action_states(fast)
    end
    core.add_handler('wilson', ActionHandler(entry.remote, core.make_state_handler(entry, false)))
    core.add_handler('wilson_client', ActionHandler(entry.remote, core.make_state_handler(entry, true)))
end

function core.register_queuer(entries, categories_fn, test_fn)
    core.add_queuer_postinit(function(self)
        if self.AddAction == nil then
            return
        end
        for _, entry in ipairs(entries) do
            for _, category in ipairs(categories_fn(entry)) do
                self.AddAction(category, entry.remote, test_fn(entry, category))
            end
        end
    end)

    for _, entry in ipairs(entries) do
        for _, category in ipairs(categories_fn(entry)) do
            core.add_queuer_action(category, entry.remote, test_fn(entry, category))
        end
    end
end

-- 本模块通过 modimport 在模组环境加载（需要 AddAction/AddStategraphState 等环境函数），
-- 用 TUNING 上的全局槽位把模块表带回给调用方。
TUNING.YMKIT_CORE = core

return core
