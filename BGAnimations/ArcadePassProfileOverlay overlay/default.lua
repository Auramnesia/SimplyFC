-- ArcadePass: show the profile loaded on each side in the bottom corners of
-- every menu. On ArcadePass cabinets the local profile list is never shown,
-- so this is the only place customers and staff can see who is signed in.
-- Registered as an overlay screen in metrics.ini (Common:OverlayScreens).
-- While ArcadePass is enabled this replaces the engine's credits text for
-- joined sides (see ScreenSystemLayer overlay.lua).

local function HideOnThisScreen()
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return true end
	local name = screen:GetName()
	-- Gameplay and Edit draw their own content in the bottom corners.
	return name:match("^ScreenGameplay") ~= nil or name:match("^ScreenEdit") ~= nil
end

-- Idle logout: an attended cabinet should not sit signed in while nobody is
-- playing. The engine already tracks seconds since the last input event on
-- either side (any button press or release resets it), so this only has to
-- turn that number into a warning prompt and a sign-out.
local IDLE_PROMPT_SECONDS = 60
local IDLE_LOGOUT_SECONDS = 100  -- prompt stays up for 40 seconds

-- True while there is a side worth signing out: joined locally, or holding a
-- pass authorization that was never joined.
local function AnythingToLogOut()
	if not PREFSMAN:GetPreference("ArcadePassEnabled") then return false end
	for pn in ivalues(PlayerNumber) do
		if GAMESTATE:IsHumanPlayer(pn) or ArcadePass.HasAuthorization(pn) then
			return true
		end
	end
	return false
end

-- The root actor of this overlay does not reliably receive Init/On commands
-- and its command queue is not reliably run, so everything here is done with
-- direct calls: the watch is an update function on a child actor, and the
-- logout itself is a plain function rather than a queued command.
local idle_watch_started = false
local idle_watch_accum = 0

local function DoIdleLogout(root)
	local prompt = root:GetChild("IdlePrompt")
	if prompt then prompt:visible(false) end

	local sides = {}
	for pn in ivalues(PlayerNumber) do
		if GAMESTATE:IsHumanPlayer(pn) or ArcadePass.HasAuthorization(pn) then
			sides[#sides+1] = ToEnumShortString(pn)
		end
	end
	if #sides > 0 then
		SCREENMAN:SystemMessage("ArcadePass: signing out " .. table.concat(sides, " and ") .. " (idle)")
	end
	for pn in ivalues(PlayerNumber) do
		ArcadePass.LogOut(pn)
	end

	-- Back to the cabinet's home screen, where the next scan starts fresh.
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen:GetName() ~= "ScreenSelectProfile" then
		SCREENMAN:SetNewScreen("ScreenSelectProfile")
	end
end

local function IdleWatch(root, dt)
	idle_watch_accum = idle_watch_accum + dt
	if idle_watch_accum < 0.2 then return end
	idle_watch_accum = 0

	local prompt = root:GetChild("IdlePrompt")
	if not prompt then return end

	local idle = ArcadePass.GetIdleSeconds()
	if idle < IDLE_PROMPT_SECONDS then
		-- Input happened; a later idle period may sign out again.
		SL.Global.ArcadePassIdleLogoutIdle = nil
	end

	local active = AnythingToLogOut() and not HideOnThisScreen()
	if not active then
		prompt:visible(false)
		return
	end

	-- Returning home can re-join guests, and the overlay is rebuilt per screen,
	-- so "already signed out" is remembered on the theme's global table; only
	-- real input (idle dropping) re-arms it.
	if SL.Global.ArcadePassIdleLogoutIdle then
		prompt:visible(false)
		return
	end

	if idle >= IDLE_LOGOUT_SECONDS then
		SL.Global.ArcadePassIdleLogoutIdle = idle
		DoIdleLogout(root)
		return
	end

	local show = idle >= IDLE_PROMPT_SECONDS
	prompt:visible(show)
	if show then
		local countdown = prompt:GetChild("IdleCountdown")
		if countdown then
			local text = ("Signing out in %d"):format(math.max(0, math.ceil(IDLE_LOGOUT_SECONDS - idle)))
			if countdown:GetText() ~= text then
				countdown:settext(text)
			end
		end
	end
end

local function StartIdleWatch(root)
	if idle_watch_started then return end
	local watcher = root:GetChild("IdleWatcher")
	if not watcher then return end
	idle_watch_started = true
	watcher:SetUpdateFunction(function(_, dt) IdleWatch(root, dt) end)
end

local function LabelFor(pn)
	local on_player_1 = pn == PLAYER_1
	return Def.BitmapText {
		Font = "Common Normal",
		Name = "Label" .. PlayerNumberToString(pn),
		InitCommand = function(self)
			self:settext("")
			self:zoom(SL_WideScale(0.8, 0.9)):vertalign("bottom")
			self:y(_screen.h - 9)
			if on_player_1 then
				self:horizalign("left"):x(SL_WideScale(38, 45))
			else
				self:horizalign("right"):x(_screen.w - SL_WideScale(38, 45))
			end
		end
	}
end

local t = Def.ActorFrame {
	-- "Update" is not a built-in per-frame command; it has to be queued
	-- whenever the state we display can change.
	OnCommand = function(self) self:queuecommand("Update") end,
	ScreenChangedMessageCommand = function(self)
		self:queuecommand("Update")
		StartIdleWatch(self)
	end,
	PlayerJoinedMessageCommand = function(self)
		self:queuecommand("Update")
		StartIdleWatch(self)
	end,
	PlayerUnjoinedMessageCommand = function(self) self:queuecommand("Update") end,
	PlayerProfileSetMessageCommand = function(self) self:queuecommand("Update") end,
	ArcadePassScannedMessageCommand = function(self)
		self:queuecommand("Update")
		StartIdleWatch(self)
	end,
	ArcadePassLoggedOutMessageCommand = function(self) self:queuecommand("Update") end,
	UpdateCommand = function(self)
		local hide = HideOnThisScreen() or not PREFSMAN:GetPreference("ArcadePassEnabled")
		for pn in ivalues(PlayerNumber) do
			local label = self:GetChild("Label" .. PlayerNumberToString(pn))
			local text = ""
			if label and not hide and GAMESTATE:IsHumanPlayer(pn) then
				local name = ""
				if PROFILEMAN:IsPersistentProfile(pn) then
					local profile = PROFILEMAN:GetProfile(pn)
					if profile then
						name = profile:GetDisplayName()
					end
				end
				if name == "" then
					name = "GUEST"
				end
				text = ToEnumShortString(pn) .. "  " .. name
			end
			if label:GetText() ~= text then
				label:settext(text)
			end
		end
	end,
}

t[#t+1] = LabelFor(PLAYER_1)
t[#t+1] = LabelFor(PLAYER_2)

-- Frame-driven idle watcher; see StartIdleWatch/IdleWatch above.
t[#t+1] = Def.ActorFrame {
	Name = "IdleWatcher",
}

-- The idle warning panel. Hidden until the cabinet has gone untouched for
-- IDLE_PROMPT_SECONDS; the countdown text is refreshed by IdleWatch.
t[#t+1] = Def.ActorFrame {
	Name = "IdlePrompt",
	InitCommand = function(self) self:visible(false) end,

	-- dim the whole screen so it is obvious something is about to happen
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(_screen.w, _screen.h):xy(_screen.cx, _screen.cy):diffuse(0, 0, 0, 0.55)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(SL_WideScale(430, 470) + 4, 154):xy(_screen.cx, _screen.cy):diffuse(1, 1, 1, 0.3)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(SL_WideScale(430, 470), 150):xy(_screen.cx, _screen.cy):diffuse(0, 0, 0, 0.92)
		end
	},

	LoadFont("Common Normal")..{
		Name = "IdleTitle",
		Text = "ARE YOU STILL THERE?",
		InitCommand = function(self)
			self:zoom(SL_WideScale(0.95, 1.05)):x(_screen.cx):y(_screen.cy - 45):diffuse(1, 1, 1, 1)
		end
	},
	LoadFont("Common Normal")..{
		Name = "IdleCountdown",
		Text = "Signing out in 40",
		InitCommand = function(self)
			self:zoom(SL_WideScale(0.85, 0.95)):x(_screen.cx):y(_screen.cy + 2):diffuse(0.93, 0.52, 0.70, 1)
		end
	},
	LoadFont("Common Normal")..{
		Name = "IdleBody",
		Text = "Press any button to stay signed in",
		InitCommand = function(self)
			self:zoom(SL_WideScale(0.7, 0.8)):x(_screen.cx):y(_screen.cy + 42):diffuse(0.8, 0.8, 0.8, 1)
		end
	},
}

return t
