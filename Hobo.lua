--!strict
local Hobo = {}
Hobo.__index = Hobo
Hobo.ClassName = "Hobo"

export type CleanupObject = {any} | RBXScriptConnection | thread | Instance

export type func = (...any) -> (...any)

export type Hobo = typeof(setmetatable({}, Hobo)) & {
	Objects: {CleanupObject},
	IsCleaning: boolean,
	Status: "Active" | "Inactive"
}

local connection: RBXScriptConnection = workspace.Destroying:Connect(function() end) -- Silly micro-optimization to get disconnect function
connection:Disconnect()

local classOptions: {[string]: func} = {
	["Hobo"] = function(hobo)
		hobo:Destroy()
	end,
	["Promise"] = function(promise)
		promise:Close()
	end,
}

local cleanupOptions: {[string]: func} = {
	["Instance"] = game.Destroy,
	["table"] = function(object)
		local cleanupFunction = classOptions[object.ClassName]
		if cleanupFunction then
			cleanupFunction(object)
		end
	end,
	["RBXScriptConnection"] = connection.Disconnect,
	["thread"] = coroutine.close
}

local function deepClean(tble: {CleanupObject | any})
	for i, object: any in tble do
		local objectType: string = typeof(object)
		if objectType == "table" then
			deepClean(object)
			continue
		end
		local cleanupFunction: func = cleanupOptions[objectType]
		if cleanupFunction then
			cleanupFunction(object)
		end
	end
end

function Hobo.new()
	local self: Hobo = setmetatable({} :: Hobo, Hobo)
	self.Objects = {}
	self.IsCleaning = false
	self.Status = "Active"
	return self
end

-- DeepCleanTable and CleanTable clean any table passed as a parameter, without needing to construct a Hobo object
Hobo.DeepCleanTable = deepClean

function Hobo.CleanTable(tble: {CleanupObject | any})
	for i, object in tble do
		local cleanupFunction: func = cleanupOptions[typeof(object)]
		if cleanupFunction then
			cleanupFunction(object)
		end
	end
end

-- Cleanup method must accept object parameter, class must have ClassName property
function Hobo.AddCleanupMethod(className: string, method: func)
	classOptions[className] = method
end

function Hobo:Add(object: CleanupObject): boolean
	if self.IsCleaning then
		warn("Table is busy cleaning!")
		return false
	end
	local objectType: string = typeof(object)
	if not cleanupOptions[objectType] then
		warn(objectType, "is not able to be cleaned up!")
		return false
	end
	table.insert(self.Objects, object)
	return true
end

function Hobo:Remove(object: CleanupObject): boolean
	if self.IsCleaning then
		warn("Table is busy cleaning!")
		return false
	end
	local objects = self.Objects
	local index = table.find(objects, object)
	if not index then
		warn("Object does not exist!")
		return false
	end
	table.remove(objects, index)
	return true
end

function Hobo:Clean(): boolean
	if self.IsCleaning then
		warn("Table is busy cleaning!")
		return false
	end
	self.IsCleaning = true
	for i, object in self.Objects do
		local cleanupFunction: func = cleanupOptions[typeof(object)]
		cleanupFunction(object)
	end
	table.clear(self.Objects)
	self.IsCleaning = false
	return true
end

function Hobo:DeepClean(): boolean
	if self.IsCleaning then
		warn("Table is busy cleaning!")
		return false
	end
	self.IsCleaning = true
	deepClean(self.Objects)
	table.clear(self.Objects)
	self.IsCleaning = false
	return true
end

function Hobo:BindToInstance(instance: Instance): boolean
	if typeof(instance) ~= "Instance" then
		warn("Must bind to instance!")
		return false
	end
	if self._connection then
		self._connection:Disconnect()
	end
	self._connection = instance.Destroying:Connect(function()
		self:Destroy()
	end)
	return true
end

function Hobo:Destroy()
	local connection: RBXScriptConnection = self._connection
	if connection then
		connection:Disconnect()
	end
	self.Status = "Inactive"
	self:Clean()
end

function Hobo:DumpContents(): boolean
	if self.IsCleaning then
		warn("Cleaning in progress! Cannot dump contents!")
		return false
	end
	table.clear(self.Objects)
	return true
end

function Hobo:PrintContents()
	print(self.Objects)
end

return Hobo