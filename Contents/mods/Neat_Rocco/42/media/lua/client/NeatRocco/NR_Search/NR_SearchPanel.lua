-- NR_SearchPanel.lua
-- NeatUI replacement for ISSearchWindow (Investigate Area / Search Mode).
-- Vanilla logic preserved 1:1 — visual layer only.

require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Config"
require "NeatUI_Framework/NeatTool/NeatTool_3Patch"
require "Foraging/ISSearchManager"
require "Foraging/ISZoneDisplay"
require "Foraging/ISSearchWindow"

NR_SearchPanel = NR_BasePanel:derive("NR_SearchPanel")
NR_SearchPanel.players = {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT     = FONT_HGT_SMALL + 6

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:new(character)
    local manager   = ISSearchManager.getManager(character)
    local pad       = NR_Config.padding
    local hh        = NR_Config.headerHeight
    local playerNum = character:getPlayerNum()

    local labelText = getText("UI_search_mode_focus")
    local labelW    = getTextManager():MeasureStringX(UIFont.Small, labelText)

    local width  = 420
    local height = hh + 100 + pad + BUTTON_HGT + pad + BUTTON_HGT + pad

    local o = ISPanelJoypad.new(self,
        getPlayerScreenLeft(playerNum) + 120,
        getPlayerScreenTop(playerNum)  + 300,
        width, height)
    setmetatable(o, self)
    self.__index = self

    o.manager             = manager
    o.character           = character
    o.playerNum           = playerNum
    o.player              = playerNum  -- read by ISZoneDisplay:canSeeOutside (line 402)
    o.isCollapsed         = false  -- read by ISZoneDisplay:updateTooltip
    o.tooltipForced       = nil    -- read by ISZoneDisplay:updateTooltip
    o.searchFocusCategory = "None"
    o.joypadMoveSpeed     = 20
    o.overrideBPrompt     = true
    o._labelText          = labelText
    o._labelW             = labelW
    o._comboX             = pad + labelW + pad

    NR_BasePanel.initBase(o)

    NR_SearchPanel.players[character] = o
    ISSearchWindow.players[character] = o
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:getWindowTitle()
    return getText("UI_investigate_area_window_title")
end

-- Required by ISZoneDisplay:new(_parent) to position itself below the header
function NR_SearchPanel:titleBarHeight()
    return NR_Config.headerHeight
end

function NR_SearchPanel:getWindowIcon()
    return getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Search.png")
end

function NR_SearchPanel:getInfoText()
    return getText("SurvivalGuide_entrie11moreinfo")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:createChildren()
    NR_BasePanel.createChildren(self)

    local hh  = NR_Config.headerHeight
    local pad = NR_Config.padding

    -- Zone display (animated sky / zone scene — preserved from ISZoneDisplay)
    self.zoneDisplay = ISZoneDisplay:new(self)
    self:addChild(self.zoneDisplay)

    local zoneBottom = hh + self.zoneDisplay.height  -- hh + 100

    -- Search Focus combobox (label drawn in render)
    local comboY = zoneBottom + pad
    self.searchFocus = ISComboBox:new(
        self._comboX, comboY,
        self.width - self._comboX - pad, BUTTON_HGT,
        nil, nil)
    self.searchFocus:initialise()
    self.searchFocus.selected = 1
    self.searchFocus.onChange = self.onChangeSearchFocusCategory
    self.searchFocus.target   = self
    self:updateSearchFocusCategories()
    self:addChild(self.searchFocus)

    -- Toggle search mode button (NeatUI three-patch style)
    local btnL = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png")
    local btnM = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png")
    local btnR = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png")
    local btnY = comboY + BUTTON_HGT + pad
    self.toggleBtn = ISButton:new(
        pad, btnY,
        self.width - pad * 2, BUTTON_HGT,
        "", self.manager, ISSearchManager.toggleSearchMode)
    self.toggleBtn:initialise()
    self.toggleBtn:setDisplayBackground(false)
    self.toggleBtn._nrTitle  = getText("UI_enable_search_mode")
    self.toggleBtn._nrActive = false
    self.toggleBtn.prerender = function(btn)
        local active     = btn._nrActive
        local brightness = (btn.pressed and 0.3) or (btn:isMouseOver() and 0.6) or 0.4
        local r = active and brightness * 0.5 or brightness
        local g = active and brightness * 1.6 or brightness
        local b = active and brightness * 0.5 or brightness
        NeatTool.ThreePatch.drawHorizontal(btn, 0, 0, btn.width, btn.height, btnL, btnM, btnR, 1, r, g, b)
        local title = btn._nrTitle or ""
        local tw    = getTextManager():MeasureStringX(UIFont.Small, title)
        local th    = FONT_HGT_SMALL
        btn:drawText(title, math.floor((btn.width - tw) / 2), math.floor((btn.height - th) / 2), 1, 1, 1, 1, UIFont.Small)
    end
    self:addChild(self.toggleBtn)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Search focus logic (preserved from ISSearchWindow)
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:onChangeSearchFocusCategory(_option)
    self.searchFocusCategory = _option.options[_option.selected].data
end

function NR_SearchPanel:nextSearchFocus()
    self.searchFocus.selected = self.searchFocus.selected + 1
    if not self.searchFocus.options[self.searchFocus.selected] then
        self.searchFocus.selected = 1
    end
    self.searchFocusCategory = self.searchFocus.options[self.searchFocus.selected].data
end

function NR_SearchPanel:updateSearchFocusCategories()
    self.searchFocus:clear()
    self.searchFocus:addOptionWithData(getText("UI_search_mode_no_focus"), "None")
    for _, catDef in pairs(forageSystem.catDefs) do
        local perkLevel = self.character:getPerkLevel(Perks.FromString(catDef.identifyCategoryPerk))
        if not catDef.categoryHidden and perkLevel >= catDef.identifyCategoryLevel then
            local exactCategory = getTextOrNull("IGUI_SearchMode_Categories_" .. catDef.name)
            if exactCategory then
                self.searchFocus:addOptionWithData(exactCategory, catDef.name)
            end
        end
    end
    for i, option in ipairs(self.searchFocus.options) do
        if option.data == self.searchFocusCategory then
            self.searchFocus.selected = i
            return
        end
    end
    self.searchFocus.selected = 1
    self.searchFocusCategory  = "None"
end

function NR_SearchPanel:checkShowFirstTimeSearchTutorial()
    if getCore():isShowFirstTimeSearchTutorial() then
        getCore():setShowFirstTimeSearchTutorial(false)
        getCore():saveOptions()
        SurvivalGuide.openEntry(SurvivalGuideEntry.FORAGING)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Update
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:update()
    if not self:getIsVisible() then return end
    local active = self.manager.isSearchMode
    self.toggleBtn._nrActive = active
    self.toggleBtn._nrTitle  = active and getText("UI_disable_search_mode") or getText("UI_enable_search_mode")
    self:updateSearchFocusCategories()
    ISPanelJoypad.update(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:render()
    ISPanelJoypad.render(self)
    local pad      = NR_Config.padding
    local hh       = NR_Config.headerHeight
    local comboY   = hh + 100 + pad
    local textOffY = math.floor((BUTTON_HGT - FONT_HGT_SMALL) / 2)
    self:drawText(self._labelText, pad, comboY + textOffY, 1, 1, 1, 1, UIFont.Small)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad (preserved from ISSearchWindow)
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:onJoypadDown(button, joypadData)
    if button == Joypad.AButton then
        self.manager:toggleSearchMode()
    elseif button == Joypad.BButton then
        self:close()
    elseif button == Joypad.YButton then
        self:toggleForceAreaTooltip()
    elseif button == Joypad.XButton then
        self:toggleForceVisionTooltip()
    elseif button == Joypad.LBumper then
        self:nextSearchFocus()
    elseif button == Joypad.RBumper then
        setJoypadFocus(self.playerNum, nil)
    end
end

function NR_SearchPanel:toggleForceVisionTooltip()
    self.tooltipForced = (self.tooltipForced == "Vision") and nil or "Vision"
end

function NR_SearchPanel:toggleForceAreaTooltip()
    self.tooltipForced = (self.tooltipForced == "Area") and nil or "Area"
end

function NR_SearchPanel:getAPrompt()    return getText("UI_optionscreen_binding_Toggle Search Mode")       end
function NR_SearchPanel:getBPrompt()    return getText("IGUI_RadioClose")                                  end
function NR_SearchPanel:getXPrompt()    return getText("UI_investigate_area_window_toggle_vision_tooltip") end
function NR_SearchPanel:getYPrompt()    return getText("UI_investigate_area_window_toggle_area_tooltip")   end
function NR_SearchPanel:getLBPrompt()   return getText("UI_search_mode_change_focus")                      end
function NR_SearchPanel:getRBPrompt()   return getText("IGUI_RadioReleaseFocus")                           end
function NR_SearchPanel:isValidPrompt() return self:getIsVisible()                                         end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:close()
    NR_SearchPanel.players[self.character] = nil
    ISSearchWindow.players[self.character] = nil
    self:closeBase()
end

-- (onGainJoypadFocus, onLoseJoypadFocus, isKeyConsumed, onKeyRelease héritées de NR_BasePanel)
