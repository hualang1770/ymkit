-- 青年的工具 · 配方统一注册
-- 配方数据（材料/科技/图标）在 ymkit_item_stats.lua 里按物品维护，
-- 统一使用科学二本科技 + “青年的工具”制造栏。

local stats = require 'util/ymkit_item_stats'
local config = TUNING.YMKIT_CONFIG

local function add_recipe(item)
    local ingredients = {}
    local amount = item.recipe_amount_config ~= nil
        and config[item.recipe_amount_config]
        or nil
    for _, material in ipairs(item.recipes) do
        table.insert(ingredients, Ingredient(material[1], amount or material[2]))
    end

    AddRecipe2(item.prefab_id, ingredients, item.tech, {
        atlas = item.recipe_atlas,
        image = item.recipe_image,
        force_hint = true, -- 未解锁时也在制造栏可见（锁定态），靠近科技建筑造过后永久解锁
    }, {'YMKIT_TOOLS'})

    -- 只保留在“青年的工具”栏，从其他栏移除
    RemoveRecipeFromFilter(item.prefab_id, 'MODS')
    RemoveRecipeFromFilter(item.prefab_id, CRAFTING_FILTERS.CRAFTING_STATION.name)
end

for _, key in ipairs(stats.list) do
    local item = stats[key]
    -- 有配置开关的物品：关闭时跳过配方注册
    if item.config_key == nil or config[item.config_key] ~= false then
        add_recipe(item)
    end
end
