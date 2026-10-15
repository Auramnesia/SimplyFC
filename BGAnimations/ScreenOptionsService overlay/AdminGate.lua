-- ArcadePass: the operator menu is an administrator's screen.
--
-- This is the choke point, so the rule holds no matter which door was used:
-- [ScreenTitleMenu]'s "Options" (gated in metrics.ini as well), the global
-- operator key (Scroll Lock -- the engine pops every screen and comes straight
-- here), or anything else that links to ScreenOptionsService.
--
-- Inert whenever ArcadePass is off, or when an administrator's pass is signed
-- in, so a desktop install and an operator with a card behave exactly as Simply
-- Love does.  Compare ./CompatibilityChecks.lua in ScreenInit overlay, which
-- bounces to the operator menu the same way.

return Def.Actor{
	OnCommand=function()

		if ArcadePass.Unrestricted() then return end

		SM("Administrator pass required")

		-- straight to the card gate; SystemMessages live on the always-present
		-- ScreenSystemLayer, so this one is still readable once we get there
		SCREENMAN:SetNewScreen("ScreenSelectProfile")
	end
}
