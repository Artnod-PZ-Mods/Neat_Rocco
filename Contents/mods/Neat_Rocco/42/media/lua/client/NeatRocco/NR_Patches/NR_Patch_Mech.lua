-- NR_Patch_Mech.lua
-- Monkey-patches ISOpenMechanicsUIAction.perform, ISVehicleMechanics.OnMechanicActionDone,
-- ISVehicleMenu.onMechanic (toggle via VehicleMechanics key / context menu)
-- and Vehicles.Use.EngineDoor (toggle via Interact key on the hood area).

require "NeatRocco/NR_Mech/NR_VehicleMechanicsPanel"

ISOpenMechanicsUIAction._NR_old_perform         = ISOpenMechanicsUIAction._NR_old_perform         or ISOpenMechanicsUIAction.perform
ISVehicleMechanics._NR_old_OnMechanicActionDone = ISVehicleMechanics._NR_old_OnMechanicActionDone or ISVehicleMechanics.OnMechanicActionDone
ISVehicleMenu._NR_old_onMechanic                = ISVehicleMenu._NR_old_onMechanic                or ISVehicleMenu.onMechanic
-- Vehicles.Use.EngineDoor is patched lazily — Vehicles table is loaded after this file

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

local function NR_onMechanic(playerObj, vehicle)
    local nrUI = NR_VehicleMechanicsPanel.panels[playerObj:getPlayerNum()]
    if nrUI and nrUI:isReallyVisible() then
        nrUI:close()
        return
    end
    ISVehicleMenu._NR_old_onMechanic(playerObj, vehicle)
end

local function NR_useEngineDoor(vehicle, part, character)
    local nrUI = NR_VehicleMechanicsPanel.panels[character:getPlayerNum()]

    if not part:getInventoryItem() then
        if nrUI and nrUI:isReallyVisible() then
            nrUI:close()
        else
            ISTimedActionQueue.add(ISOpenMechanicsUIAction:new(character, vehicle, nil))
        end
    elseif part:getDoor():isOpen() then
        local closed = false
        if nrUI and nrUI:isReallyVisible() then
            if nrUI.usedHood == part then closed = true end
            nrUI:close()
        end
        if not closed then
            ISTimedActionQueue.add(ISOpenMechanicsUIAction:new(character, vehicle, part))
        end
    else
        if part:getDoor():isLocked() and VehicleUtils.RequiredKeyNotFound(part, character) then
            ISTimedActionQueue.add(ISUnlockVehicleDoor:new(character, part))
        end
        ISTimedActionQueue.add(ISOpenVehicleDoor:new(character, vehicle, part))
        ISTimedActionQueue.add(ISOpenMechanicsUIAction:new(character, vehicle, part))
    end
end

local function NR_applyEngineDoorPatch(enabled)
    if not (Vehicles and Vehicles.Use) then return end
    Vehicles.Use._NR_old_EngineDoor = Vehicles.Use._NR_old_EngineDoor or Vehicles.Use.EngineDoor
    Vehicles.Use.EngineDoor = enabled and NR_useEngineDoor or Vehicles.Use._NR_old_EngineDoor
end

local function NR_applyMechToggle(enabled)
    if enabled then
        ISOpenMechanicsUIAction.perform = NR_performMechanicsUI
        ISVehicleMenu.onMechanic        = NR_onMechanic
        Events.OnMechanicActionDone.Remove(ISVehicleMechanics._NR_old_OnMechanicActionDone)
        Events.OnMechanicActionDone.Add(NR_onMechanicActionDone)
    else
        ISOpenMechanicsUIAction.perform = ISOpenMechanicsUIAction._NR_old_perform
        ISVehicleMenu.onMechanic        = ISVehicleMenu._NR_old_onMechanic
        Events.OnMechanicActionDone.Remove(NR_onMechanicActionDone)
        Events.OnMechanicActionDone.Add(ISVehicleMechanics._NR_old_OnMechanicActionDone)
        for i = 0, 3 do
            local ui = NR_VehicleMechanicsPanel.panels[i]
            if ui then ui:close() end
        end
    end
    NR_applyEngineDoorPatch(enabled)
end

NR_RegisterToggleCallback(NR_applyMechToggle)

-- Re-apply once Vehicles table is loaded (server/Vehicles/Vehicles.lua loads after us)
Events.OnGameStart.Add(function() NR_applyEngineDoorPatch(NR_isEnabled()) end)
