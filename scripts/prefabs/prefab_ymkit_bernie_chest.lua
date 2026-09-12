-- 小熊箱（ymkit_bernie_chest）
-- 可以像原版箱子一样储存物品的建筑，容器为 6x6 共 36 格（格子数在 util/ymkit_item_stats.lua 里调）。
-- 配方与放置方式和原版箱子一致（3 块木板 + 科学一本），制作后在“青年的工具”栏里放置。
-- 额外能力（数值都在 util/ymkit_item_stats.lua 的 bernie_chest 里调）：
--   无限堆叠  箱内物品不受堆叠上限限制，和“弹性空间制造器”升满后的效果一样
--   冰箱      挂 fridge 标签，箱内暖石和食物会降温，冰块这类物品不会融化
--   保鲜/返鲜 按模组配置在 50%（原版冰箱）/75%/100% 保鲜与返鲜之间切换
--   防火      不加 burnable，点火烧不着；锤 2 下砸掉，返还材料走配方（和原版箱子一样）
-- 目前动画只有 chest / hit 两个，暂不区分开合状态，后续再打磨。

local containers = require 'containers'
local data = require('util/ymkit_item_stats').bernie_chest

-- 容器面板：
--   槽位  ContainerWidget 默认就用 images/hud.xml 里的 inv_slot
--   底板  优先用模组自画的 6x6 面板贴图（bgatlas/bgimage，按 1:1 画，不放大）；
--         贴图还没做好时退回官方箱子底板 ui_chest_3x3，靠 bganim_visualfn 放大到罩住 6x6
-- 客户端创建副本容器时会按 prefab 名去 containers.params 里取容器设置，
-- 所以这里把设置登记到本物品名下，客户端和服务器用的是同一份数据。
local slotpos = {}
for row = 0, data.container_rows - 1 do
    for col = 0, data.container_cols - 1 do
        table.insert(slotpos, Vector3(
            (col - (data.container_cols - 1) * 0.5) * data.container_spacing,
            ((data.container_rows - 1) * 0.5 - row) * data.container_spacing,
            0))
    end
end

-- ContainerWidget 的 SetTexture 遇到不存在的贴图会直接报错，所以这里先确认文件在不在，
-- 贴图没做好时退回官方动画底板，容器依然能正常打开。
local use_custom_bg = data.container_bg_atlas ~= nil
    and data.container_bg_image ~= nil
    and softresolvefilepath(data.container_bg_atlas) ~= nil
    and softresolvefilepath('images/' .. data.container_bg_image) ~= nil

-- 面板显示位置：ContainerWidget 的根节点自带 0.6 缩放（见原版 widgets/containerwidget.lua），
-- 所以 700 高的底板在它自己的坐标系里只占 700 * 0.6 = 420 个单位。但它挂在原版
-- controls.containerroot 底下，那个节点是 SCALEMODE_PROPORTIONAL，会按分辨率等比放大
-- （缩放倍数 = min(屏宽/1280, 屏高/720)，且不超过 MAX_HUD_SCALE），还会按设置里的
-- “HUD 尺寸”再放大一点。于是同一个坐标在不同分辨率下离屏幕上沿的距离并不一样：
-- 1080p 会放大 1.25 倍，面板上沿就顶出屏幕了。这里先把屏幕半高换算到容器节点自己的
-- 坐标系，再决定面板能放多高：
--   屏幕够高   用理想位置（底板上沿停在中线上方，不挡箱子本体）
--   屏幕不够高 整体下移，保证上沿不顶出屏幕（margin 是屏幕上留的像素）
-- 拿不到屏幕尺寸时就用 widget.pos 那个固定位置。
local function container_widget_posfn()
    local y = data.container_widget_y
    if TheSim ~= nil and TheSim.GetScreenSize ~= nil then
        local screen_w, screen_h = TheSim:GetScreenSize()
        if screen_h ~= nil and screen_h > 0 then
            local base_w = RESOLUTION_X or 1280
            local base_h = RESOLUTION_Y or 720
            local prop = math.min(math.min((screen_w or base_w) / base_w, screen_h / base_h), MAX_HUD_SCALE or 1.25)
            local hud_size = 1
            if TheFrontEnd ~= nil and TheFrontEnd.GetProportionalHUDScale ~= nil then
                local scale = TheFrontEnd:GetProportionalHUDScale()   -- 设置里的 HUD 尺寸
                if scale ~= nil and scale > 0 then
                    hud_size = scale
                end
            end
            local scale = prop * hud_size
            local half = data.container_bg_pixels * data.container_widget_scale * 0.5
            local usable_half = screen_h * 0.5 / scale            -- 屏幕半高，换算到容器节点的坐标系
            local margin = data.container_widget_margin / scale   -- 留白按同样的比例换算
            y = math.min(y, usable_half - half - margin)
        end
    end
    return Vector3(0, y, 0)
end

containers.params[data.prefab_id] =
{
    widget =
    {
        slotpos = slotpos,
        animbank = data.container_bg_bank,
        animbuild = data.container_bg_build,
        bgatlas = use_custom_bg and data.container_bg_atlas or nil,
        bgimage = use_custom_bg and data.container_bg_image or nil,
        pos = Vector3(0, data.container_widget_y, 0),
        posfn = container_widget_posfn,
        side_align_tip = 160,
        bganim_visualfn = function(bganim)
            local scale = data.container_bg_scale
            bganim:SetScale(scale, scale, scale)
        end,
    },
    type = 'chest',
}

local assets = {
    Asset('ANIM', 'anim/' .. data.bank .. '.zip'),
    Asset('ANIM', 'anim/' .. data.container_bg_zip),
    Asset('ATLAS', data.recipe_atlas),
    Asset('IMAGE', 'images/inventoryimages/' .. data.recipe_image),
}
if use_custom_bg then
    table.insert(assets, Asset('ATLAS', data.container_bg_atlas))
    table.insert(assets, Asset('IMAGE', 'images/' .. data.container_bg_image))
end

local function onopen(inst)
    if not inst:HasTag('burnt') then
        inst.SoundEmitter:PlaySound('dontstarve/wilson/chest_open')
    end
end

local function onclose(inst)
    if not inst:HasTag('burnt') then
        inst.SoundEmitter:PlaySound('dontstarve/wilson/chest_close')
    end
end

local function onhammered(inst, worker)
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper:DropLoot()
    end
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
    local fx = SpawnPrefab('collapse_small')
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial('wood')
    inst:Remove()
end

local function onhit(inst, worker)
    if not inst:HasTag('burnt') then
        if inst.components.container ~= nil then
            inst.components.container:DropEverything()
            inst.components.container:Close()
        end
        inst.AnimState:PlayAnimation(data.anim_hit)
        inst.AnimState:PushAnimation(data.anim_idle, true)
    end
end

-- 返鲜：每 restore_period 秒给箱内每件还有新鲜度的物品补 restore_percent 的新鲜度。
-- 原版没有返鲜机制，所以用低频定时任务实现（一次只遍历 36 格），不做逐物品的持续循环。
local function restore_freshness(inst)
    local container = inst.components.container
    if container == nil then
        return
    end
    for _, item in pairs(container.slots) do
        local perishable = item ~= nil and item.components ~= nil and item.components.perishable or nil
        local percent = perishable ~= nil and perishable:GetPercent() or nil
        if percent ~= nil and percent > 0 and percent < 1 then
            perishable:SetPercent(percent + data.restore_percent)
        end
    end
end

-- 保鲜/返鲜：模式与数值见 util/ymkit_item_stats.lua 的 preserve_modes（配置项在 modinfo 里）
local function setup_preserve(inst)
    local config = TUNING.YMKIT_CONFIG
    local mode = config ~= nil and config.bernie_chest_preserve or nil
    local rate = mode ~= nil and data.preserve_modes[mode] or nil
    if rate == nil then
        return
    end

    if rate ~= TUNING.PERISH_FRIDGE_MULT then
        -- 挂了自己的 preserver 就轮不到原版按 fridge 标签取值，这里自己给出倍率；
        -- 冰块这类带 frozen 标签的物品在原版冰箱里不会融化，保留同样的处理。
        inst:AddComponent('preserver')
        inst.components.preserver:SetPerishRateMultiplier(function(owner, item)
            if item ~= nil and item:HasTag('frozen') then
                return TUNING.PERISH_COLD_FROZEN_MULT
            end
            return rate
        end)
        -- 降温仍交给 fridge 标签那一套，速率倍率保持默认（1）
        inst.components.preserver:SetTemperatureRateMultiplier(1)
    end

    if mode == 'restore' then
        inst:DoPeriodicTask(data.restore_period, restore_freshness)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon('treasurechest.png')

    inst:AddTag('structure')
    inst:AddTag('chest')
    -- 冰箱：箱内暖石/食物降温，食物按原版冰箱速度保鲜（见上面的 setup_preserve）
    inst:AddTag('fridge')

    inst.AnimState:SetBank(data.bank)
    inst.AnimState:SetBuild(data.bank)
    inst.AnimState:PlayAnimation(data.anim_idle, true)

    MakeSnowCoveredPristine(inst)

    -- 与配方里的 min_spacing 对应（原版箱子同样取 min_spacing 的一半），控制放置间距
    inst:SetDeploySmartRadius((data.min_spacing or 1) * 0.5)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('inspectable')

    inst:AddComponent('container')
    inst.components.container:WidgetSetup(data.prefab_id)
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose
    inst.components.container.skipopensnd = true
    inst.components.container.skipclosesnd = true
    -- 无限堆叠：和“弹性空间制造器”升满后的效果一样，之后放进去的物品由容器自己接管
    inst.components.container:EnableInfiniteStackSize(true)

    -- 锤子的掉落由 lootdropper 按配方自动返还（3 块木板 × HAMMER_LOOT_PERCENT），和原版箱子一样
    inst:AddComponent('lootdropper')

    setup_preserve(inst)

    inst:AddComponent('workable')
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(2)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:AddComponent('hauntable')
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    return inst
end

return Prefab(data.prefab_id, fn, assets),
    MakePlacer(data.placer_id, data.bank, data.bank, data.anim_idle)
