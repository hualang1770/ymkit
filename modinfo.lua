
name = '青年的工具'
version = '2.4.26'

description = version .. '\n青年制作的合集工具：黑曜石战斧（范围收割/隔空工具）、魔法剪刀（真实伤害/拆解/锤子形态）与力量魔杖（传送/沃尔夫冈肌肉保留），持续扩展中'

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
}

