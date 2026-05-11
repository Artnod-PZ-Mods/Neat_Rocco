-- NR_ModOptions.lua
-- Registers a toggle option in Options > Mods > "Neat Rocco"

local MOD_ID    = "Neat_Rocco"
local MOD_TITLE = "Neat Rocco's UI"

NR_MODOPTIONS_LOADED = NR_MODOPTIONS_LOADED or false

local function _NR_to_bool(v)
    return v == true or v == 1 or v == "1" or v == "true"
end

function NR_isEnabled()
    if not NR_MODOPTIONS_LOADED and PZAPI and PZAPI.ModOptions and type(PZAPI.ModOptions.load) == "function" then
        pcall(function() PZAPI.ModOptions:load() end)
        NR_MODOPTIONS_LOADED = true
    end
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions(MOD_ID)
    local o = opts and opts:getOption("useNeatRoccoUI")
    if not o then return true end
    return _NR_to_bool(o:getValue())
end

-- Callback registry (applied immediately on register + on live toggle)
NR_UI_TOGGLE_CALLBACKS = NR_UI_TOGGLE_CALLBACKS or {}

function NR_RegisterToggleCallback(cb)
    if type(cb) ~= "function" then return end
    table.insert(NR_UI_TOGGLE_CALLBACKS, cb)
    pcall(function() cb(NR_isEnabled()) end)
end

local function _NR_fire_callbacks(enabled)
    for _, cb in ipairs(NR_UI_TOGGLE_CALLBACKS) do
        pcall(function() cb(enabled) end)
    end
end

local function NR_ModOptions()
    if not (PZAPI and PZAPI.ModOptions) then return end

    local options = PZAPI.ModOptions:create(MOD_ID, MOD_TITLE)
    local _good = getCore():getGoodHighlitedColor()

    options:addTickBox(
        "useNeatRoccoUI",
        "IGUI_NR_ModOptions_UseNeatRoccoUI",
        true,
        "IGUI_NR_ModOptions_UseNeatRoccoUI_Tooltip"
    )

    options:addSlider(
        "bgAlpha",
        "IGUI_NR_ModOptions_BgAlpha",
        0.1, 1.0, 0.05, 1.0,
        "IGUI_NR_ModOptions_BgAlpha_Tooltip"
    )

    options:addTickBox(
        "convertToRT",
        "IGUI_NR_ModOptions_ConvertToRT",
        false,
        "IGUI_NR_ModOptions_ConvertToRT_Tooltip"
    )

    options:addTickBox(
        "showPerGenOverlay",
        "IGUI_NR_ModOptions_ShowPerGenOverlay",
        true,
        "IGUI_NR_ModOptions_ShowPerGenOverlay_Tooltip"
    )

    options:addTickBox(
        "showUnionOverlay",
        "IGUI_NR_ModOptions_ShowUnionOverlay",
        false,
        "IGUI_NR_ModOptions_ShowUnionOverlay_Tooltip"
    )

    options:addColorPicker(
        "perGenColor",
        "IGUI_NR_ModOptions_PerGenColor",
        _good:getR(), _good:getG(), _good:getB(), 0.08,
        "IGUI_NR_ModOptions_PerGenColor_Tooltip"
    )

    options:addColorPicker(
        "unionColor",
        "IGUI_NR_ModOptions_UnionColor",
        0.69, 0.878, 0.902, 0.28,
        "IGUI_NR_ModOptions_UnionColor_Tooltip"
    )

    if type(PZAPI.ModOptions.load) == "function" then
        pcall(function() PZAPI.ModOptions:load() end)
        NR_MODOPTIONS_LOADED = true
    end

    local opt = options:getOption("useNeatRoccoUI")
    if opt then
        opt.onChange = function(self, selected)
            _NR_fire_callbacks(_NR_to_bool(selected))
        end
        opt.onChangeApply = function(self, selected)
            _NR_fire_callbacks(_NR_to_bool(selected))
        end
    end

    local sliderOpt = options:getOption("bgAlpha")
    if sliderOpt then
        local function applyAlpha(value)
            NR_Config.bgAlpha = tonumber(value) or 1.0
        end
        sliderOpt.onChange      = function(self, value) applyAlpha(value) end
        sliderOpt.onChangeApply = function(self, value) applyAlpha(value) end
        applyAlpha(sliderOpt:getValue())
    end

    local rtOpt = options:getOption("convertToRT")
    if rtOpt then
        local function applyRT(value)
            NR_Config.convertToRT = _NR_to_bool(value)
        end
        rtOpt.onChange      = function(_, value) applyRT(value) end
        rtOpt.onChangeApply = function(_, value) applyRT(value) end
        applyRT(rtOpt:getValue())
    end

    local perGenOpt = options:getOption("showPerGenOverlay")
    if perGenOpt then
        local function apply(v) NR_Config.showPerGenOverlay = _NR_to_bool(v) end
        perGenOpt.onChange      = function(_, v) apply(v) end
        perGenOpt.onChangeApply = function(_, v) apply(v) end
        apply(perGenOpt:getValue())
    end

    local unionOpt = options:getOption("showUnionOverlay")
    if unionOpt then
        local function apply(v) NR_Config.showUnionOverlay = _NR_to_bool(v) end
        unionOpt.onChange      = function(_, v) apply(v) end
        unionOpt.onChangeApply = function(_, v) apply(v) end
        apply(unionOpt:getValue())
    end

    local function applyColor(key, value)
        if type(value) == "table" then
            NR_Config[key] = { r = value.r or value[1], g = value.g or value[2], b = value.b or value[3], a = value.a or value[4] }
        end
    end

    local perGenColorOpt = options:getOption("perGenColor")
    if perGenColorOpt then
        local function apply(v) applyColor("perGenColor", v) end
        perGenColorOpt.onChange      = function(_, v) apply(v) end
        perGenColorOpt.onChangeApply = function(_, v) apply(v) end
        apply(perGenColorOpt:getValue())
    end

    local unionColorOpt = options:getOption("unionColor")
    if unionColorOpt then
        local function apply(v) applyColor("unionColor", v) end
        unionColorOpt.onChange      = function(_, v) apply(v) end
        unionColorOpt.onChangeApply = function(_, v) apply(v) end
        apply(unionColorOpt:getValue())
    end

    _NR_fire_callbacks(NR_isEnabled())
end

Events.OnGameBoot.Add(NR_ModOptions)
