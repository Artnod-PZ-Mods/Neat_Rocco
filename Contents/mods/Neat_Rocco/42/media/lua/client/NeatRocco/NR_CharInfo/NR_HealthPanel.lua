-- NR_HealthPanel.lua
-- Derives from ISHealthPanel and calls its vanilla chain.
-- Mod compatibility: any mod patching ISHealthPanel.createChildren
-- (e.g. NutritionMakesSense adds a status button) runs automatically.
-- ISButtons added by mods are auto-detected and wrapped as NI_SquareButtons
-- (generic mod icon + button title/tooltip shown on hover), matching the
-- NR_CharInfoPanel tab bar pattern for unknown mod tabs.

require "XpSystem/ISUI/ISHealthPanel"
require "NeatRocco/NR_Config"
require "NeatRocco/NR_Utils/NR_DrawUtils"

NR_HealthPanel = ISHealthPanel:derive("NR_HealthPanel")

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

local GENERIC_MOD_ICON = "media/ui/NeatRocco/CategoryIcon/Icon_Mechanics.png"
local FITNESS_ICON     = "media/ui/NeatRocco/CategoryIcon/Icon_Fitness.png"

-- Builds a callback that delegates to the vanilla ISButton's onclick.
local function makeModBtnCallback(vanillaBtn)
    return function()
        if vanillaBtn.onclick then vanillaBtn.onclick(vanillaBtn.target, vanillaBtn) end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_HealthPanel:new(player, x, y, width, height)
    local o = ISHealthPanel.new(self, player, x, y, width, height)
    o._nrModBtns = {}
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- createChildren — calls the vanilla chain (all mods run here), then wraps fitness
-- and any mod-added ISButtons as NI_SquareButtons.
-- ----------------------------------------------------------------------------------------------------- --

function NR_HealthPanel:createChildren()
    ISHealthPanel.createChildren(self)

    local bsz        = NR_Config.buttonSize
    local isTutorial = getCore():getGameMode() == "Tutorial"

    -- Vanilla fitness button: hide visually (override render to nop) instead of
    -- setVisible(false). Some mods (e.g. NMS) mirror fitness:isVisible() on their
    -- own status button each frame; setVisible(false) would cascade-hide them too.
    local oldFitness = self.fitness
    oldFitness.prerender = function() end
    oldFitness.render    = function() end

    self._neatFitnessBtn = NI_SquareButton:new(oldFitness.x, oldFitness.y, bsz,
        getTexture(FITNESS_ICON),
        self, function() ISNewHealthPanel.onClick(self, { internal = "FITNESS" }) end)
    self._neatFitnessBtn:initialise()
    self._neatFitnessBtn:setActive(true)
    self._neatFitnessBtn:setActiveColor(0.95, 0.5, 0.1)
    self._neatFitnessBtn.tabName = getText("ContextMenu_Fitness")
    self:addChild(self._neatFitnessBtn)
    if isTutorial then self._neatFitnessBtn:setVisible(false) end

    -- Auto-detect mod-added ISButtons: collect first, then wrap (avoids mutating
    -- self.children during iteration). self.children is keyed by ID (not sequential),
    -- so pairs() is required. Pattern matches NR_RoostPanel:67-88.
    local knownVanilla = {
        [self.healthPanel]    = true,
        [self.listbox]        = true,
        [self.bodyPartPanel]  = true,
        [self.fitness]        = true,
        [self._neatFitnessBtn] = true,
    }
    local modCandidates = {}
    for _, child in pairs(self.children) do
        if not knownVanilla[child] and child.onclick then
            table.insert(modCandidates, child)
        end
    end
    for _, child in ipairs(modCandidates) do
        child.prerender = function() end
        child.render    = function() end
        local nrBtn = NI_SquareButton:new(0, 0, bsz,
            getTexture(GENERIC_MOD_ICON),
            self, makeModBtnCallback(child))
        nrBtn._vanillaBtn = child
        nrBtn:initialise()
        nrBtn:setActive(true)
        nrBtn:setActiveColor(0.95, 0.5, 0.1)
        self:addChild(nrBtn)
        table.insert(self._nrModBtns, nrBtn)
    end

    -- Vanilla ISHealthPanel:render() draws "IGUI_health_RightClickTreatement" at the bottom
    -- but does not include it in setWidthAndParentWidth's width calculation. Bump tabtotalwidth
    -- so update() accounts for it.
    local healthTextW = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_health_RightClickTreatement")) + 20
    if self.tabtotalwidth < healthTextW then
        self.tabtotalwidth = healthTextW
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- render — calls the full vanilla+mods chain, then syncs NI_SquareButton positions
-- and visibility from the (now invisible) vanilla buttons.
-- ----------------------------------------------------------------------------------------------------- --

function NR_HealthPanel:render()
    ISHealthPanel.render(self)

    local isTutorial = getCore():getGameMode() == "Tutorial"

    -- Sync NeatUI fitness button from vanilla position (vanilla render repositions fitness.y each frame)
    if self.fitness then
        self._neatFitnessBtn:setX(self.fitness.x)
        self._neatFitnessBtn:setY(self.fitness.y)
        self._neatFitnessBtn:setVisible(not self.otherPlayer and not isTutorial)
        self._neatFitnessBtn.tabName = getText("ContextMenu_Fitness")
        if self._neatFitnessBtn:isMouseOver() then
            NR_DrawUtils.drawTooltipAtMouse(self, self._neatFitnessBtn.tabName)
        end
    end

    -- Sync mod buttons from their vanilla counterparts (pattern NR_RoostPanel:189-202)
    for _, nrBtn in ipairs(self._nrModBtns) do
        local vBtn = nrBtn._vanillaBtn
        nrBtn:setX(vBtn:getX())
        nrBtn:setY(vBtn:getY())
        nrBtn:setVisible(vBtn:isReallyVisible())
        nrBtn.tabName = vBtn.tooltip or vBtn.title or ""
        if nrBtn:isMouseOver() then
            NR_DrawUtils.drawTooltipAtMouse(self, nrBtn.tabName)
        end
    end
end
