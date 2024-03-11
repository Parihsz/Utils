local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(script:WaitForChild("PartyServer"))
else
	return require(script:WaitForChild("PartyClient"))
end