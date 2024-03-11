--!nonstrict
local BulkLoader = {}

export type BulkLoader = typeof(setmetatable({}, BulkLoader))

export type func = (...any) -> (...any)

export type Module = {any}

local Modules: {[string]: Module} = {}

local function moduleExists(moduleName: string): boolean
	if Modules[moduleName] then
		return true
	end
	return false
end

function BulkLoader.AddModules(folder: Instance)
	local folders = folder:GetChildren()
	for i, v in folders do
		if not v:IsA("ModuleScript") then
			continue
		end
		BulkLoader.AddModule(v :: ModuleScript)
	end
end

function BulkLoader.AddModulesDeep(folder: Instance)
	local folders = folder:GetDescendants()
	for i, v in folders do
		if not v:IsA("ModuleScript") then
			continue
		end
		BulkLoader.AddModule(v :: ModuleScript)
	end
end

function BulkLoader.AddModule(module: ModuleScript)
	local moduleName = module.Name
	if moduleExists(moduleName) then
		warn("Attempted to load same module twice!")
		return
	end
	Modules[moduleName] = require(module)
end

function BulkLoader.InitializeAll()
	for i, module in Modules do
		local initializeFunction = module.Initialize
		if not initializeFunction or typeof(initializeFunction) ~= "function" then
			continue
		end
		local success, errorMessage = pcall(initializeFunction)
		if not success then
			warn(errorMessage)
		end
	end
end

function BulkLoader.GetModule(moduleName: string): Module?
	local module = Modules[moduleName]
	return module
end

return BulkLoader