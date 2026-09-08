-- 魔法剪刀真实伤害机制（参考棱镜模组带刺蔷薇）
-- 真实伤害无视：护甲、普攻减伤、位面减伤、生命损耗减免、无敌状态（玩家除外）
-- 真实伤害仍受：攻击者自身普攻加成/武器加成、被攻击对象的普攻增伤影响

local function is_true_damage_target(inst)
    return inst ~= nil and inst.ymkit_true_damage == 1
end

local function health_DoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    if amount < 0 and is_true_damage_target(self.inst) then
        if not self.inst:HasTag('player') then
            ignore_invincible = true
        end
        ignore_absorb = true
    end
    if self.ymkit_orig_DoDelta ~= nil then
        return self.ymkit_orig_DoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end
    return amount
end

local function health_IsInvincible(self, ...)
    if is_true_damage_target(self.inst) then
        return self.inst.sg ~= nil and self.inst.sg:HasStateTag('temp_invincible') or false
    end
    if self.ymkit_orig_IsInvincible ~= nil then
        return self.ymkit_orig_IsInvincible(self, ...)
    end
end

local function planarentity_AbsorbDamage(self, damage, attacker, weapon, spdmg, ...)
    if self.ymkit_orig_AbsorbDamage == nil then
        return damage, spdmg
    end
    if is_true_damage_target(self.inst) then
        local damage2, spdamage2 = self.ymkit_orig_AbsorbDamage(self, damage, attacker, weapon, spdmg, ...)
        if damage2 < damage then
            return damage, spdamage2
        end
        return damage2, spdamage2
    end
    return self.ymkit_orig_AbsorbDamage(self, damage, attacker, weapon, spdmg, ...)
end

local function damagetyperesist_GetResist(self, attacker, weapon, ...)
    local mult = 1
    if self.ymkit_orig_GetResist ~= nil then
        local orig = self.ymkit_orig_GetResist(self, attacker, weapon, ...)
        if is_true_damage_target(self.inst) and orig < 1 then
            orig = 1
        end
        mult = orig
    end
    return mult
end

local function inventory_ApplyDamage(self, damage, attacker, weapon, spdamage, ...)
    if is_true_damage_target(self.inst) then
        return damage, spdamage
    end
    if self.ymkit_orig_ApplyDamage ~= nil then
        return self.ymkit_orig_ApplyDamage(self, damage, attacker, weapon, spdamage, ...)
    end
    return damage, spdamage
end

local function mult_Get(self, ...)
    if is_true_damage_target(self.inst) then
        local mult = self._base or 1
        if self._modifiers ~= nil then
            for _, src_params in pairs(self._modifiers) do
                for _, v in pairs(src_params.modifiers) do
                    if v > 1 and self._fn ~= nil then
                        mult = self._fn(mult, v)
                    end
                end
            end
        end
        return mult
    end
    if self.ymkit_orig_Get ~= nil then
        return self.ymkit_orig_Get(self, ...)
    end
    return 1
end

local function combat_GetAttacked(self, ...)
    local result
    if self.ymkit_orig_GetAttacked ~= nil then
        result = self.ymkit_orig_GetAttacked(self, ...)
    end
    if self.inst.ymkit_true_damage == 1 then
        self.inst.ymkit_true_damage = 0
    end
    return result
end

local function patch_target(target)
    -- 护甲吸收：真实伤害直接穿透
    local cpt = target.components.inventory
    if cpt ~= nil and cpt.ymkit_orig_ApplyDamage == nil then
        cpt.ymkit_orig_ApplyDamage = cpt.ApplyDamage
        cpt.ApplyDamage = inventory_ApplyDamage
    end

    -- 战斗减伤倍率：只保留增伤部分
    cpt = target.components.combat
    if cpt ~= nil then
        local mult = cpt.externaldamagetakenmultipliers
        if mult ~= nil then
            if mult.ymkit_orig_Get == nil then
                mult.ymkit_orig_Get = mult.Get
                mult.Get = mult_Get
            end
        end
        if cpt.ymkit_orig_GetAttacked == nil then
            cpt.ymkit_orig_GetAttacked = cpt.GetAttacked
            cpt.GetAttacked = combat_GetAttacked
        end
    end

    -- 生命：无视减伤与无敌（玩家除外）
    cpt = target.components.health
    if cpt ~= nil then
        if cpt.ymkit_orig_DoDelta == nil then
            cpt.ymkit_orig_DoDelta = cpt.DoDelta
            cpt.DoDelta = health_DoDelta
        end
        if cpt.ymkit_orig_IsInvincible == nil and not target:HasTag('player') then
            cpt.ymkit_orig_IsInvincible = cpt.IsInvincible
            cpt.IsInvincible = health_IsInvincible
        end
    end

    -- 位面实体减伤
    cpt = target.components.planarentity
    if cpt ~= nil and cpt.ymkit_orig_AbsorbDamage == nil then
        cpt.ymkit_orig_AbsorbDamage = cpt.AbsorbDamage
        cpt.AbsorbDamage = planarentity_AbsorbDamage
    end

    -- 伤害类型抗性（生命损耗减免）
    cpt = target.components.damagetyperesist
    if cpt ~= nil and cpt.ymkit_orig_GetResist == nil then
        cpt.ymkit_orig_GetResist = cpt.GetResist
        cpt.GetResist = damagetyperesist_GetResist
    end
end

local function on_attack_other(attacker, data)
    local target = data ~= nil and data.target or nil
    if target == nil or not target:IsValid() or target.ymkit_ban_true_damage then
        return
    end
    if target.ymkit_true_damage == nil then
        patch_target(target)
    end
    target.ymkit_true_damage = 1

    -- 兜底：若本次攻击未走 GetAttacked，延时清除标记，避免影响后续普通攻击
    if target.ymkit_clear_task ~= nil then
        target.ymkit_clear_task:Cancel()
    end
    target.ymkit_clear_task = target:DoTaskInTime(0.5, function()
        if target.ymkit_true_damage == 1 then
            target.ymkit_true_damage = 0
        end
        target.ymkit_clear_task = nil
    end)
end

local TrueDamage = {}

function TrueDamage.Enable(owner)
    if owner ~= nil then
        owner:RemoveEventCallback('onattackother', on_attack_other)
        owner:ListenForEvent('onattackother', on_attack_other)
    end
end

function TrueDamage.Disable(owner)
    if owner ~= nil then
        owner:RemoveEventCallback('onattackother', on_attack_other)
    end
end

return TrueDamage
