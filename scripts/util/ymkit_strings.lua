-- 青年的工具 · 本地化文本统一注册
-- 文本内容在 ymkit_item_stats.lua 里按工具维护，这里只负责遍历注册

local stats = require 'util/ymkit_item_stats'

for _, key in ipairs(stats.list) do
    local tool = stats[key]
    local upper = tool.prefab_id:upper()
    STRINGS.NAMES[upper] = tool.name
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[upper] = tool.describe
    STRINGS.RECIPE_DESC[upper] = tool.recipe_desc
end
