local ECS = {}

local nextId = 1

local archetypes = {}
local componentIds: {[string]: number} = {}
local componentFields: {[number]: {any}} = {}

local function createArchetypeIdentifier(componentIds: {number})
	
end

local function createArchetype()
	
end

local function archetypeExists()
	
end

local function getComponentId(name: string)
	return componentIds[name]
end

local function getComponentFields(name: string)
	local id = componentIds[name]
	return componentFields[id]
end

function ECS.CreateEntity()
	
	nextId += 1
end

function ECS.InitializeComponents(components: {any})
	for i, component in components do
		componentIds[component.Name] = i
		componentFields[i] = component
	end
end

return ECS