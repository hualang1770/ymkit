-- ============================================================================
--  青年的工具 · 物品属性总表
--  ---------------------------------------------------------------------------
--  三件装备（以及以后新增的工具）的数值全部集中在本文件调整。
--  修改保存后请完整退出并重启游戏；本模组不支持通过模组界面“应用”热重载。
--
--  常用字段含义：
--    damage        攻击力（普通攻击伤害）
--    range         攻击距离
--    walkspeedmult 手持时移动速度倍率（1 = 正常速度）
--    planardmg     位面伤害（无视普通护甲的部分）
--    effectiveness 工具效率（数值越大单次动作的作业量越高）
--    recharge_time 力量魔杖传送后的充能冷却秒数
--    recipes       制作配方（每项为 {材料ID, 数量}）
-- ============================================================================

local stats = {
    -- 物品登记顺序：字符串/配方注册按此遍历；新增物品时把键名加进来即可
    list = {'battleaxe', 'scissors', 'powerstaff', 'rich_fertilizer', 'growth_fallacy', 'horseshoe', 'lucky_horseshoe', 'unlucky_horseshoe', 'bernie_chest'},

    --------------------------------------------------------------------------
    -- 一、黑曜石战斧（ymkit_battleaxe）
    --------------------------------------------------------------------------
    battleaxe = {
        prefab_id = 'ymkit_battleaxe',      -- 内部 ID（一般不用改）
        name = '黑曜石战斧',                 -- 游戏内名称
        describe = '坚硬无比',               -- 检查时的描述
        recipe_desc = '强力的武器',          -- 配方描述
        bank = 'obsidian_battleaxe',        -- 动画/图标资源名（一般不用改）
        image = 'obsidian_battleaxe',
        dig_mode_tag = 'ymkit_dig_mode',    -- 挖掘形态标签（一般不用改）
        tech = TECH.SCIENCE_TWO,            -- 解锁科技（科学二本）
        recipe_atlas = 'images/inventoryimages/obsidian_battleaxe.xml',
        recipe_image = 'obsidian_battleaxe.tex',

        damage = 74,                        -- 攻击力
        range = 1.5,                          -- 攻击距离
        walkspeedmult = 1.25,               -- 手持移速倍率
        planardmg = 5,                      -- 位面伤害
        row_force = 1.0,                    -- 划船力度（邪天翁喙 0.8 的 125%）
        row_max_velocity = 6.25,            -- 划船最高速度（邪天翁喙 5 的 125%）

        -- 工具能力：effectiveness 为效率，数值越大单次作业量越高
        tools = {
            -- 范围收割（右键，收割面前一片可采集植物）
            { action = 'SCYTHE', config = 'harvest', mode = 'harvest', effectiveness = 1 },

            -- 铲掘（隔空可用）；fast 段为动画配置，一般不用改
            {
                action = 'DIG',
                config = 'dig',
                mode = 'dig',
                effectiveness = 10,
                remote = true,
                queue = {'rightclick', 'noworkdelay', 'tools', 'autocollect'},
                state = {'predig', 'digging', 'dig_start', 'dig'},
                fast = {
                    name = 'ymkit_fast_dig',
                    animation = 'shovel_loop',
                    post_animation = 'shovel_pst',
                    pretag = 'predig',
                    worktag = 'digging',
                    work_frame = 8,
                    end_frame = 16,
                    sound = 'dontstarve/wilson/dig',
                },
            },

            -- 采矿（隔空可用）：效率 3（普通鹤嘴锄的 3 倍）
            {
                action = 'MINE',
                config = 'mine',
                effectiveness = 3,
                remote = true,
                queue = {'allclick', 'noworkdelay', 'tools', 'autocollect'},
                state = {'premine', 'mining', 'mine_start', 'mine'},
                fast = {
                    name = 'ymkit_fast_mine',
                    animation = 'pickaxe_loop',
                    post_animation = 'pickaxe_pst',
                    pretag = 'premine',
                    worktag = 'mining',
                    work_frame = 5,
                    end_frame = 10,
                    mining_fx = true,
                    recoilstate = 'mine_recoil',
                },
            },

            -- 砍树（隔空可用）：效率 3（普通斧头的 3 倍）
            {
                action = 'CHOP',
                config = 'chop',
                effectiveness = 3,
                remote = true,
                queue = {'allclick', 'noworkdelay', 'tools', 'autocollect'},
                state = {'prechop', 'chopping', 'chop_start', 'chop'},
                fast = {
                    name = 'ymkit_fast_chop',
                    animation = 'chop_loop',
                    woodcutter_animation = 'woodie_chop_loop',
                    pretag = 'prechop',
                    worktag = 'chopping',
                    work_frame = 4,
                    end_frame = 8,
                },
            },

            -- 捕虫：效率 10
            { action = 'NET', config = 'net', effectiveness = 10 },
        },

        -- 制作配方：{材料ID, 数量}
        recipes = {
            {'goldnugget', 2},
            {'spear', 1},
            {'rope', 1},
        },
    },

    --------------------------------------------------------------------------
    -- 二、魔法剪刀（ymkit_scissors）
    --------------------------------------------------------------------------
    scissors = {
        prefab_id = 'ymkit_scissors',
        name = '魔法剪刀',
        describe = '蕴含真实伤害的魔法剪刀，可拆解物品、锤击建筑',
        recipe_desc = '剪刀剪开，材料返还~',
        hammer_mode_tag = 'ymkit_scissors_hammer_mode',
        tech = TECH.SCIENCE_TWO,            -- 解锁科技（科学二本）
        recipe_atlas = 'images/inventoryimages/ymkit_scissors.xml',
        recipe_image = 'ymkit_scissors.tex',

        -- 真实伤害参考值；实际生效数值由模组配置项 scissors_damage 控制
        -- （游戏内模组设置可选 54~9999；想改默认值请改 modinfo.lua 的 default）
        damage = 100,
        range = 1.5,                          -- 攻击距离
        walkspeedmult = 1,                  -- 手持移速倍率
        planardmg = 0,                      -- 位面伤害

        tools = {
            -- 锤子形态（右键切换，隔空可用）：效率 10（10 倍锤力）
            {
                action = 'HAMMER',
                config = 'hammer',
                effectiveness = 10,
                remote = true,
                rmb = true,
                queue = {'rightclick', 'noworkdelay', 'tools', 'autocollect'},
                state = {'prehammer', 'hammering', 'hammer_start', 'hammer'},
                fast = {
                    name = 'ymkit_scissors_fast_hammer',
                    animation = 'atk',
                    pretag = 'prehammer',
                    worktag = 'hammering',
                    work_frame = 2,
                    end_frame = 4,
                },
            },
        },

        -- 制作配方
        recipes = {
            {'nightmarefuel', 4},
            {'livinglog', 2},
            {'greengem', 2},
            {'opalpreciousgem', 1},
        },
    },

    --------------------------------------------------------------------------
    -- 三、力量魔杖（ymkit_powerstaff）
    --------------------------------------------------------------------------
    powerstaff = {
        prefab_id = 'ymkit_powerstaff',
        name = '力量魔杖',
        describe = '蕴含传送之力的魔杖，沃尔夫冈佩戴时肌肉不会因走动而流失',
        recipe_desc = '力量与传送并存',
        tech = TECH.SCIENCE_TWO,            -- 解锁科技（科学二本）
        recipe_atlas = 'images/inventoryimages/ymkit_powerstaff.xml',
        recipe_image = 'orangestaff.tex',
        config_key = 'powerstaff',          -- 对应 TUNING.YMKIT_CONFIG 的开关键（关闭则不注册配方）

        -- 默认跟随原版懒人法杖数值；想固定就直接填数字（当前攻击力约 17）
        damage = TUNING.CANE_DAMAGE,
        walkspeedmult = TUNING.CANE_SPEED_MULT, -- 默认 1.25
        shadowlevel = TUNING.STAFF_SHADOW_LEVEL, -- 暗影等级，默认 1
        recharge_time = 3,                  -- 传送后充能冷却（秒）

        -- 制作配方
        recipes = {
            {'orangestaff', 1},
            {'goldnugget', 10},
            {'greengem', 1},
        },
    },

    --------------------------------------------------------------------------
    -- 四、高效肥料（ymkit_rich_fertilizer）
    --------------------------------------------------------------------------
    rich_fertilizer = {
        prefab_id = 'ymkit_rich_fertilizer',
        config_key = 'rich_fertilizer',
        name = '高效肥料',
        describe = '闻起来像科学和肥料的混合物。',
        recipe_desc = '富含全部营养类型的高效肥料。',
        tech = TECH.SCIENCE_TWO,
        recipe_atlas = 'images/inventoryimages/ymkit_rich_fertilizer.xml',
        recipe_image = 'ymkit_rich_fertilizer.tex',
        recipe_amount_config = 'rich_fertilizer_recipe_amount',
        recipes = {
            {'fertilizer', 1},
            {'soil_amender', 1},
            {'compost', 1},
        },
    },

    --------------------------------------------------------------------------
    -- 五、万物生长（ymkit_growth_fallacy）
    --------------------------------------------------------------------------
    growth_fallacy = {
        prefab_id = 'ymkit_growth_fallacy',
        config_key = 'growth_fallacy',
        name = '万物生长',
        describe = '草木丛生',
        recipe_desc = '强而有力',
        bank = 'ymkit_growth_fallacy',
        image = 'ymkit_growth_fallacy',
        tech = TECH.NONE,
        recipe_atlas = 'images/inventoryimages/ymkit_growth_fallacy.xml',
        recipe_image = 'ymkit_growth_fallacy.tex',
        range = 30,
        uses = 5,
        recipes = {
            {'papyrus', 1},
            {'poop', 5},
            {'seeds', 1},
        },
    },

    --------------------------------------------------------------------------
    -- 六、原版幸运马蹄铁的额外合成途径（ymkit_horseshoe）
    --------------------------------------------------------------------------
    horseshoe = {
        prefab_id = 'horseshoe',
        keep_vanilla_name = true, -- 不覆盖原版名称/描述，只新增合成配方
        name = '幸运马蹄铁',
        describe = '据说能带来好运的马蹄铁。',
        recipe_desc = '幸运金块合成幸运马蹄铁，很合理吧',
        tech = TECH.NONE,
        recipe_atlas = 'images/inventoryimages2.xml',
        recipe_image = 'horseshoe.tex',
        recipes = {
            {'lucky_goldnugget', 4},
        },
    },

    --------------------------------------------------------------------------
    -- 七、超幸运马蹄铁（ymkit_lucky_horseshoe）
    --------------------------------------------------------------------------
    lucky_horseshoe = {
        prefab_id = 'ymkit_lucky_horseshoe',
        name = '超幸运马蹄铁',
        describe = '10倍的幸运',
        recipe_desc = '带上它，你会幸运的',
        bank = 'lucky_horseshoe',
        image = 'ymkit_lucky_horseshoe',
        tech = TECH.NONE,
        recipe_atlas = 'images/inventoryimages/ymkit_lucky_horseshoe.xml',
        recipe_image = 'ymkit_lucky_horseshoe.tex',
        recipes = {
            {'horseshoe', 10},
        },
    },

    --------------------------------------------------------------------------
    -- 八、不幸马蹄铁（ymkit_unlucky_horseshoe）
    --------------------------------------------------------------------------
    unlucky_horseshoe = {
        prefab_id = 'ymkit_unlucky_horseshoe',
        name = '不幸马蹄铁',
        describe = '4倍的黑鲶鱼',
        recipe_desc = '带上它，也许你会幸运的',
        bank = 'unlucky_horseshoe',
        image = 'ymkit_unlucky_horseshoe',
        tech = TECH.NONE,
        recipe_atlas = 'images/inventoryimages/ymkit_unlucky_horseshoe.xml',
        recipe_image = 'ymkit_unlucky_horseshoe.tex',
        recipes = {
            {'oceanfish_medium_4_inv', 4},
        },
    },

    --------------------------------------------------------------------------
    -- 九、小熊箱（ymkit_bernie_chest）
    --------------------------------------------------------------------------
    bernie_chest = {
        prefab_id = 'ymkit_bernie_chest',
        name = '小熊箱',
        describe = '小熊的肚子里能装下不少东西。',
        recipe_desc = '三块木板钉一只小熊',
        bank = 'bernie_chest',              -- 动画 bank 与 build 同名
        placer_id = 'ymkit_bernie_chest_placer',
        -- 容器：6x6 共 36 格。槽位和底板都用官方 UI 资源，底板取官方箱子 ui_chest_3x3 放大到能盖住 6x6。
        container_cols = 6,
        container_rows = 6,
        container_spacing = 80,             -- 与原版箱子一致的槽位间距
        -- 自画的 6x6 底板（700x700，源图 images/ymkit_bernie_chest_panel.png）。
        -- 走 ContainerWidget 的 bgatlas/bgimage 分支：按 1 像素 = 1 界面单位直接画贴图，不放大，最清晰。
        -- 贴图文件不存在时会自动退回下面那套官方动画底板。
        container_bg_atlas = 'images/ymkit_bernie_chest_panel.xml',
        container_bg_image = 'ymkit_bernie_chest_panel.tex',
        -- 备用底板：官方箱子 ui_chest_3x3 本身只有 3x3 大，靠放大 2 倍罩住 6x6 的格子
        container_bg_scale = 2,
        container_bg_zip = 'ui_chest_3x3.zip',
        container_bg_bank = 'ui_chest_3x3',
        container_bg_build = 'ui_chest_3x3',
        -- 面板位置：ContainerWidget 的根节点自带 0.6 缩放（见原版 widgets/containerwidget.lua），
        -- 所以 700 高的底板其实只占 700 * 0.6 = 420 个单位。下面给的是“理想位置”：
        -- 屏幕够高时底板上沿会停在中线上方，不挡箱子本体；屏幕不够高就自动往下让，
        -- 保证面板不顶出屏幕上沿（算法见 prefab 里的 container_widget_posfn）。
        -- 另外这块面板挂在原版 controls.containerroot 底下，那个节点会按分辨率等比放大
        -- （最多 MAX_HUD_SCALE = 1.25 倍），所以面板在屏幕上的实际大小和位置随分辨率变化，
        -- posfn 会把放大倍数算进去：1080p 放不下理想位置就自动下移，2K 及以上保持不动。
        container_widget_y = 290,           -- 面板中心的理想高度（原版箱子是 200）
        container_bg_pixels = 700,          -- 自画底板的边长（像素），用来换算面板实际占多高
        container_widget_scale = 0.6,       -- 原版 ContainerWidget 根节点的缩放，一般不用改
        container_widget_margin = 8,        -- 面板上沿与屏幕上沿至少留出的距离（屏幕像素）
        anim_idle = 'chest',                -- 待机动画（循环播放）
        anim_hit = 'hit',                   -- 被锤击时播放的动画
        -- 保鲜/返鲜：键名与 modinfo 的 bernie_chest_preserve 选项一一对应。
        -- 表里是“腐败速度倍率”，越小越不容易坏：0.5 = 原版冰箱（腐烂速度减半），0 = 完全不腐烂。
        -- 返鲜除了不腐烂，还会每 restore_period 秒给箱内物品补 restore_percent 的新鲜度。
        preserve_modes = {
            fridge50 = 0.5,                 -- 原版冰箱数值
            fridge75 = 0.25,
            fridge100 = 0,
            restore = 0,
        },
        restore_period = 30,                -- 返鲜间隔（秒）
        restore_percent = 0.05,             -- 每次恢复的新鲜度比例（5%）
        tech = TECH.SCIENCE_ONE,            -- 与原版箱子相同：科学一本
        recipe_atlas = 'images/inventoryimages/ymkit_bernie_chest.xml',
        recipe_image = 'ymkit_bernie_chest.tex',
        min_spacing = 1,                    -- 与原版箱子一致的放置间距
        recipes = {
            {'boards', 3},
        },
    },

    --------------------------------------------------------------------------
    -- 十、以后新增的工具
    -- 复制下面的模板，改 prefab_id 和数值即可。同时：
    --   1. 把键名加进上面的 list（字符串/配方会自动注册）
    --   2. 在 scripts/prefabs/ 新建对应 prefab 文件，并在 modmain.lua 的
    --      PrefabFiles 里注册
    --   3. 在 modinfo.lua 添加对应配置开关（可选）
    --------------------------------------------------------------------------
    future = {
        -- example = {
        --     prefab_id = 'ymkit_example',
        --     name = '示例工具',
        --     describe = '示例描述',
        --     recipe_desc = '示例配方描述',
        --     damage = 30,
        --     range = 1,
        --     walkspeedmult = 1,
        --     planardmg = 0,
        --     tech = TECH.SCIENCE_TWO,
        --     recipe_atlas = 'images/inventoryimages/ymkit_example.xml',
        --     recipe_image = 'ymkit_example.tex',
        --     recipes = { {'goldnugget', 1} },
        -- },
    },
}

return stats
