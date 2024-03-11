--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(script.Parent:WaitForChild("Signal"))

local FiniteStateMachine = {}
FiniteStateMachine.__index = FiniteStateMachine

type func = (...any) -> (...any)

type Signal = Signal.Signal

export type State = {
	OnEnter: func?,
	OnExit: func?,
	CanEnter: (...any) -> (boolean)?,
	Transitions: {string}?,
	Signals: {RBXScriptSignal}?,	
	Callbacks: {func}?,
	new: (...any) -> State
} & {[any]: any}

export type FiniteStateMachine = typeof(setmetatable({}, FiniteStateMachine)) & {
	States: {[string]: State},
	CurrentStateName: string?,
	Connections: {RBXScriptConnection},
	Conditions: {(...any) -> (boolean)},
	StateChanged: Signal,
	DestroyFunction: func?
}

function FiniteStateMachine.new(): FiniteStateMachine
	local self = setmetatable({} :: FiniteStateMachine, FiniteStateMachine)
	self.States = {}
	self.CurrentStateName = nil
	self.Connections = {}
	self.Conditions = {}
	self.StateChanged = Signal.new()
	return self
end

function FiniteStateMachine:SetState(newStateName: string, overrideState: boolean?): boolean
	if not self:CanTransitionTo(newStateName) and not overrideState then
		return false
	end
	local newState = self.States[newStateName]
	if newState.CanEnter and not overrideState then
		if not newState:CanEnter() then
			return false
		end
	end
	if not self:CheckConditions(newState) then
		return false
	end
	local oldState = self.States[self.CurrentStateName]
	if oldState and oldState.OnExit then
		pcall(oldState.OnExit)
	end
	if newState.OnEnter then
		pcall(newState.OnEnter)
	end
	self:Cleanup() -- Disconnects old connections
	self.CurrentStateName = newStateName
	self:InitializeEvents() -- Connects new events
	self.StateChanged:Fire(oldState, newState)
	return true
end

function FiniteStateMachine:CheckConditions(newState: State)
	for i, condition in self.Conditions do
		if not condition(newState) then
			return false
		end
	end
	return true
end

function FiniteStateMachine:AddCondition(condition: func)
	table.insert(self.Conditions, condition)
end

function FiniteStateMachine:GetState(): string
	return self.CurrentStateName
end

function FiniteStateMachine:GetStateData(stateName: string): {any}
	local stateData = self.States[stateName]
	return stateData
end

function FiniteStateMachine:GetStates()
	return self.States
end

function FiniteStateMachine:AddNewState(stateName: string, state: State)
	local stateInstance = state.new()
	print(stateInstance)
	self.States[stateName] = stateInstance
end

function FiniteStateMachine:InitializeEvents()
	local state = self.States[self.CurrentStateName]
	if not state or not state.Signals then
		return false
	end
	for i, signal in state.Signals do
		local callback = state.Callbacks[i]
		self.Connections[i] = signal:Connect(callback)
	end
	return true
end

function FiniteStateMachine:Cleanup()
	for i, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

function FiniteStateMachine:CanTransitionTo(newStateName: string)
	local currentState = self.States[self.CurrentStateName]
	if not currentState then
		return true
	end
	if table.find(currentState.Transitions, newStateName) then
		return true
	end
	return false
end

function FiniteStateMachine:Destroy()
	self:Cleanup()
	self.StateChanged:Destroy()
	local destroyFunction = self.DestroyFunction
	if destroyFunction then
		destroyFunction()
	end
	table.clear(self)
	table.freeze(self)
end

function FiniteStateMachine:BindToDestroy(destroyFunction: func)
	self.DestroyFunction = destroyFunction
end

function FiniteStateMachine:Clone(): FiniteStateMachine
	local newStateMachine: FiniteStateMachine = FiniteStateMachine.new()
	for stateName, state in self.States do
		newStateMachine:AddNewState(stateName, state)
	end
	newStateMachine.Conditions = self.Conditions
	newStateMachine.DestroyFunction = self.DestroyFunction
	return newStateMachine
end

return FiniteStateMachine

--[[
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FiniteStateMachine = {}
FiniteStateMachine.__index = FiniteStateMachine

function FiniteStateMachine.new()
	local self = setmetatable({}, FiniteStateMachine)
	self.States = {}
	self.CurrentStateName = nil
	self.StateData = {}
	self.Connections = {}
	return self
end

function FiniteStateMachine:SetState(newStateName, overrideState)
	if not self:CanTransitionTo(newStateName) and not overrideState then
		return nil
	end
	local newState = self.States[newStateName].new()
	local oldState = self.States[self.CurrentStateName]
	RunService.Heartbeat:Wait() -- Makes sure OnExit functions run after the OnHeartbeat functions to avoid errors
	if oldState and oldState.OnExit then
		pcall(oldState.OnExit)
	end
	if newState.OnEnter then
		pcall(newState.OnEnter)
	end
	self:Cleanup() -- Disconnects old connections
	self.CurrentStateName = newStateName
	self.StateData = newState
	self:Initialize() -- Connects new events
	return true
end

function FiniteStateMachine:GetState()
	local state = self.States[self.CurrentStateName]
	return state
end

function FiniteStateMachine:GetStateData(stateName)
	local stateData = self.States[stateName]
	return stateData
end

function FiniteStateMachine:GetStates()
	return self.States
end

function FiniteStateMachine:AddNewState(stateName, stateData)
	self.States[stateName] = stateData
end

function FiniteStateMachine:Initialize()
	local state = self.States[self.CurrentStateName]
	if not state or not state.Signals then
		return nil
	end
	for i, signal in state.Signals do
		local callback = state.Callbacks[i]
		self.Connections[i] = signal:Connect(callback)
	end
	return true
end

function FiniteStateMachine:Cleanup()
	for i, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

function FiniteStateMachine:CanTransitionTo(newStateName)
	local currentState = self.States[self.CurrentStateName]
	if table.find(currentState.Transitions, newStateName) then
		return true
	end
	return false
end

function FiniteStateMachine:HasClientAccess(stateName)
	local state = self.States[stateName]
	if state and state.ClientAccess then
		return true
	end
	return false
end

function FiniteStateMachine:Destroy()
	self:Cleanup()
	table.clear(self)
	table.freeze(self)
end

function FiniteStateMachine:Clone()
	local newStateMachine = setmetatable({}, FiniteStateMachine)
	for stateName, state in self.States do
		local newState = state
		newStateMachine:AddNewState(stateName, newState)
	end
	newStateMachine.CurrentStateName = nil
	return newStateMachine
end

return FiniteStateMachine
]]