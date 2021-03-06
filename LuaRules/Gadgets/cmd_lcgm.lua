function gadget:GetInfo()
	return {
		name = "Beaching Command",
		desc = "Give special beaching command to LCG(M)",
		author = "FLOZi (C. Lawrence)",
		date = "27 December 2010",
		license = "GNU GPL v2",
		layer = 1,
		enabled = true
	}
end

-- SYNCED only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

-- Localisations
local DelayCall 			= GG.Delay.DelayCall
-- MoveCtrl
local mcDisable				= Spring.MoveCtrl.Disable
local mcEnable				= Spring.MoveCtrl.Enable
local mcSetCollideStop		= Spring.MoveCtrl.SetCollideStop
local mcSetTrackGround		= Spring.MoveCtrl.SetTrackGround
local mcSetVelocity			= Spring.MoveCtrl.SetVelocity
-- Synced Read
local GetGroundHeight		= Spring.GetGroundHeight
local GetUnitBasePosition	= Spring.GetUnitBasePosition
-- Synced Ctrl
local CallCOBScript			= Spring.CallCOBScript
local EditUnitCmdDesc		= Spring.EditUnitCmdDesc
local FindUnitCmdDesc		= Spring.FindUnitCmdDesc
local InsertUnitCmdDesc		= Spring.InsertUnitCmdDesc
local SetUnitArmored		= Spring.SetUnitArmored
local SetUnitWeaponState	= Spring.SetUnitWeaponState
-- Unsynced Ctrl
local SendMessageToTeam		= Spring.SendMessageToTeam

-- Constants
local CMD_BEACH = GG.CustomCommands.GetCmdID("CMD_BEACH")
local MIN_DEPTH = -150 -- lowest depth that we allow the command for
local ACTUAL_MIN_DEPTH = -11 -- lowest depth that the model should be lowered to
local SINK_RATE = -0.1
local SINK_TIME = math.floor(ACTUAL_MIN_DEPTH / SINK_RATE)
local ARMOUR_MULTIPLE = 0.50
local ACCURACY_MULT = 0.50
local BASE_ACCURACY = WeaponDefs[ UnitDefNames["gbrlcgm"].weapons[1].weaponDef ].accuracy -- ;_;

-- Variables
local activeUnits = {}


local beachDesc= {
	name	= "Beach",
	action	= "beach",
	id		= CMD_BEACH,
	type	= CMDTYPE.ICON_MODE,
	tooltip	= "Ground the ship for improved armour and accuracy",
	params	= {0, 'Beach', 'Unbeach'},
}

local function EndBeach(unitID, disable)
	CallCOBScript(unitID, "StopMoving", 0)
	mcSetVelocity(unitID, 0, 0, 0)
	activeUnits[unitID] = nil
	if disable then -- unit has surfaced
		mcDisable(unitID) 
		SetUnitArmored(unitID, false)
		SetUnitWeaponState(unitID, 1, {accuracy = BASE_ACCURACY})
		SetUnitWeaponState(unitID, 2, {accuracy = BASE_ACCURACY})
	else -- unit is grounded
		SetUnitArmored(unitID, true, ARMOUR_MULTIPLE) 
		SetUnitWeaponState(unitID, 1, {accuracy = BASE_ACCURACY * ACCURACY_MULT})
		SetUnitWeaponState(unitID, 2, {accuracy = BASE_ACCURACY * ACCURACY_MULT})
	end
end

local function Beach(unitID, groundHeight)
	CallCOBScript(unitID, "EmitWakes", 0)
	mcEnable(unitID)
	mcSetVelocity(unitID, 0, SINK_RATE, 0)
	if groundHeight >= ACTUAL_MIN_DEPTH then
		mcSetTrackGround(unitID, true)
		mcSetCollideStop(unitID, true)
	else
		DelayCall(EndBeach, {unitID, false}, SINK_TIME)
	end
end

local function UnBeach(unitID)
	CallCOBScript(unitID, "EmitWakes", 0)
	mcSetVelocity(unitID, 0, -SINK_RATE, 0)
	DelayCall(EndBeach, {unitID, true}, SINK_TIME)
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if unitDefID == UnitDefNames["gbrlcgm"].id then -- switch to custom param?
		InsertUnitCmdDesc(unitID, beachDesc)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	activeUnits[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_BEACH then
		-- check that this unit has this command
		local cmdDescID = FindUnitCmdDesc(unitID, CMD_BEACH)
		if not cmdDescID then return false end
		-- check unit is not already un/beaching
		if activeUnits[unitID] then return false end
		-- check unit is in shallow enough water
		local x, _, z = GetUnitBasePosition(unitID)
		local groundHeight = GetGroundHeight(x,z)
		if groundHeight < MIN_DEPTH then 
			SendMessageToTeam(teamID, "Water is too deep to beach here!")
			return false
		end
		if cmdParams[1] == 1 then
			activeUnits[unitID] = true
			Beach(unitID, groundHeight)
		else
			activeUnits[unitID] = true
			UnBeach(unitID)
		end
		--Spring.MoveCtrl.SetLimits(unitID, x, -15, z, x, 15, z)
		beachDesc.params[1] = cmdParams[1]
		EditUnitCmdDesc(unitID, cmdDescID, { params = beachDesc.params})
	end
	return true
end

function gadget:MoveCtrlNotify(unitID, unitDefID, unitTeam, data)
	if activeUnits[unitID] then
		mcSetTrackGround(unitID, false)
		mcSetCollideStop(unitID, false)
		EndBeach(unitID)
	end
	return false
end

