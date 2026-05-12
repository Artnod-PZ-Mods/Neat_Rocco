-- NR_Patch_Bake.lua
-- Monkey-patches ISOvenUITimedAction.perform to open NR_OvenPanel or NR_MicrowavePanel.

require "NeatRocco/NR_Bake/NR_OvenPanel"
require "NeatRocco/NR_Bake/NR_MicrowavePanel"

ISOvenUITimedAction._NR_old_perform = ISOvenUITimedAction._NR_old_perform or ISOvenUITimedAction.perform

local function NR_performBake(self)
    -- Must be called first, like vanilla (removes action from queue)
    ISBaseTimedAction.perform(self)

    local player = self.character:getPlayerNum()

    if self.mcwave then
        -- Microwave: use NR_MicrowavePanel
        if NR_MicrowavePanel.instance and NR_MicrowavePanel.instance[player + 1] then
            NR_MicrowavePanel.instance[player + 1]:close()
        end
        local _pad  = NR_Config.padding
        local _tex1 = getTexture("media/ui/Knobs/KnobBGMicrowaveTemp.png")
        local _tex2 = getTexture("media/ui/Knobs/KnobBGMicrowaveTimer.png")
        local _w    = _pad + _tex1:getWidthOrig() + _pad + _tex2:getWidthOrig() + _pad
        local ui = NR_MicrowavePanel:new(0, 0, _w, 300, self.mcwave, self.character)
        ui:initialise()
        ui:addToUIManager()
        if JoypadState.players[player + 1] then
            ui.prevFocus = JoypadState.players[player + 1].focus
            setJoypadFocus(player, ui)
        end
        return
    end

    -- Oven: use NR_OvenPanel
    if NR_OvenPanel.instance and NR_OvenPanel.instance[player + 1] then
        NR_OvenPanel.instance[player + 1]:close()
    end

    local _pad  = NR_Config.padding
    local _tex1 = getTexture("media/ui/Knobs/KnobBGFarhenOvenTemp.png")
    local _tex2 = getTexture("media/ui/Knobs/KnobBGOvenTimer.png")
    local _w    = _pad + _tex1:getWidthOrig() + _pad + _tex2:getWidthOrig() + _pad
    local ui = NR_OvenPanel:new(0, 0, _w, 400, self.stove, self.character)
    ui:initialise()
    ui:addToUIManager()
    if JoypadState.players[player + 1] then
        ui.prevFocus = JoypadState.players[player + 1].focus
        setJoypadFocus(player, ui)
    end
end

local function NR_applyBakeToggle(enabled)
    if enabled then
        ISOvenUITimedAction.perform = NR_performBake
    else
        ISOvenUITimedAction.perform = ISOvenUITimedAction._NR_old_perform
        for i = 1, 4 do
            local inst = NR_OvenPanel.instance[i]
            if inst then inst:close() end
            inst = NR_MicrowavePanel.instance[i]
            if inst then inst:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyBakeToggle)
