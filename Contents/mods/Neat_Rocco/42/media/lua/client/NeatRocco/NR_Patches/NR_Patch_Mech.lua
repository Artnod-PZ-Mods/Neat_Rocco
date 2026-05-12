-- NR_Patch_Mech.lua
-- Monkey-patches ISOpenMechanicsUIAction.perform and ISVehicleMechanics.OnMechanicActionDone.

require "NeatRocco/NR_Mech/NR_VehicleMechanicsPanel"

ISOpenMechanicsUIAction._NR_old_perform         = ISOpenMechanicsUIAction._NR_old_perform         or ISOpenMechanicsUIAction.perform
ISVehicleMechanics._NR_old_OnMechanicActionDone = ISVehicleMechanics._NR_old_OnMechanicActionDone or ISVehicleMechanics.OnMechanicActionDone

local function NR_performMechanicsUI(self)
    local playerNum = self.character:getPlayerNum()
    local ui = NR_VehicleMechanicsPanel.panels[playerNum]
    if not ui then
        ui = NR_VehicleMechanicsPanel:new(0, 0, self.character, nil)
        ui:initialise()
        ui:instantiate()  -- createChildren() is called here, which creates listbox/bodyworklist
        NR_VehicleMechanicsPanel.panels[playerNum] = ui
    end
    ui.vehicle  = self.vehicle
    ui.usedHood = self.usedHood
    ui:initParts()
    ui:setVisible(true, JoypadState.players[playerNum + 1])
    ui:addToUIManager()
    ui:calculateLayout(ui.width, ui.height)
    ISBaseTimedAction.perform(self)
end

local function NR_onMechanicActionDone(chr, success)
    local nrUI = NR_VehicleMechanicsPanel.panels[chr:getPlayerNum()]
    if nrUI and nrUI:isReallyVisible() then
        if success then nrUI:startFlashGreen() else nrUI:startFlashRed() end
    else
        ISVehicleMechanics._NR_old_OnMechanicActionDone(chr, success)
    end
end

local function NR_applyMechToggle(enabled)
    if enabled then
        ISOpenMechanicsUIAction.perform = NR_performMechanicsUI
        Events.OnMechanicActionDone.Remove(ISVehicleMechanics._NR_old_OnMechanicActionDone)
        Events.OnMechanicActionDone.Add(NR_onMechanicActionDone)
    else
        ISOpenMechanicsUIAction.perform = ISOpenMechanicsUIAction._NR_old_perform
        Events.OnMechanicActionDone.Remove(NR_onMechanicActionDone)
        Events.OnMechanicActionDone.Add(ISVehicleMechanics._NR_old_OnMechanicActionDone)
        for i = 0, 3 do
            local ui = NR_VehicleMechanicsPanel.panels[i]
            if ui then ui:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyMechToggle)
