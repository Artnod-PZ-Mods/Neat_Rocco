-- NR_CharInfo_AMSCompat.lua
-- Compat patch for "Armor Makes Sense" (workshop id 3677430162).
--
-- AMSBurdenPanel:syncSizeToScreen forces our window dimensions each frame using
-- panel.canonicalW = host:getWidthOfAllTabs() (the tab strip width). In vanilla,
-- the tab strip ≈ window width so this works. In NeatUI, our icon tab strip is
-- much narrower than the window, causing two problems we patch here:
--
--   1. Bars / names truncation: syncSizeToScreen also calls self:setWidth(canonicalW)
--      on the AMSBurdenPanel itself, shrinking it. Override view.setWidth to always
--      track outer.width so the panel keeps the full window width and bars span it.
--
--   2. Bottom padding too tight: contentH passed by AMS is undersized.
--      - no-drivers branch passes (y + lineH); drivers branch passes only y.
--      - Even (y + lineH) is too tight against our NeatUI border.
--      Inflate contentH by lineHeight + padding*2 to cover both cases.
--
-- We deliberately leave contentW alone so AMS's own screen:setWidth(canonicalW)
-- triggers its _amsMinCharacterInfoWidth clamp -- this restores the vanilla
-- behaviour of the window shrinking when switching from a wider tab (Temperature)
-- to Burden.
--
-- Vanilla tabs (Info, Skills, ...) are untouched because they don't have a
-- syncSizeToScreen method.

require "NeatRocco/NR_CharInfo/NR_CharInfoPanel"
require "NeatRocco/NR_Config"

table.insert(NR_CharInfoPanel.addViewHooks, function(view, _, outer)
    if type(view.syncSizeToScreen) ~= "function" then return end

    -- AMSBurdenPanel:syncSizeToScreen reads tabPanel.tabHeight via view:getParent().
    -- Our views are addChild'd to outer (not shim), so set tabHeight on outer.
    -- Default ISTabPanel.tabHeight is 24; ours matches the NeatUI icon tab bar.
    outer.tabHeight = NR_Config.tabBarHeight

    -- Force the AMS panel width to follow the window width (ignore canonicalW).
    local origSetWidth = view.setWidth
    view.setWidth = function(self)
        return origSetWidth(self, outer.width)
    end

    local orig = view.syncSizeToScreen
    view.syncSizeToScreen = function(self, contentW, contentH)
        return orig(self, contentW, contentH + NR_Config.lineHeight + NR_Config.padding * 2)
    end
end)
