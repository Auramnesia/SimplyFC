-- Simply FullCombo: on this cabinet the song select screen has no gray header
-- bar. The original header (screen name, EventMode session timer, stage
-- number, pad indicators) is replaced by the cabinet logo in the top-left
-- corner, sized and placed to sit in the strip the old bar occupied (the song
-- banner starts around y=42 on a 720p screen).
--
-- The logo asset is 2x scale; 0.3 zoom leaves it about 31 pixels tall.

local t = Def.ActorFrame{}

t[#t+1] = LoadActor( THEME:GetPathG("", "Common FullCombo logo.png") )..{
	Name="FullComboLogo",
	InitCommand=function(self)
		self:horizalign("left"):vertalign("top")
		self:zoom(0.3)
		self:xy(SL_WideScale(14, 18), 6)
		self:diffusealpha(0)
	end,
	OnCommand=function(self) self:sleep(0.1):decelerate(0.33):diffusealpha(1) end,
	OffCommand=function(self) self:linear(0.2):diffusealpha(0) end,
}

return t
