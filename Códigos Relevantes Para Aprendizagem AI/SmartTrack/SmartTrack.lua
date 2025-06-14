SmartTrack = LibStub("AceAddon-3.0"):NewAddon("SmartTrack", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

--Getting locale table
local L = LibStub("AceLocale-3.0"):GetLocale("SmartTrack");

--Hooking up config
local AceConfig = LibStub("AceConfig-3.0");
local AceCongigDialog = LibStub("AceConfigDialog-3.0");

--Addon version
local SmartTrackVersion = "1.1";

--For Last tracking to be remembered
local SmartTrack_last_tracking = "";

--Default options
SmartTrack.defaults = 
{
       	char = 
	{
               	handle = 
		{
               		["EnableInPVP"] = false,
			["EnableOutOfCombat"] = false,
			["RememberLast"] = false,
			["DamageBonusOnly"] = false,
		},
	},
}

--Options
SmartTrack_Options = {
    	name = "SmartTrackConfig",
    	handler = SmartTrack,
    	type = 'group',
    	args = 
	{
        	General = 
		{
            		order = 1,
            		type = "group",
           	 	name = "General",
            		desc = "General settings",
           	 	args = 
			{
            	    		EnableInPVP = 
				{
            	    			type = "toggle",
            	    			order = 1,
            	    			name = "Enable in PvP",
            	    			desc = "If enabled it will allow addon to automatically change tracking when you are on Arena or Battleground",
            	    			get = function(info) return SmartTrack.db.char.handle["EnableInPVP"] end,
                   			set = function(info,input) SmartTrack.db.char.handle["EnableInPVP"] = input end,
       				},
            	    		EnableOutOfCombat = 
				{
            	    			type = "toggle",
            	    			order = 2,
            	    			name = "Out of combat",
            	    			desc = "If enabled it will allow addon to automatically change tracking even when you are out of combat. Enabling this with [Remember tracking] enabled is not recommended.",
            	    			get = function(info) return SmartTrack.db.char.handle["EnableOutOfCombat"] end,
                   			set = function(info,input) SmartTrack.db.char.handle["EnableOutOfCombat"] = input end,
       				},
            	    		RememberLast = 
				{
            	    			type = "toggle",
            	    			order = 3,
            	    			name = "Remember tracking",
            	    			desc = "If enabled it will remember what tracking you had before changing it and restore it when out of combat. Enabling this with [Out of combat] enabled is not recommended.",
            	    			get = function(info) return SmartTrack.db.char.handle["RememberLast"] end,
                   			set = function(info,input) SmartTrack.db.char.handle["RememberLast"] = input end,
       				},
            	    		DamageBonusOnly = 
				{
            	    			type = "toggle",
            	    			order = 4,
            	    			name = "Damage Bonus Only",
            	    			desc = "If enabled it will auto change tracking ONLY IF you are tracking something that doesn't give you the [Improved tracking] damage bonus (herbs for instance). So you will get it. If the target is right.",
            	    			get = function(info) return SmartTrack.db.char.handle["DamageBonusOnly"] end,
                   			set = function(info,input) SmartTrack.db.char.handle["DamageBonusOnly"] = input end,
       				},
 			},
 		},
    	},
}

--Addon initialized
function SmartTrack:OnInitialize()
    	AceConfig:RegisterOptionsTable("SmartTrackConfig", SmartTrack_Options, nil)
    	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SmartTrackConfig", "SmartTrack")
   	self.db = LibStub("AceDB-3.0"):New("SmartTrackDB", SmartTrack.defaults)
   	db = self.db.char
   	LibStub("AceComm-3.0"):Embed(self)
end

--Addon enabled
function SmartTrack:OnEnable()
    	self:RegisterEvent("PLAYER_REGEN_DISABLED")
    	self:RegisterEvent("PLAYER_REGEN_ENABLED")
    	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	--Showing addon version in chat
    	self:Print("SmartTrack ver."..SmartTrackVersion.." is Active")
end

--Checking if given tracking is active - so we won't be enabling it if it is already enabled
function SmartTrack:CheckTrack(track)
    	for i = 1, GetNumTrackingTypes() do
		local name, texture, TrackActive, category = GetTrackingInfo(i)

		if (name == track) then
	   		if (TrackActive == 1) then
	      			return true
           		end
        	end
    	end

    	return false
end

--Getting Active tracking name - so we can remember it
function SmartTrack:GetActiveTrack()
   	for i = 1, GetNumTrackingTypes() do
		local name, texture, TrackActive, category = GetTrackingInfo(i)

	   	if (TrackActive == 1) then
	      		return name
           	end
    	end

    	return nil
end

--Getting the ID of given tracking so we can Set it by ID with SetTracking command, so we can restore any remembered tracking when needed
function SmartTrack:GetTrackId(track)
   	 for i = 1, GetNumTrackingTypes() do
		local name, texture, TrackActive, category = GetTrackingInfo(i)

		if (name == track) then
	      		return i
        	end
    	end

    	return 0
end

--Checking PVP status returns true when we are on arena or BG and [Enable in PvP] option is disabled. Otherwise returns false.
function SmartTrack:isPVP()
	if not(SmartTrack.db.char.handle["EnableInPvP"]) then
	    	local isIn, inType = IsInInstance()

		if ((inType == "pvp") or (inType == "arena")) then
			return true
		end
	end

	return false
end

--Checking if we are in combat and the target status is ok - so we won't be changing tracking if target is dead/ghost/friendly
function SmartTrack:isCombat()
	if ((InCombatLockdown() or SmartTrack.db.char.handle["EnableOutOfCombat"]) and (UnitIsDeadOrGhost("target") == nil) and (UnitIsEnemy("player", "target") == 1) and UnitCanAttack("player","target")) then
            	return true
	end

	return false
end

--Restoring remembered tracking. Any.
function SmartTrack:RestoreTrack()
   	if (SmartTrack.db.char.handle["RememberLast"]) then
		if not(self:CheckTrack(SmartTrack_last_tracking)) then
          		if not(self:isPVP()) then
            			SetTracking(self:GetTrackId(SmartTrack_last_tracking))
          		end
       		end
   	end
end

--Checking target type. If it's in Localized table - returns true. Otherwise - false. Needed to prevent AceLoccale asserts on various target types for which no tracking is available, i.e. critter, totem, etc.
function SmartTrack:CheckTarget(target)
	local result = false

	function check(targetType, trackType)
		if (targetType == target) then
			result = true
			return
		end
	end

	table.foreach(L, check)

	return result
end

--Checking if we are already tracking with damage bonus
function SmartTrack:CheckForBonus()
	local result = false
	local activeType = self:GetActiveTrack()

	local function check(targetType, trackType)
		if (trackType == activeType) then
			result = true
			return
		end
	end

	table.foreach(L,check)

	return result
end

--Changing tracking according to target type if suitable.
function SmartTrack:SmartTrack()
	if (SmartTrack.db.char.handle["DamageBonusOnly"]) then
		if (self:CheckForBonus()) then
			return
		end
	end

	if (self:isCombat()) then
		local targetType = UnitCreatureType("target")

		if (targetType ~= nil) then
			if (self:CheckTarget(targetType)) then
    				local trackType = L[targetType];
		
    				if (trackType ~= nil) then
       					if not(self:CheckTrack(trackType)) then
          					if not(self:isPVP()) then
	   		  				SetTracking(self:GetTrackId(trackType))
	          				end
       					end
    				end
			end
		end
	end
end

--Combat started. Remembering current tracking. And changing it.
function SmartTrack:PLAYER_REGEN_DISABLED()
	SmartTrack_last_tracking = self:GetActiveTrack();

  	self:SmartTrack();
end

--Combat ended. Restoring remembered tracking.
function SmartTrack:PLAYER_REGEN_ENABLED()
   	self:RestoreTrack();
end

--Target changed. Changing tracking.
function SmartTrack:PLAYER_TARGET_CHANGED()
 	self:SmartTrack();
end

function SmartTrack:GetMessage(info)
    	return self.db.profile.message
end

function SmartTrack:SetMessage(info, newValue)
    	self.db.profile.message = newValue
end

function SmartTrack:IsShowInChat(info)
    	return self.db.profile.showInChat
end

function SmartTrack:ToggleShowInChat(info, value)
    	self.db.profile.showInChat = value
end

function SmartTrack:IsShowOnScreen(info)
    	return self.db.profile.showOnScreen
end

function SmartTrack:ToggleShowOnScreen(info, value)
    	self.db.profile.showOnScreen = value
end