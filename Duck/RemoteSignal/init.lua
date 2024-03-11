if game:GetService("RunService"):IsServer() then
	return require(script.RemoteSignalServer)
else
	return require(script:WaitForChild("RemoteSignalClient"))
end