-- 青年的工具 · 本地化文本统一注册
-- 文本内容在 ymkit_item_stats.lua 里按物品维护，这里只负责遍历注册

local stats = require 'util/ymkit_item_stats'

for _, key in ipairs(stats.list) do
    local item = stats[key]
    local upper = item.prefab_id:upper()
    -- 原版已有名称的物品（keep_vanilla_name）只注册配方描述，避免覆盖其他语言的原版名称。
    if item.keep_vanilla_name ~= true then
        STRINGS.NAMES[upper] = item.name
        -- describe_upgraded 有的话按原版箱子的写法存成表（GENERIC + UPGRADED_STACKSIZE），
        -- 检查升级过的熊箱就会显示那一句；没有的物品还是原来的纯文本。
        if item.describe_upgraded ~= nil then
            STRINGS.CHARACTERS.GENERIC.DESCRIBE[upper] = {
                GENERIC = item.describe,
                UPGRADED_STACKSIZE = item.describe_upgraded,
            }
        else
            STRINGS.CHARACTERS.GENERIC.DESCRIBE[upper] = item.describe
        end
    end
    STRINGS.RECIPE_DESC[upper] = item.recipe_desc
end
