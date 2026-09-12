-- 青年的工具 · 本地化文本统一注册
-- 文本内容在 ymkit_item_stats.lua 里按物品维护，这里只负责遍历注册

local stats = require 'util/ymkit_item_stats'

for _, key in ipairs(stats.list) do
    local item = stats[key]
    local upper = item.prefab_id:upper()
    -- 原版已有名称的物品（keep_vanilla_name）只注册配方描述，避免覆盖其他语言的原版名称。
    if item.keep_vanilla_name ~= true then
        STRINGS.NAMES[upper] = item.name
        STRINGS.CHARACTERS.GENERIC.DESCRIBE[upper] = item.describe
    end
    STRINGS.RECIPE_DESC[upper] = item.recipe_desc
end
