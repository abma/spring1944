function gadget:GetInfo()
  return {
    name      = "Transport Helper",
    desc      = "Hides units when inside a closed transport, issues stop command to units trying to enter a full transport",
    author    = "FLOZi",
    date      = "09/02/10",
    license   = "PD",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-- Unsynced Ctrl
local SetUnitNoDraw			= Spring.SetUnitNoDraw
-- Synced Read
local GetUnitDefID			= Spring.GetUnitDefID
local GetUnitPosition 		= Spring.GetUnitPosition
local GetUnitTransporter 	= Spring.GetUnitTransporter
local GetUnitsInCylinder 	= Spring.GetUnitsInCylinder
-- Synced Ctrl
local GiveOrderToUnit		= Spring.GiveOrderToUnit

-- Constants
local CMD_LOAD_ONTO = CMD.LOAD_ONTO
local CMD_STOP = CMD.STOP
-- Variables
local massLeft = {}
local toBeLoaded = {}

if (gadgetHandler:IsSyncedCode()) then

local DelayCall = GG.Delay.DelayCall

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_LOAD_ONTO then
		local transportID = cmdParams[1]
		toBeLoaded[unitID] = transportID
	end
	return true
end


function gadget:UnitCreated(unitID, unitDefID, teamID)
	local unitDef = UnitDefs[unitDefID]
	local maxMass = unitDef.transportMass
	if maxMass then
		massLeft[unitID] = maxMass
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	massLeft[unitID] = nil
	toBeLoaded[unitID] = nil
end

local function TransportIsFull(transportID)
	for unitID, targetTransporterID in pairs(toBeLoaded) do
		if targetTransporterID == transportID then
			GiveOrderToUnit(unitID, CMD_STOP, {}, {})
			toBeLoaded[unitID] = nil
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	--Spring.Echo("UnitLoaded")
	local transportDef = UnitDefs[GetUnitDefID(transportID)]
	local unitDef = UnitDefs[unitDefID]
	-- Check if transport is full (former crash risk!)
	massLeft[transportID] = massLeft[transportID] - unitDef.mass
	if massLeft[transportID] == 0 then
		TransportIsFull(transportID)
	end
	if unitDef.xsize == 2 and not (transportDef.minWaterDepth > 0) and not unitDef.customParams.hasturnbutton then 
		-- transportee is Footprint of 1 (doubled by engine) and transporter is not a boat and transportee is not an infantry gun
		SetUnitNoDraw(unitID, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	--Spring.Echo("UnitUnloaded")
	local transportDef = UnitDefs[GetUnitDefID(transportID)]
	local unitDef = UnitDefs[unitDefID]
	massLeft[transportID] = massLeft[transportID] + unitDef.mass
	if unitDef.xsize == 2 and not (transportDef.minWaterDepth > 0) and not unitDef.customParams.hasturnbutton then 
		SetUnitNoDraw(unitID, false)
	end
	DelayCall(Spring.SetUnitVelocity, {unitID, 0, 0, 0}, 16)
end

else

end


