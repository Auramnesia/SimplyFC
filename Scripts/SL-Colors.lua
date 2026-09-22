------------------------------------------------------------
-- global functions related to colors in Simply Love

-- Simply FullCombo pairs PLAYER_2 with the periwinkle end of the F/C letter
-- gradient (the last entry in SL.Colors) so both sides read as one brand
-- gradient against PLAYER_1's FullCombo pink.  Simply Love's stock offset
-- (ActiveColorIndex - 2) would land PLAYER_2 on one of the logo-arrow colors.
local FULLCOMBO_PLAYER_2_INDEX = 12

function GetHexColor( n, decorative )
	-- if we were passed nil or a non-number, return white
	if n == nil or type(n) ~= "number" then return Color.White end

	local style = ThemePrefs.Get("VisualStyle")
	local colorTable = SL.Colors
	if decorative then
		colorTable = SL.DecorativeColors
	end
	if style == "SRPG10" then
		colorTable = SL.SRPG10.Colors
	end

	-- use the number passed in to lookup a color in the corresponding color table
	-- ensure the index is kept in bounds via modulo operation
	local clr = ((n - 1) % #colorTable) + 1
	if colorTable[clr] then
		local c = color(colorTable[clr])
		if style == "SRPG10" and not decorative then
			c = LightenColor(c)
		end
		return c
	end

	return Color.White
end

-- convenience function to return the current color from SL.Colors
function GetCurrentColor( decorative )
	return GetHexColor( SL.Global.ActiveColorIndex, decorative )
end

function PlayerColor( pn, decorative )
	if pn == PLAYER_1 then return GetHexColor(SL.Global.ActiveColorIndex, decorative) end
	if pn == PLAYER_2 then return GetHexColor(FULLCOMBO_PLAYER_2_INDEX, decorative) end
	return Color.White
end

function DifficultyColor( difficulty, decorative )
	if (difficulty == nil or difficulty == "Difficulty_Edit") then return color("#B4B7BA") end

	-- use the reverse lookup functionality available to all SM enums
	-- to map a difficulty string to a number
	-- SM's enums are 0 indexed, so Beginner is 0, Challenge is 4, and Edit is 5
	local clr = SL.Global.ActiveColorIndex + (Difficulty:Reverse()[difficulty] - 4)
	return GetHexColor(clr, decorative)
end

function LightenColor(c)
	return { c[1]*1.25, c[2]*1.25, c[3]*1.25, c[4] }
end
