
name = '青年的工具'
version = '2.4.29'

description = version .. '\n青年制作的合集工具：黑曜石战斧（范围收割/隔空工具）、魔法剪刀（真实伤害/拆解/锤子形态）、力量魔杖（传送/沃尔夫冈肌肉保留）、高效肥料与万物生长，持续扩展中'

author = '青年'

icon_atlas = 'modicon.xml'
icon = 'modicon.tex'

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = true

local toggle_options = {
    {description = '开启', data = true},
    {description = '关闭', data = false},
}

local function toggle(name, label, hover)
    return {
        name = name,
        label = label,
        hover = hover,
        options = toggle_options,
        default = true,
    }
end

local function section(name, label)
    return {
        name = name,
        label = label,
        hover = '',
        options = {
            {description = '', data = 0},
        },
        default = 0,
    }
end

configuration_options = {
    section('ymkit_section_battleaxe', '战斧功能'),
    toggle('enable_remote', '隔空操作', '统一控制铲掘、采矿和砍树是否可以隔空执行'),
    toggle('enable_harvest', '范围收割', '开启暗影收割者的右键范围收割形态'),
    toggle('enable_dig', '铲掘', '开启铲子对应的铲除能力'),
    toggle('enable_mine', '采矿', '开启采矿能力，效率为普通鹤嘴锄的3倍'),
    toggle('enable_chop', '砍树', '开启砍树能力，效率为普通斧头的3倍'),
    toggle('enable_net', '捕虫', '开启官方捕虫网动作'),
    toggle('enable_row', '划船', '开启黑曜石战斧的划船功能，划船效率为100%'),
    section('ymkit_section_jiandao', '剪刀功能'),
    toggle('enable_jiandao', '剪刀拆解', '开启第二把工具魔法剪刀的拆解返还材料功能'),
    toggle('enable_jiandao_remote', '剪刀隔空操作', '开启拆解与锤子的隔空执行，无需走近目标'),
    toggle('enable_hammer', '锤子功能', '开启10倍锤力的锤子功能'),
    {
        name = 'jiandao_damage',
        label = '魔法剪刀真实伤害',
        hover = '每次攻击造成的真实伤害数值（无视护甲/减伤/无敌，玩家除外）',
        options = {
            {description = '54', data = 54},
            {description = '60', data = 60},
            {description = '70', data = 70},
            {description = '80', data = 80},
            {description = '100', data = 100},
            {description = '120', data = 120},
            {description = '150', data = 150},
            {description = '200', data = 200},
            {description = '300', data = 300},
            {description = '500', data = 500},
            {description = '1000', data = 1000},
            {description = '9999', data = 9999},
        },
        default = 100,
    },
    section('ymkit_section_powerstaff', '力量魔杖'),
    toggle('enable_powerstaff', '力量魔杖', '开启第三把工具力量魔杖（传送魔杖，沃尔夫冈佩戴时走动不流失肌肉）'),
    {
        name = 'wolfgang_muscle',
        label = '沃尔夫冈肌肉值下降',
        hover = '手持力量魔杖时沃尔夫冈肌肉值的下降方式',
        options = {
            {description = '和原版一样（缓慢减少）', data = 'slow'},
            {description = '完全停止肌肉值下降', data = 'stop'},
        },
        default = 'slow',
    },
    section('ymkit_section_rich_fertilizer', '高效肥料'),
    toggle('enable_rich_fertilizer', '高效肥料', '开启高效肥料的制作配方'),
    {
        name = 'rich_fertilizer_nutrients',
        label = '每种营养含量',
        hover = '每次施肥为耕地补充的每种营养数值',
        options = {
            {description = '25', data = 25},
            {description = '50', data = 50},
            {description = '75', data = 75},
            {description = '100', data = 100},
        },
        default = 25,
    },
    {
        name = 'rich_fertilizer_uses',
        label = '使用次数',
        hover = '每份高效肥料可使用的次数；无限时不会消耗',
        options = {
            {description = '10次', data = 10},
            {description = '20次', data = 20},
            {description = '50次', data = 50},
            {description = '100次', data = 100},
            {description = '无限', data = false},
        },
        default = 10,
    },
    {
        name = 'rich_fertilizer_recipe_amount',
        label = '每种配方材料数量',
        hover = '制作高效肥料时每种基础肥料所需的数量',
        options = {
            {description = '1', data = 1},
            {description = '2', data = 2},
            {description = '3', data = 3},
            {description = '4', data = 4},
            {description = '5', data = 5},
        },
        default = 3,
    },
    section('ymkit_section_growth_fallacy', '万物生长'),
    toggle('enable_growth_fallacy', '万物生长', '开启万物生长的制作配方；已有物品不受此开关影响'),
}

