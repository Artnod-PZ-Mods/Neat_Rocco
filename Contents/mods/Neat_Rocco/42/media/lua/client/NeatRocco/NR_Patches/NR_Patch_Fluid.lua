-- NR_Patch_Fluid.lua
-- Monkey-patches ISFluidInfoUI.OpenPanel and ISFluidTransferUI.OpenPanel.

require "NeatRocco/NR_Fluid/NR_FluidContainerPanel"
require "NeatRocco/NR_Fluid/NR_FluidTransferPanel"

-- ### FluidContainer ###
ISFluidInfoUI._NR_old_OpenPanel = ISFluidInfoUI._NR_old_OpenPanel or ISFluidInfoUI.OpenPanel

local function NR_applyFluidContainerToggle(enabled)
    if enabled then
        ISFluidInfoUI.OpenPanel = NR_FluidContainerPanel.OpenPanel
    else
        ISFluidInfoUI.OpenPanel = ISFluidInfoUI._NR_old_OpenPanel
        for pn = 0, 3 do
            local inst = NR_FluidContainerPanel.players[pn]
            if inst then inst:close() end
        end
    end
end

-- ### FluidTransfer ###
ISFluidTransferUI._NR_old_OpenPanel = ISFluidTransferUI._NR_old_OpenPanel or ISFluidTransferUI.OpenPanel

local function NR_applyFluidTransferToggle(enabled)
    if enabled then
        ISFluidTransferUI.OpenPanel = NR_FluidTransferPanel.OpenPanel
    else
        ISFluidTransferUI.OpenPanel = ISFluidTransferUI._NR_old_OpenPanel
        for pn = 0, 3 do
            local entry = NR_FluidTransferPanel.players[pn]
            if entry and entry.instance then entry.instance:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyFluidContainerToggle)
NR_RegisterToggleCallback(NR_applyFluidTransferToggle)
