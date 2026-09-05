
GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

PrefabFiles = {
    'prefab_ymkit_battleaxe',
    'prefab_ymkit_jiandao',
    'prefab_ymkit_powerstaff',
    'prefab_ymkit_rich_fertilizer',
    'prefab_ymkit_growth_fallacy',
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
    row = GetModConfigData('enable_row') ~= false,
}

for _, tool in ipairs(stats.battleaxe.tools) do
    config[tool.config] = GetModConfigData('enable_' .. tool.config) ~= false
end

config.jiandao = modconfig('enable_jiandao', true)
config.jiandao_remote = modconfig('enable_jiandao_remote', true)
config.jiandao_damage = modconfig('jiandao_damage', 100)
config.powerstaff = modconfig('enable_powerstaff', true)
config.wolfgang_muscle = modconfig('wolfgang_muscle', 'slow')
config.rich_fertilizer = modconfig('enable_rich_fertilizer', true)
config.rich_fertilizer_nutrients = modconfig('rich_fertilizer_nutrients', 25)
config.rich_fertilizer_uses = modconfig('rich_fertilizer_uses', 10)
config.rich_fertilizer_recipe_amount = modconfig('rich_fertilizer_recipe_amount', 3)
config.growth_fallacy = modconfig('enable_growth_fallacy', true)
for _, tool in ipairs(stats.jiandao.tools) do
    config[tool.config] = modconfig('enable_' .. tool.config, true)
end

TUNING.YMKIT_CONFIG = config

-- Insight 等模组通过该表读取肥料的三种营养数值。
local fertilizer_defs = require('prefabs/fertilizer_nutrient_defs').FERTILIZER_DEFS
fertilizer_defs.ymkit_rich_fertilizer = {
    nutrients = {
        config.rich_fertilizer_nutrients,
        config.rich_fertilizer_nutrients,
        config.rich_fertilizer_nutrients,
    },
}

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
AddRecipeFilter({
    name = 'YMKIT_TOOLS',
    atlas = 'images/inventoryimages/inventoryimages2.xml',
    image = 'healingstaff.tex',
})
STRINGS.UI.CRAFTING_FILTERS.YMKIT_TOOLS = '青年的工具'

-- 核心模块加载失败时保留完整堆栈并中止初始化，避免模组半注册后继续运行。
modimport('scripts/util/'..mod_name..'_strings.lua')
modimport('scripts/util/'..mod_name..'_recipes.lua')
modimport('scripts/util/'..mod_name..'_actions.lua')

