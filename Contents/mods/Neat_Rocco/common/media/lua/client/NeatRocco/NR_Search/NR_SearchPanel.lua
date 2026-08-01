-- NR_SearchPanel.lua
-- Derives from ISSearchWindow and calls its vanilla chain.
-- Mod compatibility: any mod patching ISSearchWindow:initialise / :update
-- (e.g. Auto Forage, id=3478924012) runs automatically.
--
-- NeatUI skin is partial: NR_Header replaces the vanilla titlebar, body has
-- the NeatUI background, and self.toggleSearchMode is reskinned in three-patch
-- style. All other widgets (searchFocus combobox, mod-added widgets) keep
-- their vanilla style.

require "Foraging/ISSearchManager"
require "Foraging/ISZoneDisplay"
require "Foraging/ISSearchWindow"
require "NeatRocco/NR_Utils/NR_BaseCW"
require "NeatRocco/NR_Utils/NR_CollapseUtils"
require "NeatRocco/NR_Utils/NR_DrawUtils"
require "NeatRocco/NR_Config"
require "NeatUI_Framework/NeatTool/NeatTool_3Patch"

NR_SearchPanel = ISSearchWindow:derive("NR_SearchPanel")
NR_SearchPanel.players = {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- Three-patch button skin for self.toggleSearchMode (matches vanilla wide-rectangle button).
local function applyToggleSkin(btn)
    if not btn then return end
    local btnL = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png")
    local btnM = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png")
    local btnR = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png")
    btn:setDisplayBackground(false)
    btn._nrTitle  = btn.title or ""
    btn._nrActive = false
    btn:setTitle("")  -- prevent vanilla draw of title text
    btn.prerender = function(b)
        local active     = b._nrActive
        local brightness = (b.pressed and 0.3) or (b:isMouseOver() and 0.6) or 0.4
        local r  = active and brightness * 0.5 or brightness
        local g  = active and brightness * 1.6 or brightness
        local bv = active and brightness * 0.5 or brightness
        NeatTool.ThreePatch.drawHorizontal(b, 0, 0, b.width, b.height, btnL, btnM, btnR, 1, r, g, bv)
        local title = b._nrTitle or ""
        local tw = getTextManager():MeasureStringX(UIFont.Small, title)
        local th = FONT_HGT_SMALL
        b:drawText(title, math.floor((b.width - tw) / 2), math.floor((b.height - th) / 2), 1, 1, 1, 1, UIFont.Small)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:new(character)
    local manager   = ISSearchManager.getManager(character)
    local playerNum = character:getPlayerNum()

    -- ISSearchWindow.new sets props (manager, character, player, title, ...), the default
    -- position (x=120, y=300) and calls :initialise(), which registers the window with
    -- ISLayoutManager. The layout manager then restores the saved position/size (vanilla
    -- behaviour). We no longer override x/y here, so the saved position is respected.
    local o = ISSearchWindow.new(self, manager)
    -- ISSearchWindow.new sets o.player but not o.playerNum. NR_Patch_Search reads playerNum.
    o.playerNum = playerNum

    NR_SearchPanel.players[character] = o
    ISSearchWindow.players[character] = o   -- AF (and other mods) read this to find the instance
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity (consumed by NR_Header)
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:titleBarHeight()
    return NR_Config.headerHeight
end

function NR_SearchPanel:getWindowTitle()
    return getText("UI_investigate_area_window_title")
end

-- No getWindowIcon: the title icon is intentionally omitted to keep the header
-- compact (collapse + info buttons on the left, close on the right).

function NR_SearchPanel:getInfoText()
    return getText("SurvivalGuide_entrie11moreinfo")
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:initialise()
    -- Run vanilla chain (+ Auto Forage etc. if installed). This creates all widgets:
    -- zoneDisplay, searchFocus, toggleSearchMode (vanilla), plus any mod-added widgets.
    -- It also calls addToUIManager + setHeight + setVisible(false).
    ISSearchWindow.initialise(self)

    -- Apply NeatUI skin: dark body bg, hide vanilla titlebar buttons, add NR_Header.
    NR_BaseCW.initBase(self)
    NR_BaseCW.createHeader(self)
    if self.pinButton    then self.pinButton:setVisible(false)    end
    if self.resizeWidget then self.resizeWidget:setVisible(false) end

    -- Re-skin the wide toggleSearchMode button (vanilla ISButton -> NeatUI three-patch).
    applyToggleSkin(self.toggleSearchMode)

    -- Collapse/peek via NR_CollapseUtils (adds the collapse button through NR_Header).
    NR_CollapseUtils.init(self)
    -- The vanilla chain ran RegisterWindow -> RestoreLayout, which may have set
    -- pin=false / collapsed from a saved layout. Reset to a clean expanded state;
    -- collapse is now driven by NR_CollapseUtils, not the vanilla pin mechanism.
    self.pin         = true
    self.isCollapsed = false
    self:clearMaxDrawHeight()
    -- NR_Header hides the info button when it is paired with the collapse button
    -- (the per-tab CharInfo case); our info is static, so keep it visible.
    if self.header and self.header.infoButton then
        self.header.infoButton:setVisible(true)
    end
end

function NR_SearchPanel:prerender()
    -- Skip ISCollapsableWindow.prerender (vanilla title bar + frame); we draw our own.
    -- The body bg uses NinePatchTexture (absolute coords) which bypasses
    -- setMaxDrawHeight clipping, so guard it: when collapsed, only the header
    -- (which draws its own bg) shows.
    if NR_CollapseUtils.isBodyVisible(self) then
        NR_BaseCW.prerenderBody(self)
    end
end

function NR_SearchPanel:render()
    ISSearchWindow.render(self)
end

-- ISSearchWindow:update (vanilla or AF-wrapped) sets self.toggleSearchMode.title each tick.
-- Sync our three-patch skin state from that title + the manager's search mode flag.
function NR_SearchPanel:update()
    if not self:getIsVisible() then return end
    ISSearchWindow.update(self)
    NR_CollapseUtils.update(self)
    local btn = self.toggleSearchMode
    if btn then
        if btn.title and btn.title ~= "" then
            btn._nrTitle = btn.title
            btn:setTitle("")
        end
        btn._nrActive = self.manager and self.manager.isSearchMode
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Collapse / peek (delegated to NR_CollapseUtils; NR_Header wires the collapse button)
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:onClickCollapse() NR_CollapseUtils.onClickCollapse(self) end
function NR_SearchPanel:_onHeaderHover()  NR_CollapseUtils.onHeaderHover(self)   end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:close()
    -- Like vanilla ISSearchWindow:close: only hide, keep the instance alive so its
    -- position is preserved on reopen. Real teardown happens on player death and
    -- mod disable via NR_destroySearchUI.
    self:setVisible(false)
    self:removeFromUIManager()
    if JoypadState.players[self.player + 1] then
        if isJoypadFocusOnElementOrDescendant(self.player, self) then
            setJoypadFocus(self.player, nil)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad — override B (close) and let vanilla handle the rest (A toggle, LB/RB focus, X/Y tooltips).
-- ----------------------------------------------------------------------------------------------------- --

function NR_SearchPanel:onJoypadDown(button, joypadData)
    if button == Joypad.BButton then
        self:close()
        return
    end
    ISSearchWindow.onJoypadDown(self, button, joypadData)
end

function NR_SearchPanel:isKeyConsumed(_) return false end

function NR_SearchPanel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close(); return true end
end
