if game:GetService("RunService"):IsServer() then
	return require(script.RemoteFunctionServer)
else
	return require(script:WaitForChild("RemoteFunctionClient"))
end