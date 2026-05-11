-- NR_TabBar.lua
-- Utility functions for NI_SquareButton tab bars.
-- Used by NR_HutchPanel, NR_LiteraturePanel, NR_CharInfoPanel.

require "NeatRocco/NR_Config"

NR_TabBar = {}

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- Creates the ISPanel strip, initialises it, adds it as a child of panel, and returns it.
function NR_TabBar.create(panel, y)
    local bar = ISPanel:new(0, y, panel.width, NR_Config.tabBarHeight)
    bar:noBackground()
    bar:initialise()
    panel:addChild(bar)
    return bar
end

-- Creates a NI_SquareButton tab at position n, wired to panel:switchTab(n).
-- Adds it to tabBar and returns it. isActive: whether this button starts active.
function NR_TabBar.addButton(tabBar, panel, n, tex, name, isActive)
    local bsz  = NR_Config.buttonSize
    local pad  = NR_Config.padding
    local btnX = pad + (n - 1) * (bsz + pad)
    local btnY = math.floor((NR_Config.tabBarHeight - bsz) / 2)
    local btn  = NI_SquareButton:new(btnX, btnY, bsz, tex, panel,
                     function() panel:switchTab(n) end)
    btn:initialise()
    btn:setActive(isActive and true or false)
    btn:setActiveColor(0.95, 0.5, 0.1)
    btn.tabName = name
    tabBar:addChild(btn)
    return btn
end

-- Switches active tab: updates button active states and content panel visibility.
function NR_TabBar.switch(tabButtons, contentPanels, count, n)
    for i = 1, count do
        if tabButtons[i]    then tabButtons[i]:setActive(i == n)     end
        if contentPanels[i] then contentPanels[i]:setVisible(i == n) end
    end
end
