local RunService = game:GetService("RunService")

local Signal = require(script.Parent:WaitForChild("Signal"))

local Raybox = {}
Raybox.__index = Raybox

type Signal = Signal.Signal

export type Raybox = typeof(setmetatable({}, Raybox)) & {
	Started: boolean,
	HitPoints: {Attachment},
	Model: BasePart,
	Connection: RBXScriptConnection,
	Collided: Signal,
	DestroyConnection: RBXScriptConnection,
	Params: RaycastParams
}

local visualizeRaycasts = true
local rayColor = Color3.fromRGB(220, 50, 50)

local function getHitPoints(model: Instance): {Attachment}
	local hitPoints = {}
	for i, instance in model:GetDescendants() do
		if instance:IsA("Attachment") and instance.Name == "HitPoint" then
			table.insert(hitPoints, instance)
		end
	end
	print(hitPoints)
	return hitPoints
end

local function createTrails(model: Instance, attachments: {Attachment})
	local trails = {}
	for i, attachment in attachments do
		local trail = Instance.new("Trail")
		trail.Parent = model
		trail.FaceCamera = true
		trail.Lifetime = 1
		trail.Color = ColorSequence.new(rayColor)
		trail.LightEmission = 1
		trail.MaxLength = 50
		trail.Lifetime = 0.5
		table.insert(trails, trail)
	end
	return trails
end

local function createTrailAttachments(model: Instance, attachments: {Attachment}, offset: Vector3): {Attachment}
	local trailAttachments = {}
	for i, attachment in attachments do
		local trailAttachment = attachment:Clone()
		trailAttachment.Position += offset
		trailAttachment.Parent = model
		trailAttachment.Name = "TrailAttachment"
		table.insert(trailAttachments, trailAttachment)
	end
	return trailAttachments
end

local function destroyInstances(instances: {Instance})
	for i, instance in instances do
		if instance then
			instance:Destroy()
		end
	end
end

local function raycastFromTo(startPosition: Vector3, endPosition: Vector3, params: RaycastParams)
	local offset = endPosition - startPosition
	return workspace:Raycast(startPosition, offset, params)
end

local function trailModelAttachments(model: Instance, attachments: {Attachment})
	local trails = createTrails(model, attachments)
	local trailAttachments = createTrailAttachments(model, attachments, Vector3.new(0, 0.1, 0))
	local otherTrailAttachments = createTrailAttachments(model, attachments, Vector3.new(0, -0.1, 0))
	for i, trail in trails do
		trail.Attachment0 = trailAttachments[i]
		trail.Attachment1 = otherTrailAttachments[i]
	end
	return function()
		destroyInstances(trails)
		destroyInstances(trailAttachments)
		destroyInstances(otherTrailAttachments)
	end
end

local function checkForHits(lastPositions: {[Attachment]: Vector3}, hitPoints: {Attachment}, collided: Signal, params: RaycastParams)
	for i, hitPoint in hitPoints do
		local instancesCollided = {}
		local lastPosition = lastPositions[hitPoint]
		local hitPointPosition = hitPoint.WorldCFrame.Position
		lastPositions[hitPoint] = hitPointPosition
		if not lastPosition then
			return
		end
		local rayResult = raycastFromTo(lastPosition, hitPointPosition, params)
		if not rayResult then
			return
		end
		local hit = rayResult.Instance
		if not instancesCollided[hit] then
			collided:Fire(hit, rayResult.Position)
			instancesCollided[hit] = true
		end
	end
end

function Raybox.new(model: BasePart, rayParams: RaycastParams?): Raybox
	local self = setmetatable({} :: Raybox, Raybox)
	self.Started = false
	self.HitPoints = getHitPoints(model)
	self.Collided = Signal.new()
	self.Model = model
	if not rayParams then
		rayParams = RaycastParams.new()
	end
	self.DestroyConnection = model.Destroying:Connect(function()
		self:Destroy()
	end)
	rayParams:AddToFilter({model})
	self.Params = rayParams
	return self
end

function Raybox:Start()
	if self.Started then
		warn("Raybox already active!")
		return
	end
	self.Started = true
	local hitPoints = self.HitPoints
	if visualizeRaycasts then
		self.DestroyTrail = trailModelAttachments(self.Model, hitPoints)
	end
	local lastPositions: {[Attachment]: Vector3} = {}
	local params = self.Params
	local collided = self.Collided
	self.Connection = RunService.Heartbeat:Connect(function()
		checkForHits(lastPositions, hitPoints, collided, params)
	end)
end

function Raybox:Stop()
	local connection = self.Connection
	if connection then
		connection:Disconnect()
	end
	local destroyTrail = self.DestroyTrail
	if destroyTrail then
		destroyTrail()
	end
	self.Started = false
end

function Raybox:Destroy()
	self:Stop()
	local destroyConnection = self.DestroyConnection
	if destroyConnection then
		destroyConnection:Disconnect()
	end
	self.Collided:Destroy()
end

return Raybox