-- NR_Patch.lua
-- Master orchestrator: requires generic NR dialogs and per-feature patch modules.
-- Each per-feature module (NR_Patches/NR_Patch_<Name>.lua) is self-contained:
-- it caches the vanilla function, defines overrides, an applyToggle function,
-- and registers its toggle callback via NR_RegisterToggleCallback.

require "NeatRocco/NR_ModOptions"

-- ##############################
-- ### Generic NR dialogs     ###
-- ##############################
-- NeatUI-styled overrides of vanilla dialogs. Patched generically with
-- NR_MakePatch below (no per-feature module needed).
require "NeatRocco/NR_Generic/NR_ColorPicker"
require "NeatRocco/NR_Generic/NR_TextBox"
require "NeatRocco/NR_Generic/NR_ModalRichText"
require "NeatRocco/NR_Generic/NR_ConfirmDialog"
require "NeatRocco/NR_Generic/NR_BombTimerDialog"
require "NeatRocco/NR_Generic/NR_AlarmClockDialog"
require "NeatRocco/NR_Generic/NR_DigitalCode"
require "NeatRocco/NR_Fitness/NR_FitnessPanel"

-- ##########################################
-- ### Generic class replacement helper   ###
-- ##########################################
-- Redirects VanillaClass:new(...) to ReplacementClass:new(...).
-- Subclasses that call VanillaClass.new(self, ...) pass through unchanged.
local function NR_MakePatch(VanillaClass, ReplacementClass)
    VanillaClass._NR_old_new = VanillaClass._NR_old_new or VanillaClass.new
    local function patched(self, ...)
        if self == VanillaClass then
            return VanillaClass._NR_old_new(ReplacementClass, ...)
        end
        return VanillaClass._NR_old_new(self, ...)
    end
    NR_RegisterToggleCallback(function(enabled)
        VanillaClass.new = enabled and patched or VanillaClass._NR_old_new
    end)
end

NR_MakePatch(ISColorPicker,       NR_ColorPicker)
NR_MakePatch(ISTextBox,           NR_TextBox)
NR_MakePatch(ISModalRichText,     NR_ModalRichText)
NR_MakePatch(ISModalDialog,       NR_ConfirmDialog)
NR_MakePatch(ISBombTimerDialog,   NR_BombTimerDialog)
NR_MakePatch(ISAlarmClockDialog,  NR_AlarmClockDialog)
NR_MakePatch(ISDigitalCode,       NR_DigitalCode)
NR_MakePatch(ISFitnessUI,         NR_FitnessPanel)

-- ##############################
-- ### Per-feature patches    ###
-- ##############################
require "NeatRocco/NR_Patches/NR_Patch_Livestock"
require "NeatRocco/NR_Patches/NR_Patch_Hutch"
require "NeatRocco/NR_Patches/NR_Patch_ButcherHook"
require "NeatRocco/NR_Patches/NR_Patch_Generator"
require "NeatRocco/NR_Patches/NR_Patch_BBQ"
require "NeatRocco/NR_Patches/NR_Patch_Bake"
require "NeatRocco/NR_Patches/NR_Patch_Farming"
require "NeatRocco/NR_Patches/NR_Patch_Garment"
require "NeatRocco/NR_Patches/NR_Patch_Search"
require "NeatRocco/NR_Patches/NR_Patch_Mech"
require "NeatRocco/NR_Patches/NR_Patch_AnimalTracks"
require "NeatRocco/NR_Patches/NR_Patch_Fluid"
require "NeatRocco/NR_Patches/NR_Patch_Literature"
require "NeatRocco/NR_Patches/NR_Patch_CharInfo"
require "NeatRocco/NR_Patches/NR_Patch_AnimalZoneFirstInfo"
