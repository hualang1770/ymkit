
GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

-- 热重载幂等保护：模组配置"应用"会重新执行 modmain，
-- DST 的动作/组件钩子注册表不会重置，重复注册会导致编码错位、动作失效。
TUNING.YMKIT_REG = TUNING.YMKIT_REG or {}
TUNING.YMKIT_REG.actions = TUNING.YMKIT_REG.actions or {}
TUNING.YMKIT_REG.components = TUNING.YMKIT_REG.components or {}
TUNING.YMKIT_REG.component_fns = TUNING.YMKIT_REG.component_fns or {}
TUNING.YMKIT_REG.recipes = TUNING.YMKIT_REG.recipes or {}
TUNING.YMKIT_REG.states = TUNING.YMKIT_REG.states or {}
TUNING.YMKIT_REG.handlers = TUNING.YMKIT_REG.handlers or {}
TUNING.YMKIT_REG.postinits = TUNING.YMKIT_REG.postinits or {}

local _AddAction = AddAction
local _AddComponentAction = AddComponentAction

env.AddAction = function(id, str, fn)
    local existing = ACTIONS[id]
    if existing ~= nil and TUNING.YMKIT_REG.actions[id] then
        -- “应用”配置时沿用已分配的动作编码，但刷新实现与显示文本。
        existing.str = str
        existing.fn = fn
        STRINGS.ACTIONS[id] = str
        return existing
    end
    local action = _AddAction(id, str, fn)
    TUNING.YMKIT_REG.actions[id] = true
    return action
end

env.AddComponentAction = function(actiontype, component, fn)
    local key = actiontype .. '/' .. component
    TUNING.YMKIT_REG.component_fns[key] = fn
    if TUNING.YMKIT_REG.components[key] then
        return
    end
    _AddComponentAction(actiontype, component, function(...)
        local current = TUNING.YMKIT_REG.component_fns[key]
        if current ~= nil then
            return current(...)
        end
    end)
    TUNING.YMKIT_REG.components[key] = true
end

PrefabFiles = {
    'prefab_ymkit_battleaxe',
    'prefab_ymkit_jiandao',
    'prefab_ymkit_powerstaff',
}

local mod_name = 'ymkit'
local stats = require 'util/ymkit_item_stats'

local function modconfig(name, default)
    local value = GetModConfigData(name)
    if value == nil then
        return default
    end
    return value
end

local config = {
    remote = GetModConfigData('enable_remote') ~= false,
}

for _, tool in ipairs(stats.battleaxe.tools) do
    config[tool.config] = GetModConfigData('enable_' .. tool.config) ~= false
end

config.jiandao = modconfig('enable_jiandao', true)
config.jiandao_remote = modconfig('enable_jiandao_remote', true)
config.jiandao_damage = modconfig('jiandao_damage', 100)
config.powerstaff = modconfig('enable_powerstaff', true)
config.wolfgang_muscle = modconfig('wolfgang_muscle', 'slow')
for _, tool in ipairs(stats.jiandao.tools) do
    config[tool.config] = modconfig('enable_' .. tool.config, true)
end

TUNING.YMKIT_CONFIG = config

-- 力量魔杖使用懒人魔杖(orangestaff)的动画，注册同一组皮肤：
-- 让制作栏皮肤选择器、装扮工具(reskin_tool)都能对力量魔杖使用懒人魔杖皮肤。
if PREFAB_SKINS ~= nil and PREFAB_SKINS.orangestaff ~= nil and PREFAB_SKINS.ymkit_powerstaff == nil then
    PREFAB_SKINS.ymkit_powerstaff = PREFAB_SKINS.orangestaff
    PREFAB_SKINS_IDS.ymkit_powerstaff = {}
    for k, v in ipairs(PREFAB_SKINS.ymkit_powerstaff) do
        PREFAB_SKINS_IDS.ymkit_powerstaff[v] = k
    end
end

-- 统一制造栏“青年的工具”：三把工具与以后的新工具都放这里，
-- 图标取自模组自带图集（更多物品 250801 版 inventoryimages2）中的 healingstaff.tex。
Assets = {
    Asset('ATLAS', 'images/inventoryimages/inventoryimages2.xml'),
    Asset('IMAGE', 'images/inventoryimages/inventoryimages2.tex'),
}
if not TUNING.YMKIT_REG.filter_tools then
    AddRecipeFilter({
        name = 'YMKIT_TOOLS',
        atlas = 'images/inventoryimages/inventoryimages2.xml',
        image = 'healingstaff.tex',
    })
    STRINGS.UI.CRAFTING_FILTERS.YMKIT_TOOLS = '青年的工具'
    TUNING.YMKIT_REG.filter_tools = true
end

-- 核心模块加载失败时保留完整堆栈并中止初始化，避免模组半注册后继续运行。
modimport('scripts/util/'..mod_name..'_strings.lua')
modimport('scripts/util/'..mod_name..'_recipes.lua')
modimport('scripts/util/'..mod_name..'_actions.lua')

