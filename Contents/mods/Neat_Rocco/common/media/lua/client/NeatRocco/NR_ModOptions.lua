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

-- Per-window callback registry. Patches receive the combined (global AND per-window) boolean.
NR_WINDOW_TOGGLE_CALLBACKS = NR_WINDOW_TOGGLE_CALLBACKS or {}

function NR_isWindowEnabled(windowId)
    if not NR_isEnabled() then return false end
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions(MOD_ID)
    local o = opts and opts:getOption("use" .. windowId)
    if not o then return true end
    return _NR_to_bool(o:getValue())
end

function NR_RegisterWindowToggleCallback(windowId, cb)
    if type(cb) ~= "function" then return end
    NR_WINDOW_TOGGLE_CALLBACKS[windowId] = NR_WINDOW_TOGGLE_CALLBACKS[windowId] or {}
    table.insert(NR_WINDOW_TOGGLE_CALLBACKS[windowId], cb)
    -- Initial fire with the current combined value
    pcall(function() cb(NR_isWindowEnabled(windowId)) end)
end

local function _NR_get_per_window_value(windowId)
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions(MOD_ID)
    local o = opts and opts:getOption("use" .. windowId)
    if not o then return true end
    return _NR_to_bool(o:getValue())
end

local function _NR_fire_window_callbacks(windowId, combinedEnabled)
    for _, cb in ipairs(NR_WINDOW_TOGGLE_CALLBACKS[windowId] or {}) do
        pcall(function() cb(combinedEnabled) end)
    end
end

local function _NR_fire_callbacks(enabled)
    for _, cb in ipairs(NR_UI_TOGGLE_CALLBACKS) do
        pcall(function() cb(enabled) end)
    end
    -- Window callbacks: combine NEW global with CURRENT per-window value
    for windowId, _ in pairs(NR_WINDOW_TOGGLE_CALLBACKS) do
        local perWin = _NR_get_per_window_value(windowId)
        _NR_fire_window_callbacks(windowId, enabled and perWin)
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

    local collapseThresholdOpt = options:addComboBox(
        "collapseThreshold",
        "IGUI_NR_ModOptions_CollapseThreshold",
        "IGUI_NR_ModOptions_CollapseThreshold_Tooltip"
    )
    collapseThresholdOpt:addItem("IGUI_NR_ModOptions_CollapseThreshold_10", false)
    collapseThresholdOpt:addItem("IGUI_NR_ModOptions_CollapseThreshold_20", true)  -- vanilla default
    collapseThresholdOpt:addItem("IGUI_NR_ModOptions_CollapseThreshold_60", false)
    collapseThresholdOpt:addItem("IGUI_NR_ModOptions_CollapseThreshold_90", false)

    -- Per-window toggles section
    options:addSeparator()
    table.insert(options.data, { type = "title", name = MOD_TITLE .. " - " .. getText("IGUI_NR_ModOptions_Section_Windows") })

    options:addTickBox(
        "useCharInfo",
        "IGUI_NR_ModOptions_Window_CharInfo",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useFitness",
        "IGUI_NR_ModOptions_Window_Fitness",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useGarment",
        "IGUI_NR_ModOptions_Window_Garment",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useLivestock",
        "IGUI_NR_ModOptions_Window_Livestock",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useHutch",
        "IGUI_NR_ModOptions_Window_Hutch",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useButcherHook",
        "IGUI_NR_ModOptions_Window_ButcherHook",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useAnimalUI",
        "IGUI_NR_ModOptions_Window_AnimalUI",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useFarming",
        "IGUI_NR_ModOptions_Window_Farming",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useBake",
        "IGUI_NR_ModOptions_Window_Bake",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useGenerator",
        "IGUI_NR_ModOptions_Window_Generator",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useSearch",
        "IGUI_NR_ModOptions_Window_Search",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useMech",
        "IGUI_NR_ModOptions_Window_Mech",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useFluid",
        "IGUI_NR_ModOptions_Window_Fluid",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    options:addTickBox(
        "useDialogs",
        "IGUI_NR_ModOptions_Window_Dialogs",
        true,
        "IGUI_NR_ModOptions_Window_Tooltip"
    )

    -- Generator section
    options:addSeparator()
    table.insert(options.data, { type = "title", name = MOD_TITLE .. " - " .. getText("IGUI_NR_ModOptions_Section_Generator") })

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
        opt.onChange = function(_, selected)
            _NR_fire_callbacks(_NR_to_bool(selected))
        end
        opt.onChangeApply = function(_, selected)
            _NR_fire_callbacks(_NR_to_bool(selected))
        end
    end

    -- Per-window toggles: fire only the matching window's callbacks on change
    -- Pass the new per-window value explicitly because MainOptions updates
    -- option.value AFTER calling onChange.
    local function _NR_wire_window_toggle(optionId, windowId)
        local windowOpt = options:getOption(optionId)
        if not windowOpt then return end
        local function fire(newValue)
            local combined = NR_isEnabled() and _NR_to_bool(newValue)
            _NR_fire_window_callbacks(windowId, combined)
        end
        windowOpt.onChange      = function(_, selected) fire(selected) end
        windowOpt.onChangeApply = function(_, selected) fire(selected) end
    end

    _NR_wire_window_toggle("useCharInfo", "CharInfo")
    _NR_wire_window_toggle("useLivestock", "Livestock")
    _NR_wire_window_toggle("useAnimalUI", "AnimalUI")
    _NR_wire_window_toggle("useDialogs", "Dialogs")
    _NR_wire_window_toggle("useFitness", "Fitness")
    _NR_wire_window_toggle("useHutch", "Hutch")
    _NR_wire_window_toggle("useButcherHook", "ButcherHook")
    _NR_wire_window_toggle("useGenerator", "Generator")
    _NR_wire_window_toggle("useBake", "Bake")
    _NR_wire_window_toggle("useFarming", "Farming")
    _NR_wire_window_toggle("useGarment", "Garment")
    _NR_wire_window_toggle("useSearch", "Search")
    _NR_wire_window_toggle("useMech", "Mech")
    _NR_wire_window_toggle("useFluid", "Fluid")

    local sliderOpt = options:getOption("bgAlpha")
    if sliderOpt then
        local function applyAlpha(value)
            NR_Config.bgAlpha = tonumber(value) or 1.0
        end
        sliderOpt.onChange      = function(_, value) applyAlpha(value) end
        sliderOpt.onChangeApply = function(_, value) applyAlpha(value) end
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

    if collapseThresholdOpt then
        local THRESHOLD_VALUES = { 10, 20, 60, 90 }
        local function applyThreshold(idx)
            NR_Config.collapseThreshold = THRESHOLD_VALUES[tonumber(idx) or 2] or 20
        end
        collapseThresholdOpt.onChange      = function(_, v) applyThreshold(v) end
        collapseThresholdOpt.onChangeApply = function(_, v) applyThreshold(v) end
        applyThreshold(collapseThresholdOpt:getValue())
    end

    _NR_fire_callbacks(NR_isEnabled())
end

Events.OnGameBoot.Add(NR_ModOptions)
