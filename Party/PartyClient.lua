local Duck = require(script.Parent.Parent:WaitForChild("Duck"))

local Party = {}
Party.__index = Party

type requestInstancesFunction = (any) -> ({string}, {[string]: any})

export type Party = typeof(setmetatable({}, Party)) & {
	Id: number,
	Instance: Instance
}

local replicateChanges = Duck.CreateRemoteSignal("ReplicateChanges")
local replicateDestroy = Duck.CreateRemoteSignal("ReplicateDestroy")
local replicateCreate = Duck.CreateRemoteSignal("ReplicateCreate")

local getInstances = Duck.CreateRemoteFunction("GetInstances")
local clientCreate = Duck.CreateRemoteFunction("ClientCreate")

local assetsFolder

local partyObjects = {}
local instancesToId = {}

local function createInstance(instanceName: string, properties: {[string]: any}): Instance
	local instance = Instance.new(instanceName)
	for propertyName, propertyValue in properties do
		instance[propertyName] = propertyValue
	end
	return instance
end

local function onReplicateChanges(id: number, property: string, newValue: any)
	local partyObject = partyObjects[id]
	if not partyObject then
		warn("Party object does not exist!")
		return
	end
	partyObject[property] = newValue
end

local function onReplicateDestroy(id: number)
	local partyObject = partyObjects[id]
	if not partyObject then
		warn("Party object does not exist!")
		return
	end
	instancesToId[partyObject.Instance] = nil
	partyObject.Instance:Destroy()
	partyObjects[id] = nil
end

local function onReplicateCreate(id: number, instanceName: string, properties: {[string]: any})
	local partyObject = Party.new(id, createInstance(instanceName, properties))
	partyObjects[id] = partyObject
	instancesToId[partyObject.Instance] = id
end

function Party.new(id: number, instance: Instance): Party
	local self = setmetatable({} :: Party, Party)
	self.Id = id
	self.Instance = instance
	return self
end

function Party.CreateInstance(instanceName: string, properties: {[string]: any}): Party
	local instance = createInstance(instanceName, properties)
	local partyObject
	clientCreate:Invoke("Build", {
		InstanceName = instanceName,
		Properties = properties
	}):Then(function(id: number)
		if not id then
			error("Id does not exist!")
		end
		partyObject = Party.new(id, instance)
		partyObjects[id] = partyObject
		instancesToId[partyObject.Instance] = id
	end):Catch(function(errorMessage: string)
		instance:Destroy()
		warn(errorMessage)
	end):Await()
	return partyObject
end

function Party.GetInstance(id: number): Instance
	return partyObjects[id]
end

function Party.GetId(instance: Instance): number
	return instancesToId[instance]
end

function Party.Initialize(assets: Folder?)
	assetsFolder = assets
	getInstances:Invoke():Then(function(requestedInstances: {any})
		for i, requestedInstances in requestedInstances do
			onReplicateCreate(requestedInstances._id, requestedInstances.InstanceName, requestedInstances.Properties)
		end
	end):Catch(warn):Await()
	replicateCreate:Connect(onReplicateCreate)
	replicateChanges:Connect(onReplicateChanges)
	replicateDestroy:Connect(onReplicateDestroy)
end

function Party:Destroy()
	local parent = self.Instance.Parent
	local copy = self.Instance:Clone()
	local id = self.Id
	instancesToId[self.Instance] = nil
	self.Instance:Destroy()
	partyObjects[id] = nil
	clientCreate:Invoke("Destroy", {Id = self.Id}):Then(function(success: boolean)
		if not success then
			error("Destroy failed!")
		end
	end):Catch(function(errorMessage: string)
		self.Instance = copy
		copy.Parent = parent
		partyObjects[id] = self
		instancesToId[copy] = id
		warn(errorMessage)
	end):Await()
end

function Party:Set(propertyName: string, newValue: any)
	local oldValue = self.Instance[propertyName]
	self.Instance[propertyName] = newValue
	clientCreate:Invoke("Modify", {
		Id = self.Id,
		PropertyName = propertyName,
		NewValue = newValue
	}):Then(function(success: boolean)
		if not success then
			error("Set failed!")
		end
	end):Catch(function(errorMessage: string)
		self.Instance[propertyName] = oldValue
	end):Await()
end

return Party

--[[
local Duck = require(script.Parent.Parent:WaitForChild("Duck"))

local Party = {}
Party.__index = Party

type requestInstancesFunction = (any) -> ({string}, {[string]: any})

local replicateChanges = Duck.CreateRemoteSignal("ReplicateChanges")
local replicateDestroy = Duck.CreateRemoteSignal("ReplicateDestroy")
local replicateCreate = Duck.CreateRemoteSignal("ReplicateCreate")

local getInstances = Duck.CreateRemoteFunction("GetInstances")
local clientCreate = Duck.CreateRemoteFunction("ClientCreate")

local assetsFolder

local idToInstances = {}
local instancesToId = {}

local function changeInstance(id: number, property: string, newValue: any)
	local instance = idToInstances[id]
	if not instance then
		warn("An instance with the id", id, "does not exist!")
		return
	end
	instance[property] = newValue
end

local function destroyInstance(id: number)
	local instance = idToInstances[id]
	if not instance then
		warn("An instance with the id", id, "does not exist!", idToInstances)
		return
	end
	instancesToId[instance] = nil
	instance:Destroy()
	idToInstances[id] = nil
end

local function createInstance(id: number, instanceName: string, properties: {[string]: any})
	warn("Instance created!")
	if idToInstances[id] then
		warn("An instance with the id", id, "already exists!")
		return
	end
	local instance = Instance.new(instanceName)
	for propertyName, propertyValue in properties do
		instance[propertyName] = propertyValue
	end
	idToInstances[id] = instance
	instancesToId[instance] = id
end

function Party.new(instanceName: string, properties: {[string]: any})
	local self = setmetatable({}, Party)
	self.InstanceName = instanceName
	self.Properties = properties
	local instance = Instance.new(instanceName)
	for propertyName, propertyValue in properties do
		instance[propertyName] = propertyValue
	end
	clientCreate:Invoke("Build", {
		InstanceName = instanceName,
		Properties = properties
	}):Then(function(id: number)
		if not id then
			instance:Destroy()
			error("Failed build!")
		end
		return id
	end):Then(function(id: number)
		idToInstances[id] = instance
		instancesToId[instance] = id
	end):Catch(warn)
end

function Party.CreateInstance(instanceName: string, properties: {[string]: any}): Party
	local self = Party.new(instanceName, properties)
	return self
end

function Party.GetInstance(id: number): Instance
	return idToInstances[id]
end

function Party.GetId(instance: Instance)
	return instancesToId[instance]
end

function Party.Initialize(assets: Folder?)
	assetsFolder = assets
	getInstances:Invoke():Then(function(requestedInstances: {any})
		for i, requestedInstances in requestedInstances do
			createInstance(requestedInstances._id, requestedInstances.InstanceName, requestedInstances.Properties)
		end
	end):Catch(warn):Await()
	replicateCreate:Connect(createInstance)
	replicateChanges:Connect(changeInstance)
	replicateDestroy:Connect(destroyInstance)
end

return Party

]]