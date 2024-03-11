--[[
TODO:
Add part tweening
Add part destruction
Add attributes / collection service tags
Add ability to create party object on client and replicate to server / changes replicate back - Some kind of remote function
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Duck = require(script.Parent.Parent:WaitForChild("Duck"))

local Party = {}
Party.__index = Party

type replicationMode = "All" | "Select" | "AllExcept"
type replicateChangesFunction =  (Player | {Player}, number, string, any) -> (any)
type replicateDestroyFunction = (Player | {Player}, number) -> (any)
type replicateCreateFunction = (Player | {Player}, number, string, {[string]: any}) -> (any)
type clientAction = "Build" | "Destroy" | "Modify"

export type Party = typeof(setmetatable({}, Party)) & {
	InstanceName: string,
	Properties: {string},
	ReplicationMode: replicationMode,
	Players: {Player}?,
	_id: number
}

local lastId = 0

local replicateChanges = Duck.CreateRemoteSignal("ReplicateChanges")
local replicateDestroy = Duck.CreateRemoteSignal("ReplicateDestroy")
local replicateCreate = Duck.CreateRemoteSignal("ReplicateCreate")

local getInstances = Duck.CreateRemoteFunction("GetInstances")
local clientCreate = Duck.CreateRemoteFunction("ClientCreate")

local assetsFolder
local clientControlCallback

local partyObjects = {}

local function filter(tble: {any}, filterFunction: (...any) -> (boolean))
	local newTable = {}
	for i, v in tble do
		if filterFunction(v) then
			table.insert(newTable, v)
		end
	end
	return newTable
end

local function hash(tble: {any}): {[any]: true}
	local hashedTable = {}
	for i, v in tble do
		hashedTable[v] = true
	end
	return hashedTable
end

local function deHash(hashedTable: {[any]: true}): {any}
	local array = {}
	for value, boolean in hashedTable do
		table.insert(array, value)
	end
	return array
end

local function getReplicatablePlayers(mode: replicationMode, players: {Player}?, allPlayers: {Player}): {Player}?
	if mode == "All" then
		return allPlayers
	end
	if mode == "Select" then
		return players
	end
	if mode == "AllExcept" then
		if not players then
			return
		end
		local lookup = hash(allPlayers)
		for i, player in players do
			lookup[player] = nil
		end
		return deHash(lookup)
	end
	error("Invalid replication mode!")
end

local function canReplicateTo(player: Player, mode: replicationMode, players: {Player}?): boolean
	if mode == "All" then
		return true
	end
	if mode == "Select" then
		if not players then
			return false
		end
		if table.find(players, player) then
			return true
		end
	end
	if mode == "AllExcept" then
		if not players then
			return true
		end
		if not table.find(players, player) then
			return true
		end
	end
	return false
end

local function compressPartyObject(partyObject: Party): {_id: number, InstanceName: string, Properties: {[string]: any}}
	return {
		_id = partyObject._id,
		InstanceName = partyObject.InstanceName,
		Properties = partyObject.Properties
	}
end

local function getReplicatableInstances(player: Player): {{_id: number, InstanceName: string, Properties: {[string]: any}}}
	warn(player, "has requested!")
	local replicatableInstances = {}
	for i, partyObject in partyObjects do
		if canReplicateTo(player, partyObject.ReplicationMode, partyObject.Players) then
			table.insert(replicatableInstances, compressPartyObject(partyObject))
		end
	end
	return replicatableInstances
end

local function getNextId()
	lastId = lastId + 1
	return lastId
end

local function attemptPack(arg: any | {any}): {any}
	if typeof(arg) == "table" then
		return arg
	end
	return {arg}
end

local function onClientCreate(player: Player, action: clientAction, args: {[any]: any})
	if not (clientControlCallback and clientControlCallback(player, action, args)) then
		return false
	end
	if action == "Build" then
		local instanceName = args.InstanceName
		local properties = args.Properties
		assert(typeof(instanceName) == "string")
		assert(typeof(properties) == "table")
		local party = Party.CreateInstance(instanceName, properties, "Select")
		party.Players = {player}
		party:SetReplicationMode("All")
		return party._id
	end
	if action == "Destroy" then
		local id = args.Id
		assert(typeof(id) == "number")
		local partyObject = partyObjects[id]
		if not partyObject then
			return false
		end
		partyObject:SetReplicationModeInternal("AllExcept", player)
		partyObject:Destroy()
		return true
	end
	if action == "Modify" then
		local id = args.Id
		assert(typeof(id) == "number")
		local partyObject = partyObjects[id]
		if not partyObject then
			return false
		end	
		partyObject:SetReplicationModeInternal("AllExcept", player)
		local propertyName = args.PropertyName
		local newValue = args.NewValue
		partyObject:Set(propertyName, newValue)
		partyObject:SetReplicationModeInternal("All")
		return true
	end
end

function Party.Initialize(assets: Folder?)
	getInstances.OnInvoke = getReplicatableInstances
	clientCreate.OnInvoke = onClientCreate
end

function Party.new(instanceName: string, properties: {[string]: any}, replicationMode, players: Player? | {Player}?): Party
	local self = setmetatable({} :: Party, Party)
	self.InstanceName = instanceName
	self.Properties = properties
	self.ReplicationMode = replicationMode
	self.Players = attemptPack(players)
	self._id = getNextId()
	return self
end

function Party.CreateInstance(instanceName: string, properties: {[string]: any}, replicationMode: replicationMode, players: Player? | {Player}?): Party
	local self = Party.new(instanceName, properties, replicationMode, players)
	partyObjects[self._id] = self
	local replicatablePlayers = getReplicatablePlayers(replicationMode, self.Players, Players:GetPlayers())
	replicateCreate:Fire(replicatablePlayers, self._id, instanceName, properties)
	return self
end

function Party.SetClientControlCallback(callback: (Player, clientAction, {any}) -> boolean)
	clientControlCallback = callback
end

function Party.GetInstance(id: number): Party
	return partyObjects[id]
end

function Party.GetInstances(): {Party}
	return partyObjects
end

function Party:Set(property: string, newValue: any)
	self.Properties[property] = newValue
	local players = getReplicatablePlayers(self.ReplicationMode, self.Players, Players:GetPlayers())
	replicateChanges:Fire(players, self._id, property, newValue)
end

function Party:SetReplicationMode(replicationMode: replicationMode, players: Player? | {Player})
	local packedPlayers = attemptPack(players)
	local oldPlayers = getReplicatablePlayers(self.ReplicationMode, self.Players, Players:GetPlayers())
	local newPlayers = getReplicatablePlayers(replicationMode, packedPlayers, Players:GetPlayers())
	if not oldPlayers then
		if not newPlayers then
			return
		end
		replicateCreate:Fire(newPlayers, self._id, self.InstanceName, self.Properties)
		self.Players = packedPlayers
		self.ReplicationMode = replicationMode
		return
	end
	if not newPlayers then
		replicateDestroy:Fire(oldPlayers, self._id)
		self.Players = packedPlayers
		self.ReplicationMode = replicationMode
		return
	end
	local lookup = hash(oldPlayers)
	local uniquePlayers = {}
	for i, newPlayer in newPlayers do
		if lookup[newPlayer] then
			lookup[newPlayer] = nil
			continue
		end
		table.insert(uniquePlayers, newPlayer)
	end
	replicateCreate:Fire(uniquePlayers, self._id, self.InstanceName, self.Properties)
	replicateDestroy:Fire(deHash(lookup), self._id)
	self.Players = packedPlayers
	self.ReplicationMode = replicationMode
end

function Party:SetReplicationModeInternal(replicationMode: replicationMode, players: Player? | {Player})
	self.ReplicationMode = replicationMode
	self.Players = attemptPack(players)
end

function Party:Get(property: string): any
	return self.Properties[property]
end

function Party:Destroy()
	local players = getReplicatablePlayers(self.ReplicationMode, self.Players, Players:GetPlayers())
	replicateDestroy:Fire(players, self._id)
	partyObjects[self._id] = nil
end

return Party

--[[
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Party = {}
Party.__index = Party

type replicationMode = "All" | "Select" | "AllExcept"

type replicateChangesFunction =  (Player | {Player}, number, string, any) -> (any)

type replicateDestroyFunction = (Player | {Player}, number) -> (any)

type replicateCreateFunction = (Player | {Player}, number, string, {[string]: any}) -> (any)

export type Party = typeof(setmetatable({}, Party)) & {
	InstanceName: string,
	Properties: {string},
	ReplicationMode: replicationMode,
	Players: Player? | {Player}?,
	_id: number
}

local lastId = 0
local replicateChanges
local replicateDestroy
local replicateCreate
local assetsFolder

local instances = {}

local function filter(tble: {any}, filterFunction: (...any) -> (boolean))
	local newTable = {}
	for i, v in tble do
		if filterFunction(v) then
			table.insert(newTable, v)
		end
	end
	return newTable
end

local function hash(tble: {any}): {[any]: true}
	local hashedTable = {}
	for i, v in tble do
		hashedTable[v] = true
	end
	return hashedTable
end

local function deHash(hashedTable: {[any]: true})
	local array = {}
	for value, boolean in hashedTable do
		table.insert(array, value)
	end
	return array
end

local function getReplicatablePlayers(mode: replicationMode, players: Player? | {Player}?, allPlayers: {Player})
	if mode == "All" then
		return allPlayers
	end
	if mode == "Select" then
		if not players then
			error("Missing players field!")
		end
		return players
	end
	if mode == "AllExcept" then
		if not players then
			error("Missing players field!")
		end
		if typeof(players) ~= "table" then
			local index = table.find(allPlayers, players)
			table.remove(allPlayers, index)
			if #allPlayers == 1 then
				return table.unpack(allPlayers)
			end
			return allPlayers
		end
		return filter(allPlayers, function(player: Player)
			if table.find(players, player) then
				return false
			end
			return true
		end)
	end
end

local function canReplicateTo(player: Player, mode: replicationMode, players: Player? | {Player}?): boolean
	if mode == "All" then
		return true
	end
	if mode == "Select" then
		if not players then
			error("Missing players field!")
		end
		if typeof(players) == "table" then
			if table.find(players, player) then
				return true
			end
		else
			if players == player then
				return true
			end
		end
	end
	if mode == "AllExcept" then
		if not players then
			error("Missing players field!")
		end
		if typeof(players) == "table" then
			if not table.find(players, player) then
				return true
			end
		else
			if players ~= player then
				return true
			end
		end
	end
	return false
end

local function compressPartyObject(partyObject: Party): {_id: number, InstanceName: string, Properties: {[string]: any}}
	return {
		_id = partyObject._id,
		InstanceName = partyObject.InstanceName,
		Properties = partyObject.Properties
	}
end

local function getReplicatableInstances(player: Player): {{_id: number, InstanceName: string, Properties: {[string]: any}}}
	warn(player, "has requested!")
	local replicatableInstances = {}
	for i, instance in instances do
		if canReplicateTo(player, instance.ReplicationMode, instance.Players) then
			table.insert(replicatableInstances, compressPartyObject(instance))
		end
	end
	return replicatableInstances
end

local function getNextId()
	lastId = lastId + 1
	return lastId
end

function Party.Initialize(changeFunction: replicateChangesFunction, destroyFunction: replicateDestroyFunction, createFunction: replicateCreateFunction, assets: Folder?)
	replicateChanges = changeFunction
	replicateDestroy = destroyFunction
	replicateCreate = createFunction
	assetsFolder = assets
	return getReplicatableInstances
end

function Party.new(instanceName: string, properties: {[string]: any}, replicationMode, players: Player? | {Player}?): Party
	local self = setmetatable({} :: Party, Party)
	self.InstanceName = instanceName
	self.Properties = properties
	self.ReplicationMode = replicationMode
	self.Players = players
	self._id = getNextId()
	instances[self._id] = self
	local replicatablePlayers = getReplicatablePlayers(replicationMode, players, Players:GetPlayers())
	replicateCreate(replicatablePlayers, self._id, instanceName, properties)
	return self
end

function Party.GetInstance(id: number): Party
	return instances[id]
end

function Party.GetInstances(): {Party}
	return instances
end

function Party:Set(property: string, newValue: any)
	self.Properties[property] = newValue
	local players = getReplicatablePlayers(self.ReplicationMode, self.Players, Players:GetPlayers())
	replicateChanges(players, self._id, property, newValue)
end

function Party:SetReplicationMode(replicationMode: replicationMode, players: Player? | {Player})
	local newReplicatablePlayers = getReplicatablePlayers(replicationMode, players, Players:GetPlayers())
	local oldReplicatablePlayers = getReplicatablePlayers(self.ReplicationMode, self.Players, Players:GetPlayers())
	warn(oldReplicatablePlayers, newReplicatablePlayers)
	if typeof(newReplicatablePlayers) == "table" then
		local lookup = hash(newReplicatablePlayers)
		if typeof(oldReplicatablePlayers) == "table" then
			local sharedPlayers = {}
			local oldPlayers = {}
			for i, player in oldReplicatablePlayers do
				if lookup[player] then
					table.insert(sharedPlayers, player)
					lookup[player] = nil
					continue
				end
				table.insert(oldPlayers, player)
			end
			replicateDestroy(oldPlayers, self._id)
			replicateCreate(deHash(lookup), self._id, self.InstancenName, self.Properties)
			return
		end
		if lookup[oldReplicatablePlayers] then
			lookup[oldReplicatablePlayers] = nil
			replicateCreate(deHash(lookup), self._id, self.InstancenName, self.Properties)
			return
		end
		replicateCreate(newReplicatablePlayers, self._id, self.InstancenName, self.Properties)
		replicateDestroy(oldReplicatablePlayers, self._id)
		return
	end
	if typeof(oldReplicatablePlayers) == "table" then
		local lookup = hash(oldReplicatablePlayers)
		if lookup[newReplicatablePlayers] then
			lookup[newReplicatablePlayers] = nil
			replicateCreate(deHash(lookup), self._id, self.InstancenName, self.Properties)
		end
		return
	end
	if oldReplicatablePlayers ~= newReplicatablePlayers then
		replicateDestroy(oldReplicatablePlayers, self._id)
		replicateCreate(newReplicatablePlayers, self._id, self.InstanceName, self.Properties)
	end
	self.ReplicationMode = replicationMode
	self.Players = players
end

function Party:Get(property: string): any
	return self.Properties[property]
end

function Party:Destroy()
	local players = getReplicatablePlayers(self.ReplicationMode, self.Players, Players:GetPlayers())
	replicateDestroy(players, self._id)
	instances[self._id] = nil
end

return Party


]]