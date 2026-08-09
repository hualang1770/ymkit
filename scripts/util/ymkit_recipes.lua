-- 青年的工具 · 配方统一注册
-- 配方数据（材料/科技/图标）在 ymkit_item_stats.lua 里按工具维护，
-- 统一使用科学二本科技 + “青年的工具”制造栏。

local stats = require 'util/ymkit_item_stats'
local config = TUNING.YMKIT_CONFIG

local function add_recipe(tool)
    if TUNING.YMKIT_REG.recipes[tool.prefab_id] then
        return
    end

    local ingredients = {}
    for _, material in ipairs(tool.recipes) do
        table.insert(ingredients, Ingredient(material[1], material[2]))
    end

    AddRecipe2(tool.prefab_id, ingredients, tool.tech, {
        atlas = tool.recipe_atlas,
        image = tool.recipe_image,
        force_hint = true, -- 未解锁时也在制造栏可见（锁定态），靠近科技建筑造过后永久解锁
    }, {'YMKIT_TOOLS'})
    TUNING.YMKIT_REG.recipes[tool.prefab_id] = true

    -- 只保留在“青年的工具”栏，从其他栏移除（幂等，可重复调用）
    RemoveRecipeFromFilter(tool.prefab_id, 'MODS')
    RemoveRecipeFromFilter(tool.prefab_id, CRAFTING_FILTERS.CRAFTING_STATION.name)
end

for _, key in ipairs(stats.list) do
    local tool = stats[key]
    -- 有配置开关的工具：关闭时跳过配方注册
    if tool.config_key == nil or config[tool.config_key] ~= false then
        add_recipe(tool)
    end
end
