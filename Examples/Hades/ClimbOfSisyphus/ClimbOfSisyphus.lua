ModUtil.RegisterMod("ClimbOfSisyphus")

local config = { 
	BaseFalls = 0,
	BaseGods = 4,
	MaxGodRate = 1,
	PlayerDamageMult = 1.35,
	EnemyDamageMult = 0.65,
	RarityRate = 0.20,
	ExchangeRate = 0.15,
	EncounterModificationEnabled = false, -- enabling this will cause crashes with bone hydra on second run
	EncounterDifficultyRate = 2.35,
	EncounterMinWaveRate = 0.65,
	EncounterMaxWaveRate = 1.25,
	EncounterEnemyCapRate = 0.65,
	EncounterTypesRate = 0.20
}	
ClimbOfSisyphus.Config = config

local function falloff( x )
	return x/math.sqrt(3+x*x)
end

local function lerp( x, y, t, d )
	if x and y then
		return x*(1-t) + t*y
	end
	return d
end

local function maxInterpolate( x, t )
	if x and t < 1 then
		return x*(1-t) + t
	end
	return t
end

OnAnyLoad{function()
	if not CurrentRun then return end
	if not CurrentRun.TotalFalls then
		CurrentRun.TotalFalls = config.BaseFalls
		CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
	end
end}

function ClimbOfSisyphus.ShowLevelIndicator()
	if ClimbOfSisyphus.LevelIndicator then
		Destroy({Ids = ClimbOfSisyphus.LevelIndicator.Id})
	end
	CurrentRun.TotalFalls = CurrentRun.TotalFalls or config.BaseFalls
	if CurrentRun.TotalFalls > 0 then
		ClimbOfSisyphus.LevelIndicator = CreateScreenComponent({Name = "BlankObstacle", Group = "LevelIndicator", X = 2*ScreenCenterX-55, Y = 110 })
		CreateTextBox({ Id = ClimbOfSisyphus.LevelIndicator.Id, Text = tostring(CurrentRun.TotalFalls), OffsetX = -40, FontSize = 22, Color = color, Font = "AlegreyaSansSCExtraBold"})
		SetAnimation({ Name = "EasyModeIcon", DestinationId = ClimbOfSisyphus.LevelIndicator.Id, Scale = 1 })
	end
end

function ClimbOfSisyphus.EndFallFunc( currentRun, exitDoor)
	AddInputBlock({ Name = "LeaveRoomPresentation" })
	ToggleControl({ Names = { "AdvancedTooltip", }, Enabled = false })

	HideCombatUI()
	LeaveRoomAudio( currentRun, exitDoor )
	wait(0.1)

	AllowShout = false

	RemoveInputBlock({ Name = "LeaveRoomPresentation" })
	ToggleControl({ Names = { "AdvancedTooltip", }, Enabled = true })
end

function ClimbOfSisyphus.RunFall( currentRun, door )
	currentRun.RoomCreations = {}
    currentRun.BlockedEncounters = {}
    currentRun.ClosedDoors = {}
    currentRun.CompletedStyxWings = 0
    currentRun.BiomeRoomCountCache = {}
    currentRun.RoomCountCache = {}
    currentRun.RoomHistory = {}
    currentRun.EncountersCompletedCache = {}
    currentRun.EncountersOccuredCache = {}
    currentRun.EncountersOccuredBiomedCache = {}
	UpdateRunHistoryCache( currentRun )
	door.Room = CreateRoom( RoomData["RoomOpening"] )
	door.ExitFunctionName = "ClimbOfSisyphus.EndFallFunc"
	door.Room.EntranceDirection = false
	currentRun.CurrentRoom.ExitFunctionName = nil
	currentRun.CurrentRoom.ExitDirection = door.Room.EntranceDirection
	currentRun.CurrentRoom.SkipLoadNextMap = false
	currentRun.TotalFalls = CurrentRun.TotalFalls + 1
	currentRun.MetaDepth = GetBiomeDepth( CurrentRun )
end

ModUtil.WrapBaseFunction("RunShopGeneration",function(baseFunc,currentRoom,...)
	if currentRoom.Name == "RoomOpening" then
		currentRoom.Flipped = false
	end
	baseFunc(currentRoom,...)
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("LeaveRoom",function(baseFunc,currentRun,door)
	if currentRun.CurrentRoom.EntranceFunctionName == "RoomEntranceHades" then
		local screen = ModUtil.Hades.NewMenuYesNo(
			"ClimbOfSisyphusExitMenu", 
			function()
				baseFunc(currentRun,door)
			end, 
			function() end,
			function()
				ClimbOfSisyphus.RunFall( currentRun, door )
			end,
			function() end,
			"Endless Calling",
			"Go back to Tartarus to climb once more?",
			" Fall ",
			" Escape ",
			"EasyModeIcon",2.25
		)
	else
		baseFunc(currentRun,door)
	end
end, ClimbOfSisyphus)

ModUtil.BaseOverride("ReachedMaxGods",function(excludedGods)
	if not CurrentRun then return end
	if not CurrentRun.TotalFalls then
		CurrentRun.TotalFalls = config.BaseFalls
		CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
	end

	excludedGods = excludedGods or {}
	local maxLootTypes = config.BaseGods + config.MaxGodRate * CurrentRun.TotalFalls
	local gods = ShallowCopyTable( excludedGods )
	for i, godName in pairs(GetInteractedGodsThisRun()) do
		if not Contains( gods, godName ) then
			table.insert( gods, godName )
		end
	end
	return TableLength( gods ) >= maxLootTypes
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("Damage", function(baseFunc, victim, triggerArgs)
	if triggerArgs.DamageAmount and victim == CurrentRun.Hero then
		triggerArgs.DamageAmount = triggerArgs.DamageAmount * math.pow(config.PlayerDamageMult,CurrentRun.TotalFalls)
	end
	baseFunc( victim, triggerArgs )
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("DamageEnemy", function(baseFunc, victim, triggerArgs)
	if triggerArgs.DamageAmount then
		triggerArgs.DamageAmount = triggerArgs.DamageAmount * math.pow(config.EnemyDamageMult,CurrentRun.TotalFalls)
	end
	baseFunc( victim, triggerArgs )
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction("GetBiomeDepth", function(baseFunc, currentRun, ...)
	if currentRun.MetaDepth then
		return currentRun.MetaDepth + baseFunc( currentRun, ...)
	end
	return baseFunc( currentRun )
end, ClimbOfSisyphus)

ModUtil.WrapBaseFunction( "ShowHealthUI", function( baseFunc )
	ClimbOfSisyphus.ShowLevelIndicator()
	baseFunc()
end, ClimbOfSisyphus)

if config.EncounterModificationEnabled then
	ModUtil.WrapBaseFunction("GenerateEncounter", function (baseFunc, currentRun, room, encounter )
		if not CurrentRun.TotalFalls then
			CurrentRun.TotalFalls = config.BaseFalls
			CurrentRun.MetaDepth = GetBiomeDepth( CurrentRun )
		end

		encounter.DifficultyModifier = (encounter.DifficultyModifier or 0) + config.EncounterDifficultyRate * CurrentRun.TotalFalls
		if encounter.ActiveEnemyCapDepthRamp then
			encounter.ActiveEnemyCapDepthRamp = encounter.ActiveEnemyCapDepthRamp + config.EncounterDifficultyRate * CurrentRun.TotalFalls
		end
		if encounter.ActiveEnemyCapBase then
			encounter.ActiveEnemyCapBase = encounter.ActiveEnemyCapBase + config.EncounterEnemyCapRate * CurrentRun.TotalFalls
		end
		if encounter.ActiveEnemyCapMax then
			encounter.ActiveEnemyCapMax = encounter.ActiveEnemyCapMax + config.EncounterEnemyCapRate * CurrentRun.TotalFalls
		end
		
		local waveCap = #WaveDifficultyPatterns
		encounter.MinWaves = lerp((encounter.MinWaves or 1),waveCap,falloff(config.EncounterMinWaveRate * CurrentRun.TotalFalls))
		encounter.MaxWaves = lerp((encounter.MaxWaves or 1),waveCap,falloff(config.EncounterMaxWaveRate * CurrentRun.TotalFalls))
		if encounter.MinWaves > encounter.MaxWaves then encounter.MinWaves = encounter.MaxWaves end

		if encounter.MaxTypesCap then
			encounter.MaxTypes = lerp((encounter.MaxTypes or 1),encounter.MaxTypesCap,falloff(config.EncounterTypesRate * CurrentRun.TotalFalls))
		else
			encounter.MaxTypes = (encounter.MaxTypes or 1) + config.EncounterTypesRate * CurrentRun.TotalFalls
		end
		if encounter.MaxEliteTypes then
			encounter.MaxEliteTypes = encounter.MaxEliteTypes + config.EncounterTypesRate * CurrentRun.TotalFalls
		end
		
		return baseFunc(currentRun, room, encounter)
	end, ClimbOfSisyphus)
end

ModUtil.WrapBaseFunction("SetTraitsOnLoot", function ( baseFunc, lootData, args )
	local extraRarity = falloff( config.RarityRate * CurrentRun.TotalFalls )
	local extraReplace = falloff( config.ExchangeRate * CurrentRun.TotalFalls )
	lootData.RarityChances.Legendary = maxInterpolate(lootData.RarityChances.Legendary,extraRarity)
	lootData.RarityChances.Heroic = maxInterpolate(lootData.RarityChances.Heroic,extraRarity)
	lootData.RarityChances.Epic = maxInterpolate(lootData.RarityChances.Epic,extraRarity)
	lootData.RarityChances.Rare = maxInterpolate(lootData.RarityChances.Rare,extraRarity)
	lootData.RarityChances.Common = maxInterpolate(lootData.RarityChances.Common,extraRarity)
	CurrentRun.Hero.BoonData.ReplaceChance = maxInterpolate(CurrentRun.Hero.BoonData.ReplaceChance,extraReplace)
	baseFunc( lootData, args )
end, ClimbOfSisyphus)
