-- NR_Patch_ButcherHook.lua
-- Monkey-patches ISOpenButcherHookUI.perform to open NR_ButcherHookPanel.

require "NeatRocco/NR_ButcherHook/NR_ButcherHookPanel"

ISOpenButcherHookUI._NR_old_perform = ISOpenButcherHookUI._NR_old_perform or ISOpenButcherHookUI.perform

local function NR_performButcherHook(self)
    -- Must be called first, like vanilla (removes action from queue)
    ISBaseTimedAction.perform(self)

    -- Close any existing panel for the same hook (splitscreen / multiplayer)
    for playerNum = 1, 4 do
        local existing = NR_ButcherHookPanel.ui and NR_ButcherHookPanel.ui[playerNum - 1] or nil
        if existing ~= nil and existing.hook == self.hook then
            existing:close()
        end
    end

    local ui = NR_ButcherHookPanel:new(
        getPlayerScreenLeft(self.playerNum) + 100,
        getPlayerScreenTop(self.playerNum) + 100,
        self.hook, self.player
    )
    ui:initialise()
    ui:addToUIManager()
    if getJoypadData(self.playerNum) then
        setJoypadFocus(self.playerNum, ui)
    end
end

local function NR_applyButcherHookToggle(enabled)
    if enabled then
        ISOpenButcherHookUI.perform = NR_performButcherHook
    else
        ISOpenButcherHookUI.perform = ISOpenButcherHookUI._NR_old_perform
        for i = 0, 3 do
            local inst = NR_ButcherHookPanel.ui[i]
            if inst then inst:close() end
        end
    end
end

NR_RegisterToggleCallback(NR_applyButcherHookToggle)
